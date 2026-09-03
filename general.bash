#!/bin/bash

if [[ "$SHELL" == "/bin/bash" ]]; then
  alias reload="source ~/.bashrc"
else
  alias reload="source ~/.zshrc"
fi

if [[ $ENV_PROFILE == "Linux" ]]; then
  alias pbcopy="wl-copy"
  alias pbpaste="wl-paste"
  function pbcopy() { wl-copy "$@"; }
  function pbpaste() { wl-paste "$@"; }
fi

unalias pwdc 2>/dev/null
function pwdc() {
  local target abs_path dir base abs_dir result=""
  local targets=()

  if [[ $# -eq 0 ]]; then
    targets=(".")
  elif [[ $# -gt 1 && -e "$*" ]]; then
    local all_exist=1
    local arg
    for arg in "$@"; do
      if [[ ! -e "$arg" && ! -d "$arg" ]]; then
        all_exist=0
        break
      fi
    done
    if [[ $all_exist -eq 1 ]]; then
      targets=("$@")
    else
      targets=("$*")
    fi
  else
    targets=("$@")
  fi

  for target in "${targets[@]}"; do
    if [[ "$target" == "~"* ]]; then
      target="${target/#\~/$HOME}"
    fi

    if [[ -d "$target" ]]; then
      abs_path="$(cd -- "$target" >/dev/null 2>&1 && pwd)"
    else
      dir="$(dirname -- "$target")"
      base="$(basename -- "$target")"
      abs_dir="$(cd -- "$dir" >/dev/null 2>&1 && pwd)"
      if [[ -n "$abs_dir" ]]; then
        if [[ "$abs_dir" == "/" ]]; then
          abs_path="/$base"
        else
          abs_path="$abs_dir/$base"
        fi
      elif [[ "$target" == /* ]]; then
        abs_path="$target"
      else
        abs_path="$PWD/$target"
      fi
    fi

    if [[ -n "$result" ]]; then
      result="$result
$abs_path"
    else
      result="$abs_path"
    fi
  done

  printf "%s\n" "$result" | pbcopy
}

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
