#!/bin/bash

if [[ ! "$ENV_PROFILE" ]]; then
  echo 'Missing Environment variable $ENV_PROFILE in your ~\.zshrc | ~\.bashrc | ~\.bash_profile | ...'
  exit 1
fi

echo "[ENV_PROFILE: $ENV_PROFILE]"

SCRIPT_DIR="$HOME/.terminal"

function header() {
  printf "\n### %s ###\n" "$1"
}

# Unlock the ssh-keychain for no password-promts on new sessions
eval "keychain --eval ssh ~./ssh/id_ed25519"
eval "keychain --eval ssh ~./ssh/id_rsa"

# Load all utils
header "Utils"
for util in "$SCRIPT_DIR"/utils/*.bash; do
  # shellcheck source=/dev/null
  source "$util"
  printf "Loaded => %s\n" "$util"
done

# Load all resources
header "Environment"
for resource in "$SCRIPT_DIR"/*.bash; do
  if grep -v --silent --quiet "__init__" <<<"$resource"; then
    loadSource "$resource"
  fi
done

# Other system sourcing
autoload -U +X bashcompinit && bashcompinit

source "$SCRIPT_DIR/az.completion"
source "$SCRIPT_DIR/tmux/init.bash"

# xmodmap
# xmodmap -e "keysym Meta_L = ISO_Level3_Shift"
# xmodmap "$SCRIPT_DIR/.Xmodmap"

# Set nvim as the default viewer for Manpages
export MANPAGER='nvim +Man!'

# Set up fzf key bindings and fuzzy completion
# shellcheck source=/dev/null
source <(fzf --zsh)
