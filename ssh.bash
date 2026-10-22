#!/bin/bash

alias ssh_eval="eval \"$(ssh-agent -s)\""

alias ssh_home="ssh 212.181.207.74"

SSH_SESSION_BG="${SSH_SESSION_BG:-#010f1a}"

# Args: (colour) — sets this pane's background, or resets it when empty
function _sshSetBackground() {
  if [[ -n "$TMUX" && -n "$TMUX_PANE" ]]; then
    if [[ -n "$1" ]]; then
      tmux set -p -t "$TMUX_PANE" window-style "bg=$1"
    else
      tmux set -pu -t "$TMUX_PANE" window-style
    fi
  elif [[ -n "$1" ]]; then
    printf '\e]11;%s\a' "$1"
  else
    printf '\e]111\a'
  fi
}

# Returns 0 when the args hold -f or -N in a cluster of ssh's argument-less flags
function _sshIsBackground() {
  local re='^-[46AaCfGgKkMNnqsTtVvXxYy]*[fN]' arg
  for arg in "$@"; do
    [[ $arg =~ $re ]] && return 0
  done
  return 1
}

# Tints the pane while an interactive ssh session runs
function ssh() {
  if [[ -n "$SSH_CONNECTION" || ! -t 0 || ! -t 1 ]] || _sshIsBackground "$@"; then
    command ssh "$@"
    return
  fi

  local rc
  _sshSetBackground "$SSH_SESSION_BG"
  # A no-op trap keeps Ctrl-C from aborting the function before the reset
  trap ':' INT
  command ssh "$@"
  rc=$?
  trap - INT
  _sshSetBackground ""
  return $rc
}
