#!/usr/bin/env bash
# Publish a draft as a new artifact without overwriting anyone's file (artifact-protocol › Claim).
# Usage: publish_new_artifact.sh <draft-file> <target-path-without-extension> [extension, default md]
# Creates <target>.<ext> with O_EXCL (set -C); on collision tries <target>-2.<ext>, -3, … Prints the path.
set -u
draft="$1" base="$2" ext="${3:-md}"
p="$base.$ext" n=1
until ( set -C; cat "$draft" > "$p" ) 2>/dev/null; do
  n=$((n + 1))
  p="$base-$n.$ext"
done
printf '%s\n' "$p"
