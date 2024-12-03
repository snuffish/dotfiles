#!/bin/bash

alias .nvim="cd \$HOME/.config/nvim"
alias .n=".nvim"
alias n="nvim"

alias nf="nvim \$(fzf --preview 'bat --color=always {}' --preview-window '~3')"
