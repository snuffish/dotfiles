#!/bin/bash

if [[ ! "$ENV_PROFILE" ]]; then
  echo "Missing Environment variable \$ENV_PROFILE in your ~\.zshrc | ~\.bashrc | ~\.bash_profile | ..."
  exit 1
fi

echo "[ENV_PROFILE: $ENV_PROFILE]"

SCRIPT_DIR="$HOME/.terminal"

# Unlock the ssh-keychain for no password-promts on new sessions
eval `keychain --eval --agents ssh id_ed25519`

# Load all utils
echo "\n### Utils ###"
for util in "$SCRIPT_DIR"/utils/*.bash; do
  source "$util"
  echo "Loaded => $util"
done

# Load all resources
echo "\n### Environment ###"
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
source <(fzf --zsh)
