#!/bin/bash
# Verb facade over ~/.terminal/wt.bash for /wt-close-all, so each step is one simple command; no logic of its own.
#   status <repo> [session id]   wt-status rows (dir, branch, live, dirty, unpushed, class, lock); the id doesn't count as live
#   rm <session id> <dir>        wt-rm --self: removes the tree only when wt-status calls it safe
source "$(dirname "$(realpath "$0")")/../../../wt.bash" || exit 1

case "$1" in
  status) wt-status "$2" "$3" ;;
  rm) wt-rm --self "$2" "$3" ;;
  *) echo "usage: wt-close-all.sh status <repo> [session id] | rm <session id> <dir>" >&2; exit 2 ;;
esac
