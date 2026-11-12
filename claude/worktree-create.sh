#!/bin/bash
# WorktreeCreate hook: replaces Claude's own git worktree creation for -w, --tmux, --bg, EnterWorktree and isolation.
# stdin: {session_id, cwd (the main checkout), name}. Branch = $CW_BRANCH (set by cw), else chore/<name>.
# wt-new prints its progress to stderr and the worktree path last on stdout, which Claude reads
source "$(dirname "$0")/../wt.bash" || exit 1
input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
name=$(jq -r '.name // empty' <<<"$input")
session=$(jq -r '.session_id // empty' <<<"$input")
[[ -n "$cwd" && -n "$name" ]] || { echo "worktree-create: missing cwd or name in hook input" >&2; exit 1; }
# claude -w <name> on a tree that already exists resumes it, as Claude's own creation does
main=$(_wt_main "$cwd") || exit 1
if [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] &&
  git -C "$main" worktree list --porcelain | grep -qxF "worktree $main/.claude/worktrees/$name"; then
  echo "$main/.claude/worktrees/$name"
  exit 0
fi
branch=${CW_BRANCH:-chore/$name}
# CW_BRANCH stays in the env of a cw session, so a later EnterWorktree finds it checked out already
git -C "$cwd" worktree list --porcelain | grep -qxF "branch refs/heads/$branch" && branch=chore/$name CW_BASE=""
wt-new "$cwd" "$name" --branch "$branch" ${CW_BASE:+--base "$CW_BASE"} ${session:+--session "$session"}
