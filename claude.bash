#!/bin/bash

# claude-mem sync between devices (see README "claude-mem sync")
function cm-sync() {
  python3 -I "$SCRIPT_DIR/claude/cm_sync.py" "$@"
}
