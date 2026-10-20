#!/bin/bash
input=$(cat)

model=$(echo "$input" | /usr/bin/jq -r '.model.display_name // empty')
dir=$(echo "$input" | /usr/bin/jq -r '.workspace.current_dir // .cwd // empty')
used=$(echo "$input" | /usr/bin/jq -r '.context_window.used_percentage // empty')
transcript=$(echo "$input" | /usr/bin/jq -r '.transcript_path // empty')

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
fi

if [ -n "$used" ]; then
  parts+=("$(printf '\033[33mctx %.0f%%\033[0m' "$used")")
fi

out=""
for p in "${parts[@]}"; do
  if [ -z "$out" ]; then out="$p"; else out="$out | $p"; fi
done
printf '%s' "$out"
