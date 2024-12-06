#!/bin/bash

# alias tm="tmux attach -t \$(tmux list-windows -a | fzf --preview 'echo \"<TODO>\"' --height 50% --layout reverse | sed 's/: .*//g')"

DATA=$(tmux list-windows -a)
echo "$DATA"
