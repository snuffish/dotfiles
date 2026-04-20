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
    git commit -m "push" || echo "No changes to commit" && exit
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

alias process="sudo ps aux | grep $process_name"

alias header="curl -I -L"
alias portListener="sudo netstat -tolpn"

alias tsd="tsx watch"
