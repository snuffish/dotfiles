#!/bin/bash

ag() {
  nohup antigravity "$@" >/dev/null 2>&1 &
}

agp() {
  (
    cd "$HOME/.gemini/antigravity" || exit
    g add .
    gc "push" || echo "No changes to commit"
    gp
  )
}

alias agpull='git -C "$HOME/.gemini/antigravity" pull'

alias tf="tail -f"
findPort() {
  lsof -i :$1
}
#alias port="findPort"

alias killPort="npx kill-port"

alias process="sudo ps aux | grep $process_name"

alias header="curl -I -L"
alias portListener="sudo netstat -tolpn"

alias tsd="tsx watch"
