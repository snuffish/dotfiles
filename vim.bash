#!/bin/bash

alias .nvim="cd \$HOME/.config/nvim"
alias .v=".nvim"
alias v="nvim"
alias vim="nvim"

alias vf="nvim \$(fzf --preview 'bat --color=always {}' --preview-window '~3')"
