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

# catc <file>... -> copy the raw file contents to the clipboard
unalias catc 2>/dev/null
function catc() {
  command cat "$@" | pbcopy
}

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
# - ff [<dir>] [<pattern>]   -> same picker in pattern mode: regex (^fi.*sh$) or glob (*.py)
# - Ctrl-R in the picker     -> toggles fuzzy / pattern mode
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
    --bind="ctrl-e:execute(${EDITOR:-nvim} {})+abort"
    --bind="ctrl-o:execute(xdg-open {} >/dev/null 2>&1 || open {} >/dev/null 2>&1 &)+abort"
    --bind="ctrl-y:execute-silent(echo -n {} | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null))+abort"
  )
  [[ -n "$query" ]] && fzf_opts+=(--query "$query")

  # Two modes, toggled with Ctrl-R; the list command reads the mode from $FZF_PROMPT.
  # - fuzzy: list every file once, fzf filters it
  # - pattern: fzf only displays, each keystroke re-runs the query through fd as a regex,
  #   or as a glob (*.py) when it isn't a valid regex
  local dir_q list_cmd
  dir_q=$(printf '%q' "$search_dir")
  if command -v fd >/dev/null 2>&1; then
    local fd_cmd="fd --hidden --exclude .git"
    list_cmd="if [[ \$FZF_PROMPT == pattern* ]]; then $fd_cmd -- {q} $dir_q 2>/dev/null || $fd_cmd --glob -- {q} $dir_q 2>/dev/null; else $fd_cmd . $dir_q 2>/dev/null; fi; true"
  else
    list_cmd="if [[ \$FZF_PROMPT == pattern* ]]; then command find $dir_q -not -path '*/.*' 2>/dev/null | grep -E -- {q}; else command find $dir_q -not -path '*/.*' 2>/dev/null; fi; true"
  fi
  local to_pattern="change-prompt(pattern> )+disable-search+rebind(change)+reload:$list_cmd"
  local to_fuzzy="change-prompt(fuzzy> )+enable-search+unbind(change)+reload:$list_cmd"
  local toggle="[[ \$FZF_PROMPT == pattern* ]] && echo $(printf '%q' "$to_fuzzy") || echo $(printf '%q' "$to_pattern")"

  fzf_opts+=(
    --header='[Enter] Print path | [Ctrl-E] Edit (nvim) | [Ctrl-O] Open | [Ctrl-Y] Copy path | [Ctrl-R] Fuzzy/pattern'
    --bind="change:reload:$list_cmd"
    --bind="ctrl-r:transform:$toggle"
  )
  if [[ -n "$__FIND_PATTERN" ]]; then
    fzf_opts+=(--prompt='pattern> ' --disabled --bind="start:reload:$list_cmd")
  else
    fzf_opts+=(--prompt='fuzzy> ' --bind="start:unbind(change)+reload:$list_cmd")
  fi

  local selected
  selected=$(: | fzf "${fzf_opts[@]}")

  if [[ -n "$selected" ]]; then
    echo "$selected"
  fi
}

# Same picker as find, but starts in pattern mode: regex or glob on file names (Ctrl-R toggles)
unalias ff 2>/dev/null
ff() {
  __FIND_PATTERN=1 find "$@"
}

alias untar="tar -xvzf"

alias dirsize="du -hs"

alias .ghostty='cd "$HOME/Library/Application Support/com.mitchellh.ghostty"'

alias space="du -d1 -h 2>/dev/null | sort -h"

# diskspace (utils/diskspace.bash) only defines functions and removes the legacy alias
# itself, so it's safe to source on every load — re-sourcing picks up edits
[[ -f "$HOME/.terminal/utils/diskspace.bash" ]] && source "$HOME/.terminal/utils/diskspace.bash"
