#!/usr/bin/env bash
# Puts the adopr activity badge in front of status-right (run from tmux.conf after tpm).
# The status line only cats the file utils/adopr.sh poll writes; it never calls az. Safe to run again.
current="$(tmux show -gv status-right)"
case "$current" in
  *adopr/badge*) exit 0 ;;
esac
tmux set -g status-right "#(cat ~/.cache/adopr/badge 2>/dev/null)$current"
