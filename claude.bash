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
