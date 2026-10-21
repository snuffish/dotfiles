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

alias g="run_fzf_json gg --title 'Git'"

alias gP="g pull"
alias gc="g commit --no-verify -m"
unalias gd 2>/dev/null
function gd() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff -w "$@"
    return $?
  fi

  local has_cached=0
  for arg in "$@"; do
    if [[ "$arg" == "--cached" || "$arg" == "--staged" ]]; then
      has_cached=1
      break
    fi
  done

  if [[ $has_cached -eq 1 ]]; then
    git diff -w "$@"
    return $?
  fi

  local tmp_untracked
  tmp_untracked=$(mktemp) || {
    git diff -w "$@"
    return $?
  }

  git ls-files -z --others --exclude-standard -- ":/" > "$tmp_untracked" 2>/dev/null

  if [[ ! -s "$tmp_untracked" ]]; then
    rm -f "$tmp_untracked"
    git diff -w "$@"
    return $?
  fi

  local cleaned=0
  cleanup() {
    if [[ $cleaned -eq 0 ]]; then
      cleaned=1
      if [[ -f "$tmp_untracked" ]]; then
        git reset -q --pathspec-from-file="$tmp_untracked" --pathspec-file-nul 2>/dev/null || true
        rm -f "$tmp_untracked"
      fi
    fi
  }

  trap cleanup INT TERM EXIT

  git add -N --pathspec-from-file="$tmp_untracked" --pathspec-file-nul 2>/dev/null || true

  git diff -w "$@"
  local ret=$?

  cleanup
  trap - INT TERM EXIT

  return $ret
}
alias gds="gd --stat"
alias gch="g checkout"
alias grh="g reset --hard && gclean"

alias gpa="git-pull-all"

# Checkout a branch, most recently visited first (from the reflog), then the rest alphabetically
unalias gb 2>/dev/null
function gb() {
  local branches
  branches=$(git branch --all --format='%(refname:short)' | sed -e 's|^origin/||' -e 's|^remotes/origin/||' | grep -Ev '^(HEAD|\(HEAD|origin/HEAD)' | sort -u) || return $?

  local recent
  recent=$(git reflog --format='%gs' 2>/dev/null | awk '/^checkout: moving from / { print $NF; print $4 }' | sed 's|^origin/||')

  # Keep only existing branches (drops detached SHAs), first occurrence wins
  printf '%s\n%s\n' "$recent" "$branches" \
    | awk 'FNR == NR { ok[$0] = 1; next } ok[$0] && !seen[$0]++' <(printf '%s\n' "$branches") - \
    | fzf --header 'Select branch to checkout:' --tiebreak=index --preview 'git show --color=always {-1}' --bind 'enter:become(git checkout {-1})' --height 50% --layout reverse
}

# Switch to another worktree of the current repo (agent-locked ones are flagged)
unalias gw 2>/dev/null
function gw() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "gw: not inside a git repository" >&2
    return 1
  fi

  local current_root
  current_root=$(git rev-parse --show-toplevel) || return $?

  # One row per live worktree: "<label>\t<dir>". Prunable (deleted) worktrees are skipped
  local rows
  rows=$(git worktree list --porcelain | awk -v cur="$current_root" '
    function flush() {
      if (dir != "" && !prunable) {
        label = (branch != "" ? branch : "(detached " substr(head, 1, 7) ")")
        if (dir == cur) label = "● " label
        if (lock != "") label = label "  🔒 " lock
        printf "%s\t%s\n", label, dir
      }
      dir = ""; head = ""; branch = ""; lock = ""; prunable = 0
    }
    /^worktree / { flush(); dir = substr($0, 10); next }
    /^HEAD /     { head = substr($0, 6); next }
    /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch); next }
    /^locked/    { lock = substr($0, 8); if (lock == "") lock = "locked"; next }
    /^prunable/  { prunable = 1; next }
    END          { flush() }
  ') || return $?

  if [[ $(printf '%s\n' "$rows" | grep -c .) -le 1 ]]; then
    echo "gw: no other worktrees in $current_root"
    return 0
  fi

  # Pre-select the current worktree's row; skipped with a query, where positions refer to the filtered list
  local -a pos_bind
  local cur_pos
  cur_pos=$(printf '%s\n' "$rows" | awk -F '\t' -v cur="$current_root" '$2 == cur { print NR; exit }')
  [[ -z "$*" && -n "$cur_pos" ]] && pos_bind=(--bind "load:pos($cur_pos)")

  # Two preview modes: status + per-file change stat + log, or the full diff (untracked files included)
  local preview_status='git -C {2} -c color.status=always status -sb; echo;'
  preview_status+=' git -C {2} diff HEAD --quiet 2>/dev/null || { git -C {2} diff HEAD --stat --color=always; echo; };'
  preview_status+=' git -C {2} log --oneline --color=always -n 20'
  local preview_diff='cd {2} || exit;'
  preview_diff+=' if git diff HEAD --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard)" ]; then echo "No changes"; exit; fi;'
  preview_diff+=' git diff HEAD --color=always;'
  preview_diff+=' git ls-files -z --others --exclude-standard | xargs -0 -n1 git diff --no-index --color=always -- /dev/null 2>/dev/null; true'

  # Match the query against the label only; the shared parent path would fuzzy-match everything
  local wt_line
  wt_line=$(printf '%s\n' "$rows" | fzf --header 'Select worktree to switch to:  (ctrl-d: diff · ctrl-s: status · shift-↑/↓: scroll)' \
    --delimiter '\t' --nth 1 --tiebreak=index \
    --query "$*" --select-1 --exit-0 "${pos_bind[@]}" \
    --preview "$preview_status" --preview-label ' status ' \
    --bind "ctrl-d:change-preview-label( diff )+change-preview:$preview_diff" \
    --bind "ctrl-s:change-preview-label( status )+change-preview:$preview_status" \
    --height 50% --layout reverse)
  [[ -n "$wt_line" ]] || return 0

  local wt_dir
  wt_dir=$(printf '%s\n' "$wt_line" | cut -f2)
  cd -- "$wt_dir" || return $?

  if [[ "$wt_line" == *"🔒 claude-skill:"* ]]; then
    echo "gw: warning — an agent is working in this worktree; avoid checkout/stash/edits here" >&2
  fi
}

alias gclean="g clean -f"

alias gst="g status"
alias gcwip="g add . && g status && gc wip && gp"

function gcw() {
  git add . || return $?
  git status || return $?

  if git diff --cached --quiet; then
    echo "Nothing to commit, working tree clean."
    return 0
  fi

  local msg="$*"
  if [ -z "$msg" ]; then
    printf "\nEnter commit message: "
    read -r msg
  fi

  if [[ -z "${msg// }" ]]; then
    echo "Commit message cannot be empty. Aborted."
    return 1
  fi

  git commit --no-verify -m "$msg" || return $?

  local current_branch
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  if [ -n "$current_branch" ] && [ -z "$(git config branch.${current_branch}.remote)" ]; then
    echo "No upstream branch set for ${current_branch}. Setting it now..."
    git push --set-upstream origin "$current_branch"
  else
    git push
  fi
}

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


