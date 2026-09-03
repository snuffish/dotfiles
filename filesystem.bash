#!/bin/bash

# Set defaults if not set above
[[ $(aliasExists ".dl") -eq 0 ]] && alias .dl='cd "$HOME/Downloads"'
[[ $(aliasExists ".ssh") -eq 0 ]] && alias .ssh='cd "$HOME/.ssh"'
[[ $(aliasExists ".logs") -eq 0 ]] && alias .logs='cd "$HOME/.logs"'
[[ $(aliasExists ".terminal") -eq 0 ]] && alias .terminal='cd "$HOME/.terminal"'
[[ $(aliasExists ".t") -eq 0 ]] && alias .t='cd "$HOME/.terminal"'

[[ $(aliasExists "..") -eq 0 ]] && alias ..="cd .."

if [[ $ENV_PROFILE == "Linux" ]]; then
  alias .disken="cd /mnt/disken"
fi

alias rm="rm -rf"

alias -- -="cd -"

mkcd() {
  mkdir -p "$@" && cd "$_" || return
}

if command -v eza >/dev/null 2>&1; then
  alias ls="eza -laho --octal-permissions --icons=always --group-directories-first"
  alias l=ls
  alias lD="ls -D"
  alias ldot="ls -ld .*"
  alias lt="ls -T"
else
  alias ls="ls -la --color=auto"
  alias l=ls
fi

if command -v bat >/dev/null 2>&1; then
  alias cat="bat"
elif command -v batcat >/dev/null 2>&1; then
  alias cat="batcat"
fi

ff() {
  if [[ -z "$1" ]]; then
    echo "Usage: ff <filename_pattern>"
    return 1
  fi
  find . -name "$1"
}

alias untar="tar -xvzf"

alias dirsize="du -hs"

alias .ghostty='cd "$HOME/Library/Application Support/com.mitchellh.ghostty"'

alias space="du -d1 -h 2>/dev/null | sort -h"

if [[ $ENV_PROFILE == "Linux" ]]; then
  alias diskspace='df -h -x squashfs -x tmpfs -x devtmpfs'
else
  alias diskspace="df -h /"
fi
