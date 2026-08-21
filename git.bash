#!/bin/bash

# Add ssh-key
eval && ssh-add "$HOME/.ssh/id_rsa"

# LazyGit
alias lg="lazygit"
alias gs="lg status"
alias lgl="lg log"
alias lgb="lg branch"
alias lgst="lg stash"

# Git
alias g="git"

alias gP="g pull"
alias gc="g commit --no-verify -m"
alias gd="g diff -w"
alias gds="g diff --stat"
alias gch="g checkout"
alias grh="g reset --hard && gclean"

alias gpa="git-pull-all"
alias gb="git branch --all --format='%(refname:short)' | sed -e 's|^origin/||' -e 's|^remotes/origin/||' | grep -Ev '^(HEAD|\(HEAD|origin/HEAD)' | sort -u | fzf --header 'Select branch to checkout:' --preview 'git show --color=always {-1}' --bind 'enter:become(git checkout {-1})' --height 50% --layout reverse"

alias gclean="g clean -f"

alias gst="g status"
alias gcwip="g add . && g status && gc wip && gp"

alias meligo="run_fzf_json meligo --title 'Meligo Azure Logs'"

function gdw() {
  SEARCH=$1
  if [[ ! $SEARCH ]]; then
    echo "Usage: gdw <string>"
    return
  fi

  gd "*$SEARCH*"
}

# Create and push a tag to Bitbcket
function gt() {
  g tag "$1" && g push origin "$1"
}

# Commit and push the changes
function gP() {
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

# Push a specific local branch without switching to it
function gpb() {
  local branch="$1"
  if [ -z "$branch" ]; then
    if command -v fzf >/dev/null 2>&1; then
      branch=$(git branch --format='%(refname:short)' | fzf --header 'Select branch to push:' --preview 'git show --color=always {-1}' --height 50% --layout reverse)
    fi
  else
    shift
  fi

  if [ -z "$branch" ]; then
    echo "Usage: gpb <branch-name> [git push options...]"
    return 1
  fi

  git push origin "$branch:$branch" "$@"
}


