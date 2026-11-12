#!/bin/bash
# SessionEnd hook: sweeps the safe worktrees of the ending session's repo (wt-sweep --apply). Detached, so exit never
# waits on it; the session's own tree still counts as live here and goes on a later sweep. Log: ~/.cache/wt-sweep.log
# stdin: {session_id, cwd, ...}
cwd=$(jq -r '.cwd // empty')
[[ -n "$cwd" ]] || exit 0
common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
nohup bash -c 'source "$1" && wt-sweep --apply "$2"' _ "$(dirname "$0")/../wt.bash" "$(dirname "$common")" >/dev/null 2>&1 &
