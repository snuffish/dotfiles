#!/bin/bash

ag() {
  nohup antigravity "$@" >/dev/null 2>&1 &
}

agp() {
  echo "[AG_USER_DIR] $AG_USER_DIR"
  (
    cd "$AG_USER_DIR" || exit
    git add . && echo "[*] Adding files"
    echo "[*] Commiting files"
    git commit -m "push" || echo "No changes to commit"
    echo "[*] Pushing files"
    git push
  )
}

agpull() {
  echo "[AG_USER_DIR] $AG_USER_DIR"
  echo "[*] Pulling"
  git -C "$AG_USER_DIR" pull
}

alias tf="tail -f"
findPort() {
  lsof -i :$1
}
#alias port="findPort"

alias killPort="npx kill-port"

process() {
  if [[ -z "$1" ]]; then
    echo "Usage: process <process_name>"
    return 1
  fi
  sudo ps aux | grep -i "$1"
}

alias header="curl -I -L"
alias portListener="sudo netstat -tolpn"

alias tsd="tsx watch"
