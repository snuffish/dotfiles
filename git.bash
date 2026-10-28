#!/bin/bash

# Add ssh-key (interactive shells only)
[[ $- == *i* ]] && ssh-add -q "$HOME/.ssh/id_rsa" 2>/dev/null

# LazyGit
alias lg="lazygit"
alias gs="lg status"
alias lgl="lg log"
alias lgb="lg branch"
alias lgst="lg stash"

# Git
alias g="git"

alias gg="run_fzf_json gg --title 'Git'"

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

# Data & key-binding helper for gb:
#   _gb_list list local|all [current_root]  -> TSV rows: "<age>\t<branch>\t<meta+subject>\t<checkout_branch>\t<ref>\t<wt_dir>\t<lock>"
#   _gb_list key                            -> fzf transform action for ctrl-t (toggles Local> / All> prompt + reloads list)
function _gb_list() {
  if [[ "$1" == key ]]; then
    local self="$HOME/.terminal/git.bash"
    if [[ "$FZF_PROMPT" == All* ]]; then
      echo "change-prompt(Local> )+reload(bash -c 'source \"$self\" && _gb_list list local')"
    else
      echo "change-prompt(All> )+reload(bash -c 'source \"$self\" && _gb_list list all')"
    fi
    return 0
  fi

  local scope="${2:-local}"
  local current_root="${3:-$(git rev-parse --show-toplevel 2>/dev/null)}"
  local now_ts
  now_ts=$(date +%s)

  local -a ref_patterns=(refs/heads)
  [[ "$scope" == all ]] && ref_patterns+=(refs/remotes/origin)

  {
    # 1. Worktrees: W \t <branch> \t <dir> \t <wt_name> \t <is_cur> \t <lock>
    git worktree list --porcelain 2>/dev/null | awk -v cur="$current_root" '
      function flush() {
        if (dir != "" && !prunable && branch != "") {
          n = split(dir, parts, "/")
          wname = parts[n]
          is_cur = (dir == cur ? 1 : 0)
          printf "W\t%s\t%s\t%s\t%d\t%s\n", branch, dir, wname, is_cur, lock
        }
        dir = ""; branch = ""; lock = ""; prunable = 0
      }
      /^worktree / { flush(); dir = substr($0, 10); next }
      /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch); next }
      /^locked/    { lock = substr($0, 8); if (lock == "") lock = "locked"; next }
      /^prunable/  { prunable = 1; next }
      END          { flush() }
    '

    # 2. Recent checkouts from reflog: R \t <branch>
    git reflog --format='%gs' 2>/dev/null \
      | awk '/^checkout: moving from / { print $NF; print $4 }' \
      | sed 's|^origin/||' \
      | awk '!seen[$0]++ { printf "R\t%s\n", $0 }'

    # 3. Branches: B \t <full_ref> \t <short_ref> \t <symref> \t <unix_ts> \t <short_date> \t <track> \t <subject>
    git for-each-ref --sort=refname \
      --format=$'B\t%(refname)\t%(refname:short)\t%(symref)\t%(committerdate:unix)\t%(committerdate:short)\t%(upstream:track,nobracket)\t%(contents:subject)' \
      "${ref_patterns[@]}" 2>/dev/null
  } | awk -F '\t' -v now="$now_ts" '
    function pad(s, len,    l) {
      l = length(s)
      return (l >= len) ? s : s sprintf("%*s", len - l, "")
    }
    function rel_age(ts, sdate,    d) {
      if (ts <= 0) return ""
      d = now - ts
      if (d < 60) return "now"
      if (d < 3600) return int(d / 60) "m ago"
      if (d < 86400) return int(d / 3600) "h ago"
      if (d < 604800) return int(d / 86400) "d ago"
      return sdate
    }
    function fmt_track(t,    out) {
      if (t == "") return ""
      out = t
      gsub(/ahead /, "↑", out)
      gsub(/behind /, "↓", out)
      gsub(/, /, " ", out)
      return out
    }
    $1 == "W" {
      b = $2; wt_dir[b] = $3; wt_name[b] = $4; wt_cur[b] = ($5 == 1); wt_lock[b] = $6
      next
    }
    $1 == "R" {
      if (!($2 in rank)) rank[$2] = ++rcount
      next
    }
    $1 == "B" {
      full = $2; short = $3; sym = $4; ts = $5 + 0; sdate = $6; trk = $7; subj = $8
      if (sym != "") next
      is_remote = (full ~ /^refs\/remotes\//)
      bname = short
      if (is_remote) sub(/^origin\//, "", bname)

      # Local branch always shadows its remote counterpart
      if (bname in seen_branch) next
      seen_branch[bname] = 1

      order[++bcount] = bname
      b_ref[bname] = short
      b_remote[bname] = is_remote
      b_ts[bname] = ts
      b_sdate[bname] = sdate
      b_trk[bname] = fmt_track(trk)
      b_subj[bname] = subj
    }
    END {
      # Emit reflog-visited branches first (in reflog order), then remaining branches alphabetically
      out_n = 0
      for (i = 1; i <= bcount; i++) {
        b = order[i]
        if (b in rank) {
          r = rank[b]
          if (r < 1 || r > 100000) r = 100000
          by_rank[r] = b
          if (r > max_r) max_r = r
        }
      }
      for (r = 1; r <= max_r; r++) {
        if (r in by_rank) final[++out_n] = by_rank[r]
      }
      for (i = 1; i <= bcount; i++) {
        b = order[i]
        if (!(b in rank)) final[++out_n] = b
      }

      # Size the branch column to the longest name rather than truncating: fzf matches the displayed text
      b_width = 0
      for (i = 1; i <= out_n; i++) if (length(final[i]) > b_width) b_width = length(final[i])

      for (i = 1; i <= out_n; i++) {
        b = final[i]
        marker = (wt_cur[b] ? "\033[32m●\033[0m " : (wt_dir[b] != "" ? "\033[31m◆\033[0m " : "  "))
        age_str = marker "\033[90m" pad(rel_age(b_ts[b], b_sdate[b]), 10) "\033[0m"

        b_col = (b_remote[b] ? "\033[36m" : "\033[35m") pad(b, b_width) "\033[0m"

        meta = ""
        if (b_remote[b]) meta = "\033[90morigin\033[0m"
        else if (b_trk[b] != "") meta = "\033[33m" b_trk[b] "\033[0m"
        if (wt_dir[b] != "" && !wt_cur[b]) {
          wt_badge = "\033[31mwt:" wt_name[b] "\033[0m"
          meta = (meta != "" ? meta "  " wt_badge : wt_badge)
        }
        if (wt_lock[b] != "") {
          lock_badge = "🔒 " wt_lock[b]
          meta = (meta != "" ? meta "  " lock_badge : lock_badge)
        }

        subj = b_subj[b]
        line_body = (meta != "" ? meta "  " subj : subj)

        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", age_str, b_col, line_body, b, b_ref[b], wt_dir[b], wt_lock[b]
      }
    }
  '
}

# Checkout a branch (or switch to its worktree if already checked out), most recently visited first (from the reflog), then the rest alphabetically
unalias gb 2>/dev/null
function gb() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "gb: not inside a git repository" >&2
    return 1
  fi

  local current_root
  current_root=$(git rev-parse --show-toplevel) || return $?
  local current_branch
  current_branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)

  local scope=local prompt='Local> '
  local rows
  rows=$(_gb_list list "$scope" "$current_root")
  if [[ -z "$rows" ]] || { [[ -n "$*" ]] && ! grep -qiF "$1" <<< "$rows"; }; then
    scope=all
    prompt='All> '
    rows=$(_gb_list list "$scope" "$current_root")
  fi
  [[ -n "$rows" ]] || return 0

  # Pre-select the current branch row when no initial query is given
  local -a pos_bind=()
  if [[ -z "$*" && -n "$current_branch" ]]; then
    local cur_pos
    cur_pos=$(printf '%s\n' "$rows" | awk -F '\t' -v cur="$current_branch" '$4 == cur { print NR; exit }')
    [[ -n "$cur_pos" ]] && pos_bind=(--bind "load:pos($cur_pos)")
  fi

  local self="$HOME/.terminal/git.bash"
  local preview_log='git show --stat --color=always {5} 2>/dev/null; echo; git log --oneline --graph --color=always -n 20 {5} 2>/dev/null'
  local preview_diff='if git diff --quiet HEAD...{5} 2>/dev/null; then echo "No diff against HEAD"; else git diff --color=always HEAD...{5} 2>/dev/null; fi'

  local pick
  pick=$(printf '%s\n' "$rows" | fzf --ansi \
    --header 'enter checkout/switch · ctrl-t local / all · ctrl-d diff · ctrl-s log · ctrl-y copy' \
    --border rounded --border-label ' Checkout branch ' --preview-border rounded \
    --color 'border:8,label:6:bold,preview-border:8,preview-label:6:bold,header:8:italic,info:8,separator:8,scrollbar:8' \
    --color 'prompt:6:bold,pointer:5,marker:5,hl:3:bold,hl+:3:bold,fg+:-1:bold,query:-1:bold' \
    --prompt "$prompt" --delimiter='\t' --with-nth=1,2,3 --nth=2,3 --tabstop=1 --tiebreak=index \
    --query "$*" --select-1 --exit-0 "${pos_bind[@]}" \
    --bind='focus:transform-preview-label:printf " %s " {4}' \
    --bind="ctrl-t:transform:bash -c 'source \"$self\" && _gb_list key'" \
    --bind="ctrl-d:change-preview:$preview_diff" \
    --bind="ctrl-s:change-preview:$preview_log" \
    --bind="ctrl-y:execute-silent(printf %s {4} | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null))+abort" \
    --preview="$preview_log" \
    --preview-window 'right,55%,wrap' --height 60% --layout reverse) || return 0
  [[ -n "$pick" ]] || return 0

  local target_branch target_wt target_lock
  target_branch=$(printf '%s\n' "$pick" | cut -f4)
  target_wt=$(printf '%s\n' "$pick" | cut -f6)
  target_lock=$(printf '%s\n' "$pick" | cut -f7)

  if [[ -n "$target_wt" && "$target_wt" != "$current_root" ]]; then
    echo "gb: '$target_branch' is checked out in worktree $target_wt — switching there" >&2
    cd -- "$target_wt" || return $?
    if [[ "$target_lock" == *"claude-skill:"* ]]; then
      echo "gb: warning — an agent is working in this worktree; avoid checkout/stash/edits here" >&2
    fi
    return 0
  fi

  git checkout "$target_branch"
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
  wt_line=$(printf '%s\n' "$rows" | fzf --border --border-label ' Switch worktree ' \
    --header '[Enter] Switch | [Ctrl-D] Diff | [Ctrl-S] Status | [Shift-↑/↓] Scroll preview' \
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


