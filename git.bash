#!/bin/bash

# Add ssh-key
# if [[ $OS == "Mac" && $SHELL_ENV == "ZSH" && $USERNAME == "snuffish" ]]; then
#     eval && ssh-add "$HOME/.ssh/id_rsa"
# fi

alias g="git"

alias gst="g status"
alias gc="g commit --no-verify -m"
alias gd="g diff -w"
alias gds="g diff --stat"
alias gch="g checkout"
alias grh="g reset --hard && gclean"

alias gclean="g clean -fdx"
alias lg="lazygit"

function gdw() {
  SEARCH=$1
  if [[ ! $SEARCH ]]; then
    echo "Usage: gdw <string>"
    return
  fi

  gd *$SEARCH*
}

# Create and push a tag to Bitbcket
function gt() {
  g tag "$1" && g push origin "$1"
}

# Commit and push the changes
function gp() {
  if [ -n "$1" ]; then
    gc "$1"
  fi

  # Check if the current branch has an upstream branch
  CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
  if [ -z "$(git config branch.${CURRENT_BRANCH}.remote)" ]; then
    echo "No upstream branch set for ${CURRENT_BRANCH}. Setting it now..."
    git push --set-upstream origin "$CURRENT_BRANCH"
  else
    g push origin
  fi
}

alias gpa="git-pull-all"

alias {gcb,gb}="git branch --all | fzf --preview 'git show --color=always {-1}' --bind 'enter:become(git checkout {-1})' --height 50% --layout reverse"
