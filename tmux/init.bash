#!/bin/bash

alias tm="tmux attach -t \$(tmux list-windows -a | fzf --preview 'echo \"<TODO>\"' --height 50% --layout reverse | sed 's/: .*//g')"
alias tn="tmux new -s"
alias ta="tmux attach -t"
alias tk="tmux kill-session -t"