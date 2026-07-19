#!/bin/bash

if [[ "$SHELL" == "/bin/bash" ]]; then
  alias reload="source ~/.bashrc"
else
  alias reload="source ~/.zshrc"
fi

if [[ $ENV_PROFILE == "Linux" ]]; then
  alias pbcopy="wl-copy"
  alias pbpaste="wl-paste"
fi

alias pwdc="pwd|pbcopy"

alias q="exit"
alias c="clear"

alias wget="wget -c"

alias psg="ps aux | grep -v grep | grep -i"

alias sysinfo="lsb_release -a"

alias myip="curl -s ipinfo.io/json | jq '.'"

alias hs="history"

alias timestamp="date +%s%N | cut -b1-13"

alias xmod="xmodmap ~/.terminal/.Xmodmap"

alias pgrep="pgrep --list-full"

function today() {
  date -u "+%F %T (Week %V)"
  date -u "+%A -%eth of %B"
}
