#!/bin/bash

if [[ "$SHELL" == "/bin/bash" ]]; then
  alias reload="source ~/.bashrc"
else
  alias reload="source ~/.zshrc"
fi

alias pwdc="pwd|pbcopy"

alias q="exit"
alias c="clear"

alias wget="wget -c"

alias ps="ps aux | grep -v grep | grep -i -e VSZ -e"

alias sysinfo="lsb_release -a"

alias myip="curl ipinfo.io/json &> /dev/null | jq '.'"

alias hs="history"

alias timestamp="date +%s%N | cut -b1-13"

alias xmod="xmodmap ~/.terminal/.Xmodmap"
