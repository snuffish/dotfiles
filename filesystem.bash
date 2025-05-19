#!/bin/bash

# Set defaults if not set above
[[ $(aliasExists ".dl") -eq 0 ]] && alias .dl='cd "$HOME/Downloads"'
[[ $(aliasExists ".ssh") -eq 0 ]] && alias .ssh='cd "$HOME/.ssh"'
[[ $(aliasExists ".logs") -eq 0 ]] && alias .logs='cd "$HOME/.logs"'
[[ $(aliasExists ".terminal") -eq 0 ]] && alias .terminal='cd "$HOME/.terminal"'
[[ $(aliasExists ".t") -eq 0 ]] && alias .t='cd "$HOME/.terminal"'

[[ $(aliasExists ".") -eq 0 ]] && alias .='cd "$HOME"'
[[ $(aliasExists "..") -eq 0 ]] && alias ..="cd .."

alias .tmp='cd "$HOME/.tmp"'
alias .logs='cd "$HOME/.logs"'

alias -- -="cd -"

mkcd() {
  mkdir -p "$@" && cd "$_" || return
}

alias rm="rm -rf"

alias ls="exa -la --icons --group-directories-first --color=always"
alias l=ls

alias lt="ls -T"
alias cat="bat"

alias find="find . -name"

alias untar="tar -xvzf"

alias dirsize="du -hs"

alias .ghostty='cd "$HOME/Library/Application Support/com.mitchellh.ghostty"'

alias space="du -d1 -h 2>/dev/null | sort -h"


