#!/usr/bin/env bash
# Hooks the ADO pill and overlay into tmux (run from tmux.conf with run-shell, after tpm). Safe to run again.
# Prefix a, or a click on the pill, opens the overlay above the status line; the overlay binds Esc/q/✕ to close itself.
# Not M-a: that needs Ghostty's macos-option-as-alt, which breaks Option-typed characters (] [ { } | @ $) on the Swedish layout.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

current="$(tmux show -gv status-right)"
case "$current" in
  *ado-status*) ;;
  *) tmux set -g status-right "#[range=user|ado]#($here/ado-status)#[norange]$current" ;;
esac

# Width min(64, client width - 4), right-aligned, bottom edge on the status line (sizes in ado-popup)
popup="run-shell -b \"'$here/ado-popup' '#{client_name}' '#{client_width}'\""
tmux unbind -n M-a 2>/dev/null
tmux bind a "$popup"
# Clicks outside the pill keep tmux's default for this binding (select the clicked window)
tmux bind -n MouseDown1Status if -F '#{==:#{mouse_status_range},ado}' "$popup" 'select-window -t ='
