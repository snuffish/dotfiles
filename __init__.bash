#!/bin/bash

if [[ ! "$ENV_PROFILE" ]]; then
  echo 'Missing Environment variable $ENV_PROFILE in your ~/.zshrc | ~/.bashrc | ~/.bash_profile | ...'
  return 1 2>/dev/null || exit 1
fi

SCRIPT_DIR="$HOME/.terminal"

# Sets init_clock_ms to epoch milliseconds, or empty on shells without EPOCHREALTIME (bash < 5)
function _initClock() {
  local now=$EPOCHREALTIME frac
  if [[ -z "$now" ]]; then
    init_clock_ms=""
    return
  fi
  # bash uses the locale's decimal separator
  frac=${now#*[.,]}000
  init_clock_ms=${now%[.,]*}${frac:0:3}
}

if [[ -n "$ZSH_VERSION" ]]; then
  zmodload zsh/datetime 2>/dev/null
fi
_initClock
init_start_ms=$init_clock_ms

# Unlock the ssh-keychain for no password-prompts on new sessions
if command -v keychain >/dev/null 2>&1; then
  eval "keychain --eval ssh ~/.ssh/id_ed25519" 2>/dev/null || true
  eval "keychain --eval ssh ~/.ssh/id_rsa" 2>/dev/null || true
fi

alias sudo="sudo "

# Args: (label, names...) — prints "  label  n  a · b · c" wrapped to the terminal width
function _initPrintGroup() {
  local label=$1
  shift

  local width=${COLUMNS:-0}
  if ((width <= 0)); then
    width=$(tput cols 2>/dev/null || echo 80)
  fi

  local indent=12 col=12 first=1 name
  printf "  \e[2m%-5s\e[0m%3d  " "$label" "$#"
  for name in "$@"; do
    if ((first)); then
      first=0
    elif ((col + 3 + ${#name} > width)); then
      printf "\n%*s" "$indent" ""
      col=$indent
    else
      printf "\e[2m · \e[0m"
      col=$((col + 3))
    fi
    printf "%s" "$name"
    col=$((col + ${#name}))
  done
  printf "\n"
}

init_utils=()
init_envs=()
init_modules=()
init_failed=0

# Load all utils
for util in "$SCRIPT_DIR"/utils/*.bash; do
  if [[ -f "$util" ]]; then
    source "$util"
    util=${util##*/}
    init_utils+=("${util%.bash}")
  fi
done

for env_file in "$SCRIPT_DIR"/.env*; do
  if [[ -f "$env_file" ]]; then
    if loadSource "$env_file"; then
      init_envs+=("${env_file##*/}")
    else
      init_failed=1
    fi
  fi
done

# Load all resources
# Every *.bash below is sourced into zsh too: never use zsh special names (path, status, cdpath, fpath, argv) as variables
for resource in "$SCRIPT_DIR"/*.bash; do
  if [[ "$resource" != *"__init__"* && -f "$resource" ]]; then
    if loadSource "$resource"; then
      resource=${resource##*/}
      init_modules+=("${resource%.bash}")
    else
      init_failed=1
    fi
  fi
done

# Other system sourcing
if [[ -n "$ZSH_VERSION" ]]; then
  autoload -U +X bashcompinit && bashcompinit
fi

if [[ -f "$SCRIPT_DIR/az.completion" ]]; then
  source "$SCRIPT_DIR/az.completion"
fi

if [[ -f "$SCRIPT_DIR/tmux/init.bash" ]]; then
  source "$SCRIPT_DIR/tmux/init.bash"
fi

# Set nvim as the default viewer for Manpages
export MANPAGER='nvim +Man!'

# Set up fzf key bindings and fuzzy completion
if command -v fzf >/dev/null 2>&1; then
  if [[ -n "$ZSH_VERSION" ]]; then
    source <(fzf --zsh)
    if declare -f _fzf_setup_completion_widget >/dev/null; then
      _fzf_setup_completion_widget
    fi
  elif [[ -n "$BASH_VERSION" ]]; then
    source <(fzf --bash 2>/dev/null || true)
    if declare -f _fzf_setup_completion_bash >/dev/null; then
      _fzf_setup_completion_bash
    fi
  fi
fi

# Startup summary: counts per group and the time this file took
init_count=$((${#init_utils[@]} + ${#init_envs[@]} + ${#init_modules[@]}))
init_took=""
_initClock
if [[ -n "$init_start_ms" && -n "$init_clock_ms" ]]; then
  init_took=" \e[2min\e[0m $((init_clock_ms - init_start_ms))ms"
fi

if ((init_failed)); then
  printf "\e[31m✗\e[0m"
else
  printf "\e[32m✓\e[0m"
fi
printf " \e[1m%s\e[0m \e[2m·\e[0m %d loaded${init_took}\n" "$ENV_PROFILE" "$init_count"
_initPrintGroup "utils" "${init_utils[@]}"
_initPrintGroup "env" "${init_envs[@]}"
_initPrintGroup "mods" "${init_modules[@]}"
printf "\n"

unset init_utils init_envs init_modules init_failed init_count init_took init_start_ms init_clock_ms
unset -f _initPrintGroup _initClock
