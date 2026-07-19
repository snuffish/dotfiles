#!/bin/bash

tm() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "Error: tmux is not installed."
    return 1
  fi
  if ! tmux list-sessions >/dev/null 2>&1; then
    echo "No active tmux sessions found. Creating a new session..."
    tmux new-session
    return
  fi
  local session
  session=$(tmux list-sessions | fzf --header 'Select tmux session to open:' \
    --preview-window='right:70%:follow' \
    --preview 'tmux capture-pane -ept $(echo {} | cut -d: -f1)' \
    --height 80% --layout reverse | cut -d: -f1)
  if [[ -n "$session" ]]; then
    tmux attach -t "$session"
  fi
}

alias tmn="tmux new -s"

tmk() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "Error: tmux is not installed."
    return 1
  fi
  if ! tmux list-sessions >/dev/null 2>&1; then
    echo "No active tmux sessions found."
    return
  fi
  local session
  session=$(tmux list-sessions | fzf --header 'Select tmux session to kill:' \
    --preview-window='right:70%:follow' \
    --preview 'tmux capture-pane -ept $(echo {} | cut -d: -f1)' \
    --height 80% --layout reverse | cut -d: -f1)
  if [[ -n "$session" ]]; then
    tmux kill-session -t "$session"
    echo "Killed tmux session: $session"
  fi
}
