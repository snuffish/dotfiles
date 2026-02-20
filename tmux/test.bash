#!/bin/bash

DATA=$(tmux list-windows -a | fzf --reverse | sed 's/: .*//g')

# Check if DATA is empty
if [ -z "$DATA" ]; then
  read -p "No session selected. Enter a new session name: " NEW_SESSION
  tmux new-session -s "$NEW_SESSION"
else
  tmux attach -t "$DATA"
fi
