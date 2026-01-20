#!/bin/bash

alias code="antigravity"

alias tf="tail -f"
findPort() {
  lsof -i :$1
}
#alias port="findPort"

alias killPort="npx kill-port"

alias process="sudo ps aux | grep $process_name"

alias header="curl -I -L"
alias portListener="sudo netstat -tolpn"

alias tsd="ts-node-dev --respawn"
