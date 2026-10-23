#!/bin/bash
# SessionStart hook: names a new session after its git branch, e.g. bugfix/31230_cluster-nearby-map-pins → "31230 cluster-nearby-map-pins".
# Prints nothing when there is no useful name, so Claude's generated title applies instead
input=$(cat)

{ read -r source; read -r cwd; read -r session_title; } < <(echo "$input" | /usr/bin/jq -r \
  '.source, .cwd, .session_title | . // ""')

# A title from --name, /rename or an earlier hook wins. Resume is skipped: the checkout may have moved on from the session's branch
[ -n "$session_title" ] && exit 0
[ "$source" = startup ] || exit 0
[ -n "$cwd" ] || exit 0

name=$(git --no-optional-locks -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null)
case "$name" in main|master|develop) name="" ;; esac

# A linked worktree on a generic branch or a detached HEAD: its folder name usually says what it is for
if [ -z "$name" ]; then
  { read -r git_dir; read -r common_dir; } < <(git --no-optional-locks -C "$cwd" rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null)
  [ -n "$git_dir" ] && [ "$git_dir" != "$common_dir" ] && name=$(basename "$git_dir")
fi

name=$(printf '%s' "$name" | sed -E 's#^[A-Za-z]+/##; s#^worktree-##; s#^([0-9]+)_#\1 #')
name=${name:0:50}
[ -n "$name" ] || exit 0

/usr/bin/jq -nc --arg t "$name" '{hookSpecificOutput: {hookEventName: "SessionStart", sessionTitle: $t}}'
