#!/bin/bash

alias tm="tmux attach -t \$(tmux list-windows -a | fzf --preview 'echo \"<TODO>\"' --height 50% --layout reverse | sed 's/: .*//g')"
alias tmnew="tmux new -s"
alias tmattach="tmux attach -t"
alias tmkill="tmux kill-session -t"
