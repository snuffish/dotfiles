#!/bin/bash
input=$(cat)

model=$(echo "$input" | /usr/bin/jq -r '.model.display_name // empty')
dir=$(echo "$input" | /usr/bin/jq -r '.workspace.current_dir // .cwd // empty')
used=$(echo "$input" | /usr/bin/jq -r '.context_window.used_percentage // empty')
transcript=$(echo "$input" | /usr/bin/jq -r '.transcript_path // empty')
session=$(echo "$input" | /usr/bin/jq -r '.session_id // empty')
git_wt=$(echo "$input" | /usr/bin/jq -r '.workspace.git_worktree // empty')

# /rename sets customTitle; otherwise fall back to the generated aiTitle
title=""
if [ -f "$transcript" ]; then
  title=$(grep -o '"customTitle":"[^"]*"' "$transcript" | tail -1 | cut -d'"' -f4)
  [ -z "$title" ] && title=$(grep -o '"aiTitle":"[^"]*"' "$transcript" | tail -1 | cut -d'"' -f4)
fi

parts=()
[ -n "$model" ] && parts+=("$(printf '\033[36m%s\033[0m' "$model")")
[ -n "$title" ] && parts+=("$(printf '\033[35m%s\033[0m' "$title")")

if [ -n "$dir" ]; then
  parts+=("$(printf '\033[34m%s\033[0m' "$(basename "$dir")")")
  branch=$(git --no-optional-locks -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git --no-optional-locks -C "$dir" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && parts+=("$(printf '\033[32m%s\033[0m' "$branch")")

  # cwd inside a linked worktree: its git dir differs from the common dir. Fallback when stdin lacks git_worktree
  { read -r toplevel; read -r git_dir; read -r common_dir; } < <(git --no-optional-locks -C "$dir" rev-parse --path-format=absolute --show-toplevel --git-dir --git-common-dir 2>/dev/null)
  cwd_wt="$git_wt"
  [ -z "$cwd_wt" ] && [ -n "$toplevel" ] && [ "$git_dir" != "$common_dir" ] && cwd_wt=$(basename "$git_dir")

  # Worktrees this session edits from outside: the git-worktrees Module locks them with "session:<id>"
  owned=""
  if [ -n "$session" ]; then
    repos=()
    if [ -n "$toplevel" ]; then
      repos=("$toplevel")
    else
      for g in "$dir"/*/.git; do [ -e "$g" ] && repos+=("$(dirname "$g")"); done
    fi
    # Sibling worktrees of one repo list the same entries, hence the dedupe; a locked worktree is never "prunable", hence the -d
    owned=$(for r in "${repos[@]}"; do
      git --no-optional-locks -C "$r" worktree list --porcelain 2>/dev/null | awk -v sid="session:$session " -v cur="$toplevel" '
        function flush() {
          if (dir != "" && !prunable && dir != cur && index(lock " ", sid)) print dir
          dir = ""; lock = ""; prunable = 0
        }
        /^worktree / { flush(); dir = substr($0, 10); next }
        /^locked/    { lock = $0; next }
        /^prunable/  { prunable = 1; next }
        END          { flush() }
      '
    done | awk '!seen[$0]++' | while read -r d; do [ -d "$d" ] && basename "$d"; done | paste -sd, -)
  fi

  [ -n "$cwd_wt" ] && parts+=("$(printf '\033[31mwt:%s\033[0m' "$cwd_wt")")
  [ -n "$owned" ] && parts+=("$(printf '\033[31mwt→%s\033[0m' "$owned")")
  [ -z "$cwd_wt$owned" ] && [ -n "$toplevel" ] && parts+=("$(printf '\033[2mno-wt\033[0m')")
fi

if [ -n "$used" ]; then
  parts+=("$(printf '\033[33mctx %.0f%%\033[0m' "$used")")
fi

out=""
for p in "${parts[@]}"; do
  if [ -z "$out" ]; then out="$p"; else out="$out | $p"; fi
done
printf '%s' "$out"
