#!/bin/bash
# WorktreeRemove hook: Claude calls it when the user picks "Remove" at exit (cw and EnterWorktree trees), after
# warning that unpushed commits may be lost. Force-removes the tree; a branch with commits is kept (wt-rm --discard).
# stdin: {session_id, cwd, worktree_path}. Non-zero keeps the tree
source "$(dirname "$0")/../wt.bash" || exit 1
dir=$(jq -r '.worktree_path // empty' | sed 's:/*$::')
[[ -n "$dir" && "$dir" == */.claude/worktrees/* ]] || { echo "worktree-remove: not a .claude/worktrees path: $dir" >&2; exit 1; }
wt-rm --discard "$dir"
