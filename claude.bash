#!/bin/bash

# claude-mem sync between devices: https://github.com/snuffish/cm-sync
function cm-sync() {
  local engine="$HOME/Projects/cm-sync/cm_sync.py"
  if [[ ! -f "$engine" ]]; then
    echo "cm-sync is not installed: git clone git@github.com:snuffish/cm-sync.git ~/Projects/cm-sync" >&2
    return 1
  fi
  python3 -I "$engine" "$@"
}
