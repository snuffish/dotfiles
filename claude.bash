#!/bin/bash

# Lint the skills registry and check skill loaders against it, then ask y/n to fix the links when any are pending (--apply skips the prompt)
function sync-skills() {
  local script="$HOME/.terminal/skills/sync-skills/sync_skills.py" answer rc
  [[ " $* " == *" --apply "* ]] && { python3 -I "$script" "$@"; return; }
  python3 -I "$script" --exit-pending "$@"; rc=$?
  (( rc == 10 || rc == 1 )) || return 0
  printf '\n\033[1mApply link changes?\033[0m \033[2m(Claude, Antigravity, Gemini)\033[0m [y/N] '
  read -r answer
  if [[ "$answer" == [yY]* ]]; then
    python3 -I "$script" --apply "$@"
  fi
}

# claude -p with live progress: the session id and each tool call go to stderr as they start, the final answer to
# stdout; args go to claude
function claude-p() {
  claude -p --output-format stream-json --verbose "$@" | jq --unbuffered -rj '
    if .type == "system" and .subtype == "init" then
      "\u001b[2msession \(.session_id)\u001b[0m\n" | stderr | empty
    elif .type == "assistant" then
      .message.content[] | select(.type == "tool_use")
      | (.input | .description // .command // .file_path // .pattern // .skill // "" | tostring | gsub("\n"; " ") | .[0:80]) as $arg
      | "\u001b[2m→ \(.name) \($arg)\u001b[0m\n" | stderr | empty
    elif .type == "result" then .result + "\n"
    else empty end'
  return "${PIPESTATUS[0]:-${pipestatus[1]}}"
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
  claude-p "/commit $*"
}

# Claude Code for reviews: no claude-mem, auto-memory, MY-RULES or mattpocock-skills; args go to claude.
# Resume such a session with claude-review --resume <id> (claude-resume starts plain claude, which loads them again)
function claude-review() {
  claude --settings "$HOME/.terminal/.claude/profiles/review.json" \
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
      --header $'[Enter] Resume · [Ctrl-O] Fork · [Ctrl-S] Copy ID\n[Ctrl-T] This dir/All · [Ctrl-G] Titles/Text' \
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
      --header $'[Enter] Print · [Ctrl-O] Resume · [Ctrl-Y] Copy Ref · [Ctrl-R] Reveal\n[Ctrl-S] Memories/Summaries/Prompts · [Ctrl-T] Scope · [Ctrl-G] Text' \
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

alias cc="claude"
alias ccp="claude-p"
alias ctail="claude-tail"
alias csend="claude-send"
