#!/bin/bash
input=$(cat)

model=$(echo "$input" | /usr/bin/jq -r 'if (.model.effort // "") != "" and ((.model.display_name // "") | contains("(") | not) then "\(.model.display_name) (\(.model.effort))" else (.model.display_name // empty) end')
dir=$(echo "$input" | /usr/bin/jq -r '.workspace.current_dir // .cwd // empty')
used=$(echo "$input" | /usr/bin/jq -r '.context_window.used_percentage // empty')
transcript=$(echo "$input" | /usr/bin/jq -r '.transcript_path // empty')
session=$(echo "$input" | /usr/bin/jq -r '.session_id // .conversation_id // empty')
git_wt=$(echo "$input" | /usr/bin/jq -r '.workspace.git_worktree // empty')
product=$(echo "$input" | /usr/bin/jq -r '.product // empty')
# One per line: a tab-joined read would collapse empty fields
{ read -r cost; read -r limit_5h; read -r limit_7d; read -r model_id; read -r ctx_size; } < <(echo "$input" | /usr/bin/jq -r \
  '(.cost.total_cost_usd // .cost.total_usd), .rate_limits.five_hour.used_percentage, .rate_limits.seven_day.used_percentage,
   .model.id, .context_window.context_window_size | . // ""')

# Empty text prints nothing, so join drops it without leaving a stray separator
color() { [ -n "$2" ] && printf '\033[%sm%s\033[0m' "$1" "$2"; }
join() {
  local sep=$1 out="" p
  shift
  for p in "$@"; do [ -n "$p" ] && out="${out:+$out$sep}$p"; done
  printf '%s' "$out"
}
# Color for a percentage that warms up towards a hard limit (auto-compact, rate limits); $3, if given, colors 50-69
heat() {
  if [ "$1" -ge 85 ]; then printf 31; elif [ "$1" -ge 70 ]; then printf '38;5;208'
  elif [ "$1" -ge 50 ] && [ -n "$3" ]; then printf '%s' "$3"; else printf '%s' "$2"; fi
}

title=$(echo "$input" | /usr/bin/jq -r '.session_name // .conversation_title // empty')

# Fallback when stdin lacks session_name / conversation_title: Antigravity SQLite DB, or Claude /rename customTitle / aiTitle
if [ -z "$title" ] && [ "$product" = "antigravity" ] && [ -n "$session" ] && [ -f ~/.gemini/antigravity-cli/conversation_summaries.db ] && command -v sqlite3 >/dev/null 2>&1; then
  safe_id="${session//\'/\'\'}"
  title=$(sqlite3 ~/.gemini/antigravity-cli/conversation_summaries.db "SELECT title FROM conversation_summaries WHERE conversation_id = '$safe_id' LIMIT 1;" 2>/dev/null)
fi
if [ -z "$title" ] && [ -f "$transcript" ]; then
  title=$(grep -o '"customTitle":"[^"]*"' "$transcript" | tail -1 | cut -d'"' -f4)
  [ -z "$title" ] && title=$(grep -o '"aiTitle":"[^"]*"' "$transcript" | tail -1 | cut -d'"' -f4)
fi

# Skills whose bodies are in context. Every load (slash command, Skill tool, post-compact re-injection)
# writes "Base directory for this skill: <dir>"; a compact_boundary resets the set.
# Scanned incrementally: a full scan of a large transcript outlasts the statusline's update cadence
skills=""
if [ -f "$transcript" ] && [ -n "$session" ]; then
  transcript_src="$transcript"
  [ -f "${transcript%.jsonl}_full.jsonl" ] && transcript_src="${transcript%.jsonl}_full.jsonl"
  cache_dir="${TMPDIR:-/tmp}/claude-statusline"
  cache="$cache_dir/$session.skills"
  size=$(wc -c < "$transcript_src" | tr -d ' ')
  offset=0; cached_path=""; list=""
  [ -f "$cache" ] && { read -r offset cached_path; list=$(cat); } < "$cache"
  if ! [[ "$offset" =~ ^[0-9]+$ ]] || [ "$cached_path" != "$transcript_src" ] || [ "$offset" -gt "$size" ]; then
    offset=0; list=""
  fi

  # Only advance over complete lines, so a write in progress can't split a marker
  if [ "$size" -gt "$offset" ] && [ -z "$(tail -c +"$size" "$transcript_src" | head -c 1)" ]; then
    # Request blobs repeat the transcript; raw quotes in the anchors skip tool calls that merely mention the marker
    new=$(tail -c +$((offset + 1)) "$transcript_src" | head -c $((size - offset)) | awk '
      index($0, "{\"type\":\"api-request-blob\"") == 1 { next }
      index($0, "\"subtype\":\"compact_boundary\"") && index($0, "\"type\":\"system\"") { reset = 1; n = 0; next }
      {
        s = $0
        while (match(s, /"(text|content)":"Base directory for this skill: \/[A-Za-z0-9._\/~ -]+/)) {
          m = substr(s, RSTART, RLENGTH); sub(/.*skill: /, "", m); buf[++n] = m
          s = substr(s, RSTART + RLENGTH)
        }
      }
      /"type":"(USER_INPUT|SYSTEM_MESSAGE)"/ && /<SKILL>/ {
        s = $0
        while (match(s, /<SKILL>The user (has explicitly invoked the \([A-Za-z0-9_:-]+\)|requested you read and use the \\"[A-Za-z0-9_:-]+\\") skill\./)) {
          m = substr(s, RSTART, RLENGTH)
          if (match(m, /\([A-Za-z0-9_:-]+\)/)) {
            buf[++n] = substr(m, RSTART + 1, RLENGTH - 2)
          } else if (match(m, /\\"[A-Za-z0-9_:-]+\\"/)) {
            buf[++n] = substr(m, RSTART + 2, RLENGTH - 4)
          }
          s = substr(s, RSTART + RLENGTH)
        }
      }
      /"type":"PLANNER_RESPONSE"/ && /"tool_calls":/ && /"(read_file|view_file)"/ {
        s = $0
        while (match(s, /"(Path|AbsolutePath)":(\\"|")[^"\\]+\/skills\/[A-Za-z0-9._-]+\/SKILL\.md(\\"|")/)) {
          m = substr(s, RSTART, RLENGTH)
          sub(/^.*\/skills\//, "", m)
          sub(/\/SKILL\.md(\\"|")$/, "", m)
          if (m != "_modules") buf[++n] = m
          s = substr(s, RSTART + RLENGTH)
        }
      }
      END { if (reset) print "\001"; for (i = 1; i <= n; i++) print buf[i] }
    ' | sed -E 's#.*/plugins/cache/[^/]+/([^/]+)/[^/]+/skills/(.*/)?([^/]+)$#\1:\3#; s#.*/##')
    if [ "${new%%$'\n'*}" = $'\001' ]; then
      list=""; new=$(printf '%s\n' "$new" | sed '1d')
    fi
    # Keep each skill at the position of its latest load
    list=$(printf '%s\n%s\n' "$list" "$new" | sed '/^$/d' | awk '{ a[++n] = $0; last[$0] = n } END { for (i = 1; i <= n; i++) if (last[a[i]] == i) print a[i] }')
    mkdir -p "$cache_dir"
    # Temp files of killed runs, and caches of sessions long gone
    find "$cache_dir" \( -name '*.skills.*' -mmin +1 -o -name '*.skills' -mtime +7 \) -delete 2>/dev/null
    { printf '%s %s\n' "$size" "$transcript_src"; [ -z "$list" ] || printf '%s\n' "$list"; } > "$cache.$$" && mv -f "$cache.$$" "$cache"
  fi

  if [ -n "$list" ]; then
    total=$(printf '%s\n' "$list" | wc -l | tr -d ' ')
    skills=$(printf '%s\n' "$list" | tail -3 | paste -sd, -)
    [ "$total" -gt 3 ] && skills="$skills +$((total - 3))"
  fi
fi

where=""
if [ -n "$dir" ]; then
  # Branch (short sha when detached), "*" unstaged or untracked, "+" staged, ↑↓ commits ahead/behind upstream
  { read -r branch; read -r dirty; read -r ab; } < <(git --no-optional-locks -C "$dir" status --porcelain=v2 --branch 2>/dev/null | awk '
    /^# branch\.oid / { oid = substr($3, 1, 7) }
    /^# branch\.head / { head = $3 }
    /^# branch\.ab / { a = substr($3, 2) + 0; b = substr($4, 2) + 0 }
    /^[12] / { if (substr($2, 1, 1) != ".") staged = 1; if (substr($2, 2, 1) != ".") unstaged = 1 }
    /^[u?] / { unstaged = 1 }
    END {
      if (head == "" && oid == "") exit
      print (head == "(detached)" ? oid : head)
      print (unstaged ? "*" : "") (staged ? "+" : "")
      print (a > 0 ? "↑" a : "") (b > 0 ? "↓" b : "")
    }
  ')

  # cwd inside a linked worktree: its git dir differs from the common dir. Fallback when stdin lacks git_worktree
  { read -r toplevel; read -r git_dir; read -r common_dir; } < <(git --no-optional-locks -C "$dir" rev-parse --path-format=absolute --show-toplevel --git-dir --git-common-dir 2>/dev/null)
  cwd_wt="$git_wt"
  [ -z "$cwd_wt" ] && [ -n "$toplevel" ] && [ "$git_dir" != "$common_dir" ] && cwd_wt=$(basename "$git_dir")

  # Worktrees this session edits from outside: the git-worktrees Module locks them with "session:<id>"
  owned=""
  if [ -n "$session" ]; then
    repos=()
    if [ -n "$toplevel" ]; then
      repos=("$toplevel")
    else
      for g in "$dir"/*/.git; do [ -e "$g" ] && repos+=("$(dirname "$g")"); done
    fi
    # Sibling worktrees of one repo list the same entries, hence the dedupe; a locked worktree is never "prunable", hence the -d
    owned=$(for r in "${repos[@]}"; do
      git --no-optional-locks -C "$r" worktree list --porcelain 2>/dev/null | awk -v sid="session:$session " -v cur="$toplevel" '
        function flush() {
          if (dir != "" && !prunable && dir != cur && index(lock " ", sid)) print dir
          dir = ""; lock = ""; prunable = 0
        }
        /^worktree / { flush(); dir = substr($0, 10); next }
        /^locked/    { lock = $0; next }
        /^prunable/  { prunable = 1; next }
        END          { flush() }
      '
    done | awk '!seen[$0]++' | while read -r d; do [ -d "$d" ] && basename "$d"; done | paste -sd, -)
  fi

  nowt=""
  [ -z "$cwd_wt$owned" ] && [ -n "$toplevel" ] && nowt="no-wt"

  # Dir, branch and worktree state share a segment: together they describe where the edits land
  where=$(join ' · ' "$(color 34 "$(basename "$dir")")" "$(color 32 "$branch")$(color 33 "$dirty${ab:+ $ab}")" \
    "$(color 31 "${cwd_wt:+wt:$cwd_wt}")" "$(color 31 "${owned:+wt→$owned}")" "$(color 2 "$nowt")")
fi

# ctx and skills share a segment: both describe what is in the context window
used_txt=""; ctx_color=32
if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used")
  used_txt="ctx $pct%"
  # used_percentage is of the model's window; color by progress towards autoCompactWindow, which compacts earlier.
  # A per-model value replaces the top-level one; "auto" or none means the model's window
  compact=$(/usr/bin/jq -r --arg m "${model_id%\[1m\]}" \
    '(.modelSettings[$m].autoCompactWindow // .autoCompactWindow) | numbers' ~/.claude/settings.json 2>/dev/null)
  near=$pct
  [[ "$compact" =~ ^[0-9]+$ ]] && [[ "$ctx_size" =~ ^[0-9]+$ ]] && [ "$compact" -gt 0 ] &&
    near=$(awk -v u="$used" -v s="$ctx_size" -v c="$compact" 'BEGIN { printf "%.0f", u * s / c }')
  ctx_color=$(heat "$near" 32 33)
fi
ctx=$(join ' · ' "$(color "$ctx_color" "$used_txt")" "$(color '38;5;208' "${skills:+skills:$skills}")")

# Session cost and plan rate limits share a segment: both describe spend
usage_parts=()
[ -n "$cost" ] && usage_parts+=("$(color 2 "$(printf '$%.2f' "$cost")")")
for w in 5h 7d; do
  v=limit_${w}; v=${!v}
  [ -n "$v" ] || continue
  p=$(printf '%.0f' "$v")
  usage_parts+=("$(color "$(heat "$p" 2)" "$w $p%")")
done
usage=$(join ' · ' "${usage_parts[@]}")

# Title and id both identify the session; the full id goes last so it can be copied into `claude --resume <id>`
sess=$(join ' · ' "$(color 35 "$title")" "$(color 2 "$session")")

join "$(color 2 ' │ ')" "$(color 36 "$model")" "$where" "$ctx" "$usage" "$sess"
