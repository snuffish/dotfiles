#!/bin/bash

if [[ ! "$ENV_PROFILE" ]]; then
  echo 'Missing Environment variable $ENV_PROFILE in your ~/.zshrc | ~/.bashrc | ~/.bash_profile | ...'
  return 1 2>/dev/null || exit 1
fi

echo "[ENV_PROFILE: $ENV_PROFILE]"

SCRIPT_DIR="$HOME/.terminal"

function header() {
  printf "\n### %s ###\n" "$1"
}

# Unlock the ssh-keychain for no password-prompts on new sessions
if command -v keychain >/dev/null 2>&1; then
  eval "keychain --eval ssh ~/.ssh/id_ed25519" 2>/dev/null || true
  eval "keychain --eval ssh ~/.ssh/id_rsa" 2>/dev/null || true
fi

alias sudo="sudo "

# Load all utils
header "Utils"
for util in "$SCRIPT_DIR"/utils/*.bash; do
  if [[ -f "$util" ]]; then
    source "$util"
    printf "Loaded => %s\n" "$util"
  fi
done

header "Environment variables"
for env_file in "$SCRIPT_DIR"/.env*; do
  if [[ -f "$env_file" ]]; then
    loadSource "$env_file"
  fi
done

# Load all resources
header "Environment"
for resource in "$SCRIPT_DIR"/*.bash; do
  if [[ "$resource" != *"__init__"* && -f "$resource" ]]; then
    loadSource "$resource"
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
  elif [[ -n "$BASH_VERSION" ]]; then
    source <(fzf --bash 2>/dev/null || true)
  fi
fi
