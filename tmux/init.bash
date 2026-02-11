#!/bin/bash

alias tm="tmux attach -t \$(tmux list-sessions | fzf --header 'Select tmux session to open:' --preview-window='right:70%:follow' --preview 'tmux capture-pane -ept \$(echo {} | cut -d: -f1)' --height 80% --layout reverse | sed 's/: .*//g')"
alias tmn="tmux new -s"
alias tmk="tmux kill-session -t \$(tmux list-sessions | fzf --header 'Select tmux session to kill:' --preview-window='right:70%:follow' --preview 'tmux capture-pane -ept \$(echo {} | cut -d: -f1)' --height 80% --layout reverse  | sed 's/: .*//g')"
