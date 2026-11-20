#!/bin/bash


# claude -p with live progress: the session id and each tool call go to stderr as they start, the final answer to
# stdout; args go to claude. With a named -w/--worktree that this run creates, the worktree is removed after the run
# when wt-rm calls it safe; it is found by path, so a branch renamed mid-run still gets cleaned up. An unnamed or
# pre-existing one is left alone, so other sessions' worktrees are never touched
function claude-p() {
  local arg prev="" name="" dir="" main rc
  for arg in "$@"; do
    case "$prev" in -w | --worktree) [[ "$arg" =~ ^[A-Za-z0-9._-]+$ && "$arg" != -* ]] && name=$arg ;; esac
    [[ "$arg" == --worktree=* ]] && name=${arg#--worktree=}
    prev=$arg
  done
  if [[ -n "$name" ]] && main=$(_wt_main .); then
    [[ -e "$main/.claude/worktrees/$name" ]] || dir="$main/.claude/worktrees/$name"
  fi
  claude -p --output-format stream-json --verbose "$@" | jq --unbuffered -rj '
    if .type == "system" and .subtype == "init" then
      "\u001b[2msession \(.session_id)\u001b[0m\n" | stderr | empty
    elif .type == "assistant" then
      .message.content[] | select(.type == "tool_use")
      | (.input | .description // .command // .file_path // .pattern // .skill // "" | tostring | gsub("\n"; " ") | .[0:80]) as $arg
      | "\u001b[2m→ \(.name) \($arg)\u001b[0m\n" | stderr | empty
    elif .type == "result" then .result + "\n"
    else empty end'
  rc="${PIPESTATUS[0]:-${pipestatus[1]}}"
  # claude has exited, so its registry entry is gone and doesn't count as live
  if [[ -n "$dir" && -d "$dir" ]]; then
    wt-rm "$dir" || echo "claude-p: kept worktree $dir" >&2
    # Without the WorktreeCreate hook Claude names the branch worktree-<name>; drop it when no commit is only there
    if [[ ! -d "$dir" ]] && git show-ref -q --verify "refs/heads/worktree-$name" &&
      [[ "$(git rev-list --count "worktree-$name" --not --exclude="worktree-$name" --branches --remotes)" == 0 ]]; then
      git branch -q -D "worktree-$name"
    fi
  fi
  return "$rc"
}

# claude -w in a new locked worktree of the current repo (WorktreeCreate hook → wt-new), detached at origin's default
# branch: cw makes no branch, switch to one inside the tree when needed. cw <id> <slug> → tree <id>-<slug>;
# cw <slug> → tree <slug>; cw → a random name; cw pr<N> or cw '!<N>' → tree pr-<N> on the PR's source branch.
# --tmux, --bg and other options go to claude
function cw() {
  local name branch="" base="" detach=1 pr src
  local -a pos=() opts=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; opts+=("$@"); break ;;
      # claude options that take a value keep it, or the value would land in pos as a ticket id or slug
      --settings|--model|--agent|--add-dir|--permission-mode|--effort|--mcp-config|--append-system-prompt|-r|--resume)
        opts+=("$1" "$2"); shift 2 ;;
      -*) opts+=("$1"); shift ;;
      *) pos+=("$1"); shift ;;
    esac
  done
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "cw: not inside a git repository" >&2; return 1; }
  set -- "${pos[@]}"
  if [[ $# -ge 2 ]]; then
    name="$1-$2"
  elif [[ "$1" == '!'[0-9]* || "$1" == pr[0-9]* ]]; then
    pr=${1#!} pr=${pr#pr} name="pr-$pr"
    if [[ "$(git remote get-url origin 2>/dev/null)" == *github.com* ]]; then
      src=$(gh pr view "$pr" --json headRefName -q .headRefName) || return 1
    else
      src=$(az repos pr show --id "$pr" --query sourceRefName -o tsv) || return 1
      src=${src#refs/heads/}
    fi
    git fetch -q origin "$src" || return 1
    branch=$src base="origin/$src" detach=""
  elif [[ $# -eq 1 ]]; then
    name=$1
  else
    name="$(printf '%s\n' calm bold keen warm quick brave quiet sharp | sed -n "$((RANDOM % 8 + 1))p")"
    name+="-$(printf '%s\n' otter heron maple cedar falcon badger willow comet | sed -n "$((RANDOM % 8 + 1))p")"
    name+="-$(printf %04x "$RANDOM")"
  fi
  (export CW_BRANCH="$branch" CW_BASE="$base" CW_DETACH="$detach"; claude -w "$name" "${opts[@]}")
}

# Follow a Claude Code session's transcript live: prompts and answers, plus each tool call dimmed. With no arg the
# newest session in this directory; $1 is a transcript path or a session id (or its prefix) from any directory.
# Also reads Antigravity transcripts (ar's ctrl-l passes those as a path)
function claude-tail() {
  local f
  if [[ -f "$1" ]]; then f=$1
  elif [[ -n "$1" ]]; then f=$({ command ls -t "$HOME"/.claude/projects/*/"$1"*.jsonl; } 2>/dev/null | head -n 1)
  else f=$({ command ls -t "$HOME/.claude/projects/${PWD//[^[:alnum:]]/-}"/*.jsonl; } 2>/dev/null | head -n 1)
  fi
  [[ -n "$f" ]] || { echo "claude-tail: no session transcript found" >&2; return 1; }
  echo "$f" >&2
  tail -n 50 -f "$f" | jq --unbuffered -rj '
    def tool($name; $arg): ($arg // "" | tostring | gsub("\n"; " ") | .[0:80]) as $a
      | "\u001b[2m  → \($name) \($a)\u001b[0m\n";
    if has("step_index") then
      # Antigravity: the prompt sits in <USER_REQUEST>, tool args are JSON-encoded strings
      if .type == "USER_INPUT" then
        "[user] \(.content // "" | sub("^[\\s\\S]*<USER_REQUEST>\\s*"; "") | sub("\\s*</USER_REQUEST>[\\s\\S]*$"; ""))\n"
      elif .type == "PLANNER_RESPONSE" then
        (if (.content // "") != "" then "[assistant] \(.content)\n" else empty end),
        (.tool_calls[]? | tool(.name; .args | .toolSummary // .CommandLine // .Path // .Prompt | try fromjson catch .))
      else empty end
    elif .type == "user" or .type == "assistant" then
      .type as $t | .message.content
      | if type == "string" then "[\($t)] \(.)\n"
        else .[]
          | if .type == "text" then "[\($t)] \(.text)\n"
            elif .type == "tool_use" then tool(.name; .input | .description // .command // .file_path // .pattern // .skill)
            else empty end
        end
    else empty end'
}

# Commit and push the pending changes with Claude's /commit skill; args are passed to it (e.g. no-push, intent)
function gcai() {
  claude-p --model sonnet "/commit $*"
}

# True when worktree $1 has no changes and no commit missing from every other branch and remote
function _gwtclear_landed() {
  local b
  b=$(git -C "$1" branch --show-current)
  [[ -z "$(git -C "$1" status --porcelain)" ]] &&
    [[ "$(git -C "$1" rev-list --count HEAD --not ${b:+--exclude="$b"} --branches --remotes)" == 0 ]]
}

# Close linked worktrees of the current repo (or the repo dir in $1) after you pick them. Each tree gets a planned
# action: remove (safe), commit+push, remove (on a branch, dirty or unpushed), either one with "(live)" when a running
# session works in the tree, or keep:<reason> (detached with changes, unknown session state, differing include copies).
# Two or more actionable trees: an fzf checklist, all marked except (live) ones (space toggles, enter runs, esc
# cancels), with a preview of the focused tree's changed files and unpushed commits; one: those files and commits, then
# a y/N prompt, and a separate y/N per (live) tree.
# Marked safe trees go through wt-rm; marked commit trees go to Claude's /wt-close-all (args passed to it) as the
# approved list, standing in for the skill's own confirmation, which print mode can't ask, plus an optional note you type.
# A marked (live) tree is removed with wt-rm --discard despite its session, only once it is clean with nothing unpushed
function gwtclear() {
  local repo=. rows lines menu kept picked n ans dir commits note live bind p
  [[ -d "$1" ]] && repo=$1
  rows=$(wt-status "$repo") || return 1
  if [[ -z "$rows" ]]; then
    echo "gwtclear: no linked worktrees"
    return 0
  fi
  # "<dir>\t<remove|commit|liveremove|livecommit|keep|header>\t<aligned display>", header first
  lines=$(awk -F '\t' '
    {
      if ($6 == "safe") a = "remove"
      else if ($6 == "keep:live" && $4 == 0 && $5 == "0") a = "remove (live)"
      else if ($2 != "(detached)" && ($6 == "keep:dirty" || $6 == "keep:unpushed" || $6 == "keep:live"))
        a = "commit+push, remove" ($6 == "keep:live" ? " (live)" : "")
      else { a = $6; sub(/^keep:/, "keep: ", a) }
      m = split($1, p, "/")
      r++; D[r] = $1; A[r] = a; N[r] = p[m]; B[r] = $2; X[r] = $4; U[r] = $5
      K[r] = a ~ /^remove/ ? "remove" : (a ~ /^commit/ ? "commit" : "keep")
      if (a ~ /\(live\)$/) K[r] = "live" K[r]
      if (length(p[m]) > wn) wn = length(p[m]); if (length(a) > wa) wa = length(a); if (length($2) > wb) wb = length($2)
    }
    END {
      f = "%s\t%s\t%-" wn "s  %-" wa "s  %-" wb "s  %s\n"
      printf f, "-", "header", "WORKTREE", "ACTION", "BRANCH", "DIRTY/UNPUSHED"
      for (i = 1; i <= r; i++) printf f, D[i], K[i], N[i], A[i], B[i], X[i] "/" U[i]
    }' <<<"$rows")
  menu=$(awk -F '\t' '$2 != "keep"' <<<"$lines")
  kept=$(awk -F '\t' '$2 == "keep" { print $3 }' <<<"$lines")
  n=$(( $(grep -c . <<<"$menu") - 1 ))
  if (( n == 0 )); then
    cut -f3 <<<"$lines"
    echo "gwtclear: nothing to remove"
    return 0
  fi
  if (( n > 1 )) && command -v fzf >/dev/null; then
    # Mark every row, then unmark the (live) ones by their 1-based position under the header
    bind='load:select-all'
    for p in $(awk -F '\t' 'NR > 1 && $2 ~ /^live/ { print NR - 1 }' <<<"$menu"); do
      bind+="+pos($p)+deselect"
    done
    bind+='+first'
    picked=$(fzf --multi --no-input --no-sort --layout=reverse --height=60% --delimiter=$'\t' --with-nth=3 \
      --header-lines=1 --header="space: toggle · enter: run the marked trees · esc: cancel
(live) trees start unmarked: a running session works in them${kept:+
$kept}" \
      --marker='◉ ' --pointer='❯' --preview-window='right,50%,wrap' \
      --preview='git -C {1} status --short; echo; echo "unpushed commits:"; git -C {1} log --oneline HEAD --not --exclude="$(git -C {1} branch --show-current)" --branches --remotes' \
      --bind "$bind" \
      --bind 'space:toggle,enter:transform:[ "$FZF_SELECT_COUNT" -gt 0 ] && echo accept || echo abort' \
      <<<"$menu") || { echo "gwtclear: nothing done"; return 0; }
  else
    cut -f3 <<<"$lines"
    awk -F '\t' '$2 ~ /commit$/ { print $1 }' <<<"$menu" | while IFS= read -r dir; do
      printf '\n── %s\n' "${dir##*/}"
      git -C "$dir" status --short
      echo "unpushed commits:"
      git -C "$dir" log --oneline HEAD --not --exclude="$(git -C "$dir" branch --show-current)" --branches --remotes
    done
    echo
    picked=""
    p=$(awk -F '\t' '$2 == "remove" || $2 == "commit"' <<<"$menu" | grep -c .)
    if (( p > 0 )); then
      printf 'gwtclear: run the %s action(s) above? [y/N] ' "$p"
      read -r ans
      [[ "$ans" == [yY] ]] && picked=$(awk -F '\t' '$2 == "remove" || $2 == "commit"' <<<"$menu")
    fi
    while IFS=$'\t' read -r dir p live; do
      [[ "$p" == live* ]] || continue
      [[ "$p" == livecommit ]] && ans="commit, push and remove" || ans=remove
      printf 'gwtclear: %s %s too? A running session works in it [y/N] ' "$ans" "${dir##*/}"
      read -r ans </dev/tty
      [[ "$ans" == [yY] ]] || continue
      [[ -n "$picked" ]] && picked+=$'\n'
      picked+="$dir"$'\t'"$p"$'\t'"$live"
    done <<<"$menu"
    [[ -n "$picked" ]] || { echo "gwtclear: nothing done"; return 0; }
  fi
  awk -F '\t' '$2 == "remove" { print $1 }' <<<"$picked" | while IFS= read -r dir; do
    wt-rm "$dir"
  done
  # Clean when listed: re-check, then remove despite the session
  awk -F '\t' '$2 == "liveremove" { print $1 }' <<<"$picked" | while IFS= read -r dir; do
    if _gwtclear_landed "$dir"; then wt-rm --discard "$dir"
    else echo "gwtclear: kept $dir (changed since the listing)" >&2
    fi
  done
  commits=$(awk -F '\t' '$2 ~ /commit$/ { print $3 }' <<<"$picked")
  [[ -n "$commits" ]] || return 0
  live=$(awk -F '\t' '$2 == "livecommit" { print $1 }' <<<"$picked")
  printf 'gwtclear: note for Claude (optional, enter to skip): '
  read -r note
  claude-p "/wt-close-all $*
The user approved this list in gwtclear; treat it as the Step 2 answer go. Act on these trees only, and leave every
other tree as it is, safe ones included:
$commits${live:+

Rows marked (live) are approved for commit and push although wt-status classes them keep:live; commit them in Step 3
like the others. Leave their removal to gwtclear: Step 4 keeps them, which is expected.}${note:+

Note from the user: $note}"
  # The session in a (live) tree still counts as live; remove it once its work has landed
  [[ -n "$live" ]] || return 0
  while IFS= read -r dir; do
    if _gwtclear_landed "$dir"; then wt-rm --discard "$dir"
    else echo "gwtclear: kept $dir (not clean or not pushed after the commit)" >&2
    fi
  done <<<"$live"
  return 0
}

# Merge with Claude in print mode, in a new git worktree so the checkout stays clean; args are appended to the prompt
# (e.g. a branch or PR to merge). The name keeps --worktree from taking the prompt as its name; claude-p cleans it up
function ccmerge() {
  claude-p --worktree "ccmerge-$(date +%Y%m%d-%H%M%S)" "git merge $*"
}

# Prints a temp file holding private settings $1 deep-merged with --settings value $2 (a file or a JSON string),
# $2 winning on conflicts; fails when either side is not valid JSON
function _claude_merge_settings() {
  local private="$1" caller="$2" out
  out="$(mktemp "${TMPDIR:-/tmp}/claude-settings.XXXXXX")" || return 1
  if [[ -f "$caller" ]]; then
    jq -s '.[0] * .[1]' "$private" "$caller" >"$out" 2>/dev/null
  else
    printf '%s' "$caller" | jq -s '.[0] * .[1]' "$private" - >"$out" 2>/dev/null
  fi || { rm -f "$out"; return 1; }
  printf '%s\n' "$out"
}

# Adds the git-ignored claude/settings.private.json (autoMode environment, TokenScope telemetry env) to every launch.
# A caller's own --settings (claude-review's profile) is merged over it into a temp file, removed when claude exits
function claude() {
  local private="$HOME/.terminal/claude/settings.private.json"
  if [[ ! -f "$private" ]]; then
    command claude "$@"
    return
  fi
  local -a args=() temps=()
  local arg merged rc found=0 want_value=0 options_done=0
  for arg in "$@"; do
    if (( want_value )); then
      want_value=0
      if merged="$(_claude_merge_settings "$private" "$arg")"; then
        temps+=("$merged")
        arg="$merged"
      else
        echo "claude: could not merge settings.private.json into --settings $arg; using it unmerged" >&2
      fi
    elif (( ! options_done )) && [[ "$arg" == --settings ]]; then
      found=1
      want_value=1
    elif (( ! options_done )) && [[ "$arg" == --settings=* ]]; then
      found=1
      if merged="$(_claude_merge_settings "$private" "${arg#--settings=}")"; then
        temps+=("$merged")
        arg="--settings=$merged"
      else
        echo "claude: could not merge settings.private.json into $arg; using it unmerged" >&2
      fi
    elif [[ "$arg" == -- ]]; then
      options_done=1
    fi
    args+=("$arg")
  done
  if (( found )); then
    command claude "${args[@]}"
  else
    command claude --settings "$private" "${args[@]}"
  fi
  rc=$?
  (( ${#temps[@]} )) && rm -f "${temps[@]}"
  return $rc
}

# Claude Code for reviews: no claude-mem, auto-memory, MY-RULES or mattpocock-skills; args go to claude.
# Resume such a session with claude-review --resume <id> (claude-resume starts plain claude, which loads them again)
function claude-review() {
  claude --settings "$HOME/.terminal/claude/profiles/review.json" \
    --append-system-prompt "claude-mem and auto-memory are disabled in this session; skip instructions to save or search memory." \
    "$@"
}

# The pid of a running claude that has session $1 open (Claude Code keeps ~/.claude/sessions/<pid>.json for each);
# fails when none has. A second claude on a session that is still open gets suspended as it starts
function _claude_open_pid() {
  local f pid
  while IFS= read -r f; do
    pid=${f##*/}; pid=${pid%.json}
    kill -0 "$pid" 2>/dev/null && { echo "$pid"; return 0; }
  done < <(grep -rlF --include='*.json' "\"sessionId\":\"$1\"" "$HOME/.claude/sessions" 2>/dev/null)
  return 1
}

# Type a message into a running Claude Code session's tmux pane and submit it, as if typed there (a busy session takes
# it mid-turn). $1 is the session's id, id prefix or name; the message is the remaining args, else stdin
function claude-send() {
  local target=$1 msg f pid stat tty pane matches=()
  [[ $# -ge 1 ]] && shift
  msg=${*:-$(cat)}
  [[ -n "$target" && -n "$msg" ]] || { echo "usage: claude-send <session id|prefix|name> <message>" >&2; return 2; }

  for f in "$HOME"/.claude/sessions/*.json; do
    pid=${f##*/}; pid=${pid%.json}
    kill -0 "$pid" 2>/dev/null || continue
    jq -e --arg t "$target" '(.sessionId | startswith($t)) or .name == $t' "$f" >/dev/null && matches+=("$pid")
  done
  case ${#matches[@]} in
    0) echo "claude-send: no running session matches '$target'" >&2; return 1 ;;
    1) pid=${matches[*]} ;;
    *) echo "claude-send: '$target' matches several running sessions (pids ${matches[*]}); use more of the id" >&2; return 1 ;;
  esac

  # A pane can hold suspended claudes behind the one in front; only the foreground process (+) gets the keys
  read -r stat tty < <(ps -o stat=,tty= -p "$pid")
  [[ "$stat" == *+* ]] || {
    echo "claude-send: session '$target' (pid $pid) isn't in the foreground of its terminal ($tty, state $stat)" >&2
    return 1
  }
  pane=$(tmux list-panes -a -F '#{pane_id} #{pane_tty}' 2>/dev/null | awk -v t="/dev/$tty" '$2 == t { print $1; exit }')
  [[ -n "$pane" ]] || { echo "claude-send: session '$target' (pid $pid) isn't in a tmux pane" >&2; return 1; }

  # Bracketed paste keeps a multi-line message as one prompt; Enter then submits it
  printf %s "$msg" | tmux load-buffer -b claude-send - &&
    tmux paste-buffer -p -d -b claude-send -t "$pane" &&
    sleep 0.3 &&
    tmux send-keys -t "$pane" Enter &&
    echo "Sent to pane $pane (pid $pid)" >&2
}

# Pick a Claude Code session with fzf and resume it in its own directory; extra args go to claude
function claude-resume() {
  local picker="$HOME/.terminal/utils/agent-session-picker.sh"
  local sessions="$HOME/.terminal/claude/sessions.sh"
  local focus_script="$HOME/.terminal/utils/agent-focus.sh"
  local scope=here prompt='This dir> ' out key pick id pid

  # Start with every session when this directory has none
  [[ -d "$HOME/.claude/projects/${PWD//[^[:alnum:]]/-}" ]] || { scope=all; prompt='All> '; }

  out="$(
    source "$picker"
    run_agent_session_picker \
      --driver "$sessions" \
      --title "Resume Claude session" \
      --header $'[Enter] Resume · [Ctrl-O] Fork · [Ctrl-S] Copy ID\n[Ctrl-T] This dir/All · [Ctrl-G] Titles/Text · [Ctrl-R] Pattern · [Ctrl-P] Preview · [?] Keys' \
      --keys cr \
      --scope "$scope" \
      --prompt "$prompt"
  )" || return

  key="$(head -n 1 <<< "$out")" pick="$(sed -n 2p <<< "$out")" id="$(cut -f5 <<< "$pick")"
  # ctrl-o resumes into a new session id, leaving the original as it was; so does a session still open elsewhere
  if [[ -z "$key" ]] && pid="$(_claude_open_pid "$id")"; then
    echo "Session ${id:0:8} is open in claude (pid $pid): focusing or resuming a fork of it" >&2
    bash "$focus_script" "$pid" 2>/dev/null
    key=fork
  fi
  (cd "$(cut -f7 <<< "$pick")" && claude --resume "$id" ${key:+--fork-session} "$@")
}

# Open the claude-mem dashboard in the browser
function cm() {
  local url
  url="$(cm-sync url)" || return 1
  case "$ENV_PROFILE" in
    Mac) command open "$url" ;;
    Windows) explorer.exe "$url" ;;
    *) xdg-open "$url" >/dev/null 2>&1 & ;;
  esac
}

# Search claude-mem's memories, session summaries and your prompts with fzf: enter prints one, ctrl-o resumes the
# session it came from (extra args go to claude)
function claude-mem-search() {
  local mem="$HOME/.terminal/claude/memory.sh" scope=here prompt='Memories · This project> ' project out key pick cwd sid pid
  project="$(bash "$mem" project)" || return
  # Start with every record when claude-mem never saw this directory
  [[ -n "$project" ]] || { scope=all; prompt='Memories · All> '; }
  # Fields: age, type, ref, label (shown), then ref, Claude session id
  out="$(
    bash "$mem" list memories "$scope" | fzf --ansi \
      --header $'[Enter] Print · [Ctrl-O] Resume · [Ctrl-Y] Copy Ref · [Ctrl-R] Reveal\n[Ctrl-S] Memories/Summaries/Prompts · [Ctrl-T] Scope · [Ctrl-G] Text · [?] Keys' \
      --border rounded --border-label " Search claude-mem${project:+ · $project} " --preview-border rounded \
      --color 'border:8,label:6:bold,preview-border:8,preview-label:6:bold,info:8,separator:8,scrollbar:8' \
      --color 'prompt:6:bold,pointer:5,marker:5,hl:3:bold,hl+:3:bold,fg+:-1:bold,query:-1:bold' \
      --prompt "$prompt" --delimiter='\t' --with-nth=1,2,3,4 --tabstop=1 --no-sort --expect=ctrl-o \
      --bind='focus:transform-preview-label:printf " %s " {5}' \
      --bind="ctrl-s:transform:bash $mem key source" \
      --bind="ctrl-t:transform:bash $mem key scope" \
      --bind="ctrl-g:transform:bash $mem key mode" \
      --bind="change:transform:bash $mem key change" \
      --bind="ctrl-y:execute-silent(printf %s {5} | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null))+abort" \
      --bind="ctrl-r:change-preview(bash $mem preview {5} reveal)" \
      --bind="?:transform:bash $HOME/.terminal/utils/fzf-keys.sh bind cms" \
      --preview="bash $mem preview {5}" \
      --preview-window 'right,55%,wrap' --height 60% --layout reverse
  )" || return
  key="$(head -n 1 <<< "$out")" pick="$(sed -n 2p <<< "$out")"
  if [[ -z "$key" ]]; then
    bash "$mem" show "$(cut -f5 <<< "$pick")"
    return
  fi
  sid="$(cut -f6 <<< "$pick")"
  [[ -n "$sid" ]] || { echo "No Claude session recorded for $(cut -f5 <<< "$pick")" >&2; return 1; }
  cwd="$(bash "$mem" session "$sid")" || return
  if pid="$(_claude_open_pid "$sid")"; then
    echo "Session ${sid:0:8} is open in claude (pid $pid): resuming a fork of it" >&2
    set -- --fork-session "$@"
  fi
  (cd "$cwd" && claude --resume "$sid" "$@")
}

alias cr="claude-resume"
alias cms="claude-mem-search"

alias omp='ollama launch omp'
alias omp-new='omp session start'

# cc <session-uuid> [args] resumes that session in its own directory, like claude-resume (a fork when it is still
# open elsewhere); anything else passes through to claude
function cc() {
  local sid cwd pid
  [[ "${1:-}" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || { claude "$@"; return; }
  sid=$1; shift
  cwd="$(bash "$HOME/.terminal/claude/memory.sh" session "$sid")" || return
  if pid="$(_claude_open_pid "$sid")"; then
    echo "Session ${sid:0:8} is open in claude (pid $pid): focusing or resuming a fork of it" >&2
    bash "$HOME/.terminal/utils/agent-focus.sh" "$pid" 2>/dev/null
    set -- --fork-session "$@"
  fi
  (cd "$cwd" && claude --resume "$sid" "$@")
}
alias ccp="claude-p"
alias ct="claude-tail"
alias csend="claude-send"
