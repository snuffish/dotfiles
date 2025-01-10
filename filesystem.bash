#!/bin/bash

# Set defaults if not set above
[[ $(aliasExists ".dl") -eq 0 ]] && alias .dl="cd $HOME/Downloads"
[[ $(aliasExists ".ssh") -eq 0 ]] && alias .ssh="cd $HOME/.ssh"
[[ $(aliasExists ".logs") -eq 0 ]] && alias .logs="cd $HOME/.logs"
[[ $(aliasExists ".terminal") -eq 0 ]] && alias .terminal="cd $HOME/.terminal"
[[ $(aliasExists ".t") -eq 0 ]] && alias .t="cd $HOME/.terminal"

[[ $(aliasExists ".cd") -eq 0 ]] && alias .="cd $HOME"
[[ $(aliasExists "..") -eq 0 ]] && alias ..="cd .."

alias .dl="cd $HOME/Downloads"
alias .ssh="cd $HOME/.ssh"
alias .tmp="cd $HOME/.tmp"
alias .logs="cd $HOME/.logs"

alias .="cd $HOME"
alias ..="cd .."
alias -- -="cd -"

mkcd() {
  mkdir -p "$@" && cd "$_"
}

alias rm="rm -rf"

alias {l,ls}="exa -la --icons --group-directories-first --color=always"
alias lt="ls -T"
alias cat="bat"

alias find="find . -name"

alias untar="tar -xvzf"

alias dirsize="du -hs"
