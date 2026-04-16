#!/bin/bash

typeset -A AG_DIRS
AG_DIRS=(
  Linux "$HOME/.config/Antigravity/User"
  Mac "$HOME/Library/Application Support/Antigravity/User"
)

ag() {
  nohup antigravity "$@" >/dev/null 2>&1 &
}

agp() {
  local dir="${AG_DIRS[$ENV_PROFILE]}"
  (
    cd "$dir" || exit
    git add .
    git commit -m "push" || echo "No changes to commit"
    git push
  )
}

agpull() {
  local dir="${AG_DIRS[$ENV_PROFILE]}"
  git -C "$dir" pull
}

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
