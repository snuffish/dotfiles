#!/bin/bash

# Add ssh-key
# if [[ $OS == "Mac" && $SHELL_ENV == "ZSH" && $USERNAME == "snuffish" ]]; then
#     eval && ssh-add "$HOME/.ssh/id_rsa"
# fi

alias g="git"

alias gst="g status"
alias gc="g commit --no-verify -m"
alias gd="g diff -w"
alias gch="g checkout"

alias gclean="g clean -fdx"
alias gl="lazygit"

# Create and push a tag to Bitbcket
function gt() {
  g tag "$1" && g push origin "$1"
}

# Commit and push the changes
function gp() {
  if [ -n "$1" ]; then
    gc "$1"
  fi
  g push origin
}

# Pull/fetch everything
function gpa() {
  git branch -r | grep -v '\->' | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" | while read remote; do git branch --track "${remote#origin/}" "$remote"; done
}

alias {gcb,gb}="git branch | fzf --preview 'git show --color=always {-1}' --bind 'enter:become(git checkout {-1})' --height 50% --layout reverse"
