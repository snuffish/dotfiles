#!/bin/bash

ag() {
  nohup antigravity "$@" >/dev/null 2>&1 &
}

agy() {
  # If running non-interactively, pass through directly
  if [[ ! -t 0 ]]; then
    command agy "$@"
    return $?
  fi

  # Pass through common subcommands and help flags without prompting
  case "$1" in
    agent|agents|changelog|help|install|mcp|mic-serve|models|plugin|plugins|update|--help|-h|--version|-v)
      command agy "$@"
      return $?
      ;;
  esac

  # If user already passed permission or mode flags, pass through directly
  for arg in "$@"; do
    if [[ "$arg" == "--dangerously-skip-permissions" || "$arg" == "--mode" ]]; then
      command agy "$@"
      return $?
    fi
  done

  local response
  printf "Auto-approve all actions for this session? [y/N]: "
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    command agy --mode accept-edits --dangerously-skip-permissions "$@"
  else
    command agy "$@"
  fi
}

agyy() {
  echo "⚡ Launching in auto-approval mode..."
  command agy --mode accept-edits --dangerously-skip-permissions "$@"
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
