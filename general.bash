#!/bin/bash

alias reload="source ~/.bashrc"
# if [[ "$SHELL" == "/bin/bash" ]]; then
# else
#   alias reload="source ~/.zshrc"
# fi

alias pwdc="pwd | \pbcopy && echo 'Copied \"\$(pwd)\" to clipboard'"

alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'

alias c="clear"

alias wget="wget -c"

alias ps="ps aux | grep -v grep | grep -i -e VSZ -e"

alias sysinfo="lsb_release -a"

alias myip="curl ipinfo.io/json &> /dev/null | jq '.'"

alias hs="history"

alias timestamp="date +%s%N | cut -b1-13"

# function regex { gawk 'match($0,/'$1'/, ary) {print ary['${2:-'0'}']}'; }
