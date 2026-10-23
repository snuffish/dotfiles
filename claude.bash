#!/bin/bash

# claude-mem sync between devices: https://github.com/snuffish/cm-sync
function cm-sync() {
  local engine="$HOME/Projects/cm-sync/cm_sync.py"
  if [[ ! -f "$engine" ]]; then
    echo "cm-sync is not installed: git clone git@github.com:snuffish/cm-sync.git ~/Projects/cm-sync" >&2
    return 1
  fi
  CM_SYNC_REPO="${CM_SYNC_REPO:-$HOME/.terminal/memory}" \
  CM_SYNC_REMOTE="${CM_SYNC_REMOTE:-git@github.com:snuffish/claude-memory.git}" \
    python3 -I "$engine" "$@"
}

# Lint the skills registry and check ~/.claude/skills against it, then ask y/n to fix the links (--apply skips the prompt)
function sync-skills() {
  local script="$HOME/.terminal/skills/sync-skills/sync_skills.py" answer
  [[ " $* " == *" --apply "* ]] && { python3 -I "$script" "$@"; return; }
  python3 -I "$script" "$@"
  printf 'Apply the link changes to ~/.claude/skills? [y/N] '
  read -r answer
  if [[ "$answer" == [yY]* ]]; then
    python3 -I "$script" --apply "$@"
  fi
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

# Pick a Claude Code session with fzf and resume it in its own directory; extra args go to claude
function claude-resume() {
  local sessions="$HOME/.terminal/claude/sessions.sh" scope=here prompt='This dir> ' out key pick id pid
  # Start with every session when this directory has none
  [[ -d "$HOME/.claude/projects/${PWD//[^[:alnum:]]/-}" ]] || { scope=all; prompt='All> '; }
  # Fields: age, short id, branch, label (shown), then id, transcript, cwd
  out="$(
    bash "$sessions" list "$scope" | fzf --ansi --header 'enter resume · ctrl-o fork · ctrl-t this dir / all · ctrl-g titles / text · ctrl-s copy id' \
      --border rounded --border-label ' Resume Claude session ' --preview-border rounded \
      --color 'border:8,label:6:bold,preview-border:8,preview-label:6:bold,header:8:italic,info:8,separator:8,scrollbar:8' \
      --color 'prompt:6:bold,pointer:5,marker:5,hl:3:bold,hl+:3:bold,fg+:-1:bold,query:-1:bold' \
      --prompt "$prompt" --delimiter='\t' --with-nth=1,2,3,4 --no-sort --expect=ctrl-o \
      --bind='focus:transform-preview-label:printf " %s " {4}' \
      --bind="ctrl-t:transform:bash $sessions key scope" \
      --bind="ctrl-g:transform:bash $sessions key mode" \
      --bind="change:transform:bash $sessions key change" \
      --bind="ctrl-s:execute-silent(printf %s {5} | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null))+abort" \
      --preview="bash $sessions preview {6}" \
      --preview-window 'right,55%,wrap,follow' --height 60% --layout reverse
  )" || return
  key="$(head -n 1 <<< "$out")" pick="$(sed -n 2p <<< "$out")" id="$(cut -f5 <<< "$pick")"
  # ctrl-o resumes into a new session id, leaving the original as it was; so does a session still open elsewhere
  if [[ -z "$key" ]] && pid="$(_claude_open_pid "$id")"; then
    echo "Session ${id:0:8} is open in claude (pid $pid): resuming a fork of it" >&2
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
      --header $'enter print · ctrl-o resume · ctrl-y copy ref · ctrl-r reveal\nctrl-s memories / summaries / prompts · ctrl-t scope · ctrl-g text' \
      --border rounded --border-label " Search claude-mem${project:+ · $project} " --preview-border rounded \
      --color 'border:8,label:6:bold,preview-border:8,preview-label:6:bold,header:8:italic,info:8,separator:8,scrollbar:8' \
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
