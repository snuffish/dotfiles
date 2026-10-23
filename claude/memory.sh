#!/bin/bash
# claude-mem data for claude-mem-search (claude.bash), read-only from ~/.claude-mem/claude-mem.db. Three sources, each
# record named by a ref: memories (observations, #<id>), session summaries (S<id>) and your prompts (P<id>)
#   memory.sh project [DIR]           the claude-mem project for DIR (default $PWD): the project of the recorded
#                                     session cwd that is DIR or its nearest parent, without a "/<worktree>" part;
#                                     empty when claude-mem never saw DIR
#   memory.sh list memories|summaries|prompts here|all [TEXT]
#                                     one row per record, newest first:
#                                     "<age>\t<type>\t<ref>\t<label>\t<ref>\t<Claude session id>" (colored);
#                                     with TEXT, only records containing every word of it (memories and summaries
#                                     through claude-mem's full-text index, best match first)
#   memory.sh preview REF [reveal]    the record styled with ANSI colors, hits of $FZF_QUERY highlighted in text mode
#                                     ($FZF_PROMPT ends in "text> "); sensitive memories stay hidden without reveal
#   memory.sh show REF                the record as plain text
#   memory.sh session ID              the working directory of Claude session ID, from its transcript
#   memory.sh key source|scope|mode|change
#                                     the fzf action for that key or query change; the prompt holds the state:
#                                     "<Memories|Summaries|Prompts> · <This project|All>[ text]> "
# The schema belongs to the claude-mem plugin, so every query fails loudly instead of guessing

db="$HOME/.claude-mem/claude-mem.db"

if [[ "$1" == key ]]; then
  src=${FZF_PROMPT%% · *}
  [[ "$src" == Summaries || "$src" == Prompts ]] || src=Memories
  scope=here; [[ "$FZF_PROMPT" == *"· All"* ]] && scope=all
  text=; [[ "$FZF_PROMPT" == *" text> " ]] && text=1
  case "$2" in
    source) case $src in Memories) src=Summaries ;; Summaries) src=Prompts ;; *) src=Memories ;; esac ;;
    scope) if [[ $scope == all ]]; then scope=here; else scope=all; fi ;;
    mode) if [[ $text ]]; then text=; else text=1; fi ;;
    # Fuzzy mode filters inside fzf; text mode asks the database again
    change) [[ $text ]] || exit 0 ;;
  esac
  label='This project'; [[ $scope == all ]] && label=All
  list="bash $0 list $(tr '[:upper:]' '[:lower:]' <<< "$src") $scope"
  if [[ $text ]]; then
    echo "change-prompt($src · $label text> )+disable-search+reload($list {q})+refresh-preview"
  else
    echo "change-prompt($src · $label> )+enable-search+reload($list)+refresh-preview"
  fi
  exit
fi

if [[ "$1" == session ]]; then
  file=$(find "$HOME/.claude/projects" -mindepth 2 -maxdepth 2 -name "$2.jsonl" -print -quit 2>/dev/null)
  [[ -n "$file" ]] || { echo "No local transcript for session $2 (written on another device?)" >&2; exit 1; }
  grep -m1 -o '"cwd":"[^"]*"' "$file" | sed 's/^/{/; s/$/}/' | jq -r .cwd
  exit
fi

command -v sqlite3 >/dev/null || { echo "claude-mem-search needs sqlite3" >&2; exit 1; }
[[ -f "$db" ]] || { echo "No claude-mem database at $db" >&2; exit 1; }

q() {
  local out
  if ! out=$(sqlite3 -readonly -json "$db" "$1" 2>&1); then
    echo "claude-mem query failed (schema changed?): $out" >&2
    exit 1
  fi
  printf '%s' "$out"
}

# A single-quoted SQL string literal
lit() { printf "'%s'" "${1//\'/\'\'}"; }

if [[ "$1" == project ]]; then
  dir=$(lit "${2:-$PWD}")
  q "select project from sdk_sessions
     where cwd is not null and ($dir = cwd or substr($dir, 1, length(cwd) + 1) = cwd || '/')
     group by cwd, project order by length(cwd) desc, count(*) desc limit 1" | jq -r '.[0].project // empty | sub("/.*"; "")'
  exit
fi

jqdefs='def glyph: {bugfix: "●", feature: "◆", refactor: "↻", change: "✓", discovery: "○", decision: "⚖",
    security_alert: "⚠", security_note: "⚷", sensitive: "⊘", summary: "🎯", prompt: "❯"}[.] // "·";
  # A prompt as typed: no reminders or IDE context, a slash command as "<name> <args>"
  def clean: gsub("<system-reminder>[\\s\\S]*?</system-reminder>"; "")
    | gsub("<(?<t>ide_[a-z_]+)>[\\s\\S]*?</\\k<t>>"; "")
    | gsub("<command-message>[^<]*</command-message>\\s*"; "")
    | gsub("<command-name>(?<n>[^<]*)</command-name>\\s*(<command-args>(?<a>[\\s\\S]*?)</command-args>)?"; "\(.n) \(.a // "")")
    | gsub("^\\s+|\\s+$"; "");'

if [[ "$1" == list ]]; then
  words=()
  read -ra input <<< "$4"
  for w in "${input[@]}"; do [[ "$w" == *[[:alnum:]]* ]] && words+=("$w"); done
  project=
  if [[ "$3" == here ]]; then
    project=$(bash "$0" project) || exit 1
    [[ -n "$project" ]] || exit 0
  fi
  # The scope clause on a project column, and on a merged_into_project column when the table has one:
  # worktree records are keyed "<repo>/<worktree>", merged ones keep their old project
  in_project() {
    [[ -n "$project" ]] || { echo 1; return; }
    local p; p=$(lit "$project")
    echo "($1 = $p collate nocase or lower(substr($1, 1, length($p) + 1)) = lower($p || '/')${2:+ or $2 = $p collate nocase})"
  }
  # Every word becomes a quoted FTS5 prefix term, all required: raw input like cm-sync is FTS5 syntax
  fts() { local w m=; for w in "${words[@]}"; do m+="\"${w//\"/\"\"}\"* "; done; lit "${m% }"; }
  # Line breaks are flattened in SQL: a jq gsub over every title costs most of a second
  flat() { echo "replace(replace(replace($1, char(13), ' '), char(10), ' '), char(9), ' ')"; }
  case "$2" in
    memories)
      from="observations o" match= order="o.created_at_epoch desc"
      if (( ${#words[@]} )); then
        from="observations_fts f join observations o on o.id = f.rowid"
        match="and observations_fts match $(fts)" order="bm25(observations_fts) limit 300"
      fi
      sql="select '#' || o.id as ref, o.created_at_epoch / 1000 as t, o.project, o.type, $(flat o.title) as title,
          s.content_session_id as sid
        from $from left join sdk_sessions s on s.memory_session_id = o.memory_session_id
        where $(in_project o.project o.merged_into_project) $match order by $order" ;;
    summaries)
      from="session_summaries m" match= order="m.created_at_epoch desc"
      if (( ${#words[@]} )); then
        from="session_summaries_fts f join session_summaries m on m.id = f.rowid"
        match="and session_summaries_fts match $(fts)" order="bm25(session_summaries_fts) limit 300"
      fi
      sql="select 'S' || m.id as ref, m.created_at_epoch / 1000 as t, m.project, 'summary' as type,
          $(flat "coalesce(m.request, m.completed)") as title, s.content_session_id as sid
        from $from left join sdk_sessions s on s.memory_session_id = m.memory_session_id
        where $(in_project m.project m.merged_into_project) $match order by $order" ;;
    prompts)
      # No full-text index for prompts; a few hundred rows scan in milliseconds
      match=
      for w in "${words[@]}"; do match+=" and instr(lower(p.prompt_text), lower($(lit "$w"))) > 0"; done
      sql="select 'P' || p.id as ref, p.created_at_epoch / 1000 as t, s.project, 'prompt' as type,
          substr($(flat p.prompt_text), 1, 400) as title, p.content_session_id as sid
        from user_prompts p left join sdk_sessions s on s.id = p.session_db_id
        where $(in_project s.project) and p.prompt_text not like '<agent-message%' $match order by p.created_at_epoch desc" ;;
    *) echo "usage: memory.sh list memories|summaries|prompts here|all [TEXT]" >&2; exit 1 ;;
  esac
  q "$sql" | jq -r --arg scope "$3" "$jqdefs"'
    def pad($n): . + (" " * ([$n - length, 0] | max));
    .[] | (now - .t) as $age
    | [ (if $age < 60 then "now" elif $age < 3600 then "\($age / 60 | floor)m ago" elif $age < 86400 then "\($age / 3600 | floor)h ago"
         elif $age < 604800 then "\($age / 86400 | floor)d ago" else .t | localtime | strftime("%Y-%m-%d") end | pad(8)),
        "\u001b[33m\(.type | glyph)\u001b[0m \u001b[90m\(.type | pad(14))\u001b[0m",
        "\u001b[90m\(.ref)\u001b[0m",
        (if $scope == "all" then "\u001b[34m\(.project // "?")\u001b[0m  " else "" end)
          + (if .type == "prompt" then .title | clean else .title // "(untitled)" end),
        .ref, .sid // "" ] | @tsv'
  exit
fi

if [[ "$1" == preview || "$1" == show ]]; then
  case "$2" in
    S*) kind=summary id=${2#S} ;;
    P*) kind=prompt id=${2#P} ;;
    *) kind=memory id=${2#\#} ;;
  esac
  [[ "$id" =~ ^[0-9]+$ ]] || exit 0
  case $kind in
    memory) sql="select o.*, '#' || o.id as ref, s.content_session_id as sid from observations o
               left join sdk_sessions s on s.memory_session_id = o.memory_session_id where o.id = $id" ;;
    summary) sql="select m.*, 'S' || m.id as ref, 'summary' as type, s.content_session_id as sid from session_summaries m
               left join sdk_sessions s on s.memory_session_id = m.memory_session_id where m.id = $id" ;;
    prompt) sql="select p.*, 'P' || p.id as ref, 'prompt' as type, s.project, p.content_session_id as sid from user_prompts p
               left join sdk_sessions s on s.id = p.session_db_id where p.id = $id" ;;
  esac
  # The query's words, highlighted in text mode
  re=
  if [[ "$1" == preview && "$FZF_PROMPT" == *" text> " ]]; then
    re=$(jq -rn --arg q "$FZF_QUERY" '[$q | scan("\\w+")] | join("|")')
  fi
  q "$sql" | jq -r --argjson color "$([[ "$1" == preview ]] && echo true || echo false)" \
      --argjson reveal "$([[ "$1" == show || "$3" == reveal ]] && echo true || echo false)" --arg re "$re" "$jqdefs"'
    def style($code): if $color then "\u001b[\($code)m\(.)\u001b[0m" else . end;
    def hl: if $re == "" then . else gsub("(?<m>\($re))"; "\u001b[1;30;43m\(.m)\u001b[0m"; "i") end;
    def items: (try fromjson catch null) as $v | if ($v | type) == "array" then $v else [] end;
    def section($name; $xs): if ($xs | length) > 0 then ($name | style("1;35")), ($xs[] | "  • " + hl), "" else empty end;
    # Summary fields are "• …" lines, every one after the first indented
    def prose($name; $text): if ($text // "") != "" then ($name | style("1;35")),
      ($text | gsub("^\\s+|\\s+$"; "") | gsub("\n\\s*"; "\n  ") | "  " + hl), "" else empty end;
    .[0] // empty
    | "\(.type | glyph) " + (if .type == "summary" then .request // .completed elif .type == "prompt" then "Your prompt \(.prompt_number)"
        else .title end // "(untitled)" | hl | style("1")),
      (.subtitle // empty | hl | style("3")),
      ("\(.ref) · \(.type) · \(.project // "?") · \(.created_at_epoch / 1000 | localtime | strftime("%Y-%m-%d %H:%M"))"
        + (if .sid then " · session \(.sid[0:8])" else "" end) | style("90")),
      "",
      if .type == "sensitive" and ($reveal | not) then "⊘ Sensitive: ctrl-r reveals it" | style("1;31")
      elif .type == "summary" then
        prose("Investigated"; .investigated), prose("Learned"; .learned), prose("Completed"; .completed),
        prose("Next steps"; .next_steps), prose("Notes"; .notes),
        section("Files read"; .files_read | items), section("Files edited"; .files_edited | items)
      elif .type == "prompt" then .prompt_text | clean | hl
      else
        (.narrative // .text // empty | hl), "",
        section("Facts"; .facts | items),
        section("Concepts"; .concepts | items),
        section("Files read"; .files_read | items),
        section("Files modified"; .files_modified | items)
      end'
  exit
fi

echo "usage: memory.sh project|list|preview|show|session|key" >&2
exit 1
