#!/bin/bash

if [[ "$SHELL" == "/bin/bash" ]]; then
  alias reload="source ~/.bashrc"
else
  alias reload="source ~/.zshrc"
fi


alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'

alias pwdc="pwd|pbcopy"

alias c="clear"

alias wget="wget -c"

alias ps="ps aux | grep -v grep | grep -i -e VSZ -e"

alias sysinfo="lsb_release -a"

alias myip="curl ipinfo.io/json &> /dev/null | jq '.'"

alias hs="history"

alias timestamp="date +%s%N | cut -b1-13"

alias xmod="xmodmap ~/.terminal/.Xmodmap"

# function regex { gawk 'match($0,/'$1'/, ary) {print ary['${2:-'0'}']}'; }
