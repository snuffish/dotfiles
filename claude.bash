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

# Lint the skills registry and check ~/.claude/skills against it; --apply fixes the links
function sync-skills() {
  python3 -I "$HOME/.terminal/skills/sync-skills/sync_skills.py" "$@"
}

# Pick a Claude Code session with fzf and resume it in its own directory; extra args go to claude
function claude-resume() {
  local sessions="$HOME/.terminal/claude/sessions.sh" scope=here prompt='This dir> ' pick
  # Start with every session when this directory has none
  [[ -d "$HOME/.claude/projects/${PWD//[^[:alnum:]]/-}" ]] || { scope=all; prompt='All> '; }
  pick="$(
    bash "$sessions" list "$scope" | fzf --header '[Enter] Resume | [Ctrl-T] This dir / All | [Ctrl-S] Copy id' \
      --prompt "$prompt" --delimiter='\t' --with-nth=1,2,3 --tiebreak=index \
      --bind="ctrl-t:transform:[ \"\$FZF_PROMPT\" = 'All> ' ] && echo 'change-prompt(This dir> )+reload(bash $sessions list here)' || echo 'change-prompt(All> )+reload(bash $sessions list all)'" \
      --bind="ctrl-s:execute-silent(printf %s {2} | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null))+abort" \
      --preview="bash $sessions preview {4}" \
      --preview-window wrap --height 50% --layout reverse
  )" || return
  (cd "$(cut -f5 <<< "$pick")" && claude --resume "$(cut -f2 <<< "$pick")" "$@")
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

alias cr="claude-resume"
