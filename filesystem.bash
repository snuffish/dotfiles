#!/bin/bash

# Set defaults if not set above
[[ $(aliasExists ".dl") -eq 0 ]] && alias .dl='cd "$HOME/Downloads"'
[[ $(aliasExists ".ssh") -eq 0 ]] && alias .ssh='cd "$HOME/.ssh"'
[[ $(aliasExists ".logs") -eq 0 ]] && alias .logs='cd "$HOME/.logs"'
[[ $(aliasExists ".terminal") -eq 0 ]] && alias .terminal='cd "$HOME/.terminal"'
[[ $(aliasExists ".t") -eq 0 ]] && alias .t='cd "$HOME/.terminal"'

[[ $(aliasExists "..") -eq 0 ]] && alias ..="cd .."

if [[ $ENV_PROFILE == "Linux" ]]; then
  alias .disken="cd /mnt/disken"
fi

alias rm="rm -rf"

alias -- -="cd -"

mkcd() {
  mkdir -p "$@" && cd "$_" || return
}

if command -v eza >/dev/null 2>&1; then
  alias ls="eza -laho --octal-permissions --icons=always --group-directories-first"
  alias l=ls
  alias lD="ls -D"
  alias ldot="ls -ld .*"
  alias lt="ls -T"
else
  alias ls="ls -la --color=auto"
  alias l=ls
fi

if command -v bat >/dev/null 2>&1; then
  alias cat="bat"
elif command -v batcat >/dev/null 2>&1; then
  alias cat="batcat"
fi

# ==============================================================================
# Interactive Fuzzy File Finder (find / ff)
# ==============================================================================
# - find                     -> fuzzy-find in current directory (.)
# - find ~                   -> fuzzy-find in home directory (~)
# - find <dir>               -> fuzzy-find in specified directory
# - find <query>             -> fuzzy-find in current directory pre-filtered
# - find <dir> <query>       -> fuzzy-find in <dir> pre-filtered
# - find . -name "*.txt"     -> passes through directly to GNU find
# - find ~<tab>              -> fuzzy-completes on Tab (handled by fzf completion)
find() {
  # If stdin is not a terminal (e.g. piped input), delegate directly to system find
  if [[ ! -t 0 ]]; then
    command find "$@"
    return $?
  fi

  # If any argument starts with '-', delegate directly to system find
  for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
      command find "$@"
      return $?
    fi
  done

  local search_dir="."
  local query=""

  if [[ $# -eq 0 ]]; then
    search_dir="."
  elif [[ $# -eq 1 ]]; then
    local target="${1/#\~/$HOME}"
    if [[ -d "$target" ]]; then
      search_dir="$target"
    elif [[ -f "$target" ]]; then
      echo "$target"
      return 0
    else
      query="$1"
      search_dir="."
    fi
  elif [[ $# -eq 2 ]]; then
    local target="${1/#\~/$HOME}"
    if [[ -d "$target" ]]; then
      search_dir="$target"
      query="$2"
    else
      command find "$@"
      return $?
    fi
  else
    command find "$@"
    return $?
  fi

  local preview_cmd='bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || cat {} 2>/dev/null'
  local fzf_opts=(
    --height=70%
    --layout=reverse
    --border
    --preview="$preview_cmd"
    --preview-window='right:50%:wrap'
    --header='[Enter] Print path | [Ctrl-E] Edit (nvim) | [Ctrl-O] Open | [Ctrl-Y] Copy path'
    --bind="ctrl-e:execute(${EDITOR:-nvim} {})+abort"
    --bind="ctrl-o:execute(xdg-open {} >/dev/null 2>&1 || open {} >/dev/null 2>&1 &)+abort"
    --bind="ctrl-y:execute-silent(echo -n {} | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null))+abort"
  )
  [[ -n "$query" ]] && fzf_opts+=(--query "$query")

  local selected
  if command -v fd >/dev/null 2>&1; then
    selected=$(fd --hidden --exclude .git . "$search_dir" 2>/dev/null | fzf "${fzf_opts[@]}")
  else
    selected=$(command find "$search_dir" -not -path '*/.*' 2>/dev/null | fzf "${fzf_opts[@]}")
  fi

  if [[ -n "$selected" ]]; then
    echo "$selected"
  fi
}

alias ff="find"

alias untar="tar -xvzf"

alias dirsize="du -hs"

alias .ghostty='cd "$HOME/Library/Application Support/com.mitchellh.ghostty"'

alias space="du -d1 -h 2>/dev/null | sort -h"

# diskspace (utils/diskspace.bash) only defines functions and removes the legacy alias
# itself, so it's safe to source on every load — re-sourcing picks up edits
[[ -f "$HOME/.terminal/utils/diskspace.bash" ]] && source "$HOME/.terminal/utils/diskspace.bash"
