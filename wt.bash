#!/bin/bash

# Worktree verbs shared by cw, claude-p, gw and the WorktreeCreate/WorktreeRemove hooks; menus and hooks only call these.
# Trees live in <main checkout>/.claude/worktrees/<name>, locked "claude-skill:cw … session:<id> base:<sha> made:1".
# A tree is safe to remove when it is clean, has no commit missing from every other branch and remote, no running
# Claude session has its cwd inside it or owns its lock (~/.claude/sessions/<pid>.json, pid alive and procStart matching), and its
# .worktreeinclude copies equal the main checkout's. Unreadable session registry → unknown → keep.
# Sourced into zsh too: no zsh special names (path, status) as variables, no unmatched globs.

# Absolute main checkout of the repo that holds $1 (a checkout or any of its worktrees)
function _wt_main() {
  local common
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  dirname "$common"
}

# "<session id>\t<cwd>" of every running Claude session except session $1; exit 2 when the registry can't be read
function _wt_live_sessions() {
  local reg=${WT_SESSIONS_DIR:-$HOME/.claude/sessions} pid start sid cwd
  [[ -d "$reg" && -r "$reg" ]] || return 2
  find "$reg" -maxdepth 1 -name '*.json' -exec jq -r --arg x "$1" \
    'select(.sessionId != $x) | [.pid, .procStart, .sessionId, .cwd] | @tsv' {} + 2>/dev/null |
    while IFS=$'\t' read -r pid start sid cwd; do
      kill -0 "$pid" 2>/dev/null || continue
      # procStart is UTC; a reused pid has another start time
      [[ "$(env TZ=UTC LC_ALL=C ps -o lstart= -p "$pid" | tr -s ' ' | sed 's/^ //;s/ $//')" == "$(tr -s ' ' <<<"$start")" ]] || continue
      printf '%s\t%s\n' "$sid" "$cwd"
    done
}

# Ignored files in worktree $2 that match the main checkout $1's .worktreeinclude, relative paths, one per line
function _wt_include_files() {
  [[ -f "$1/.worktreeinclude" ]] || return 0
  git --no-optional-locks -C "$2" ls-files --others --ignored --exclude-from="$1/.worktreeinclude" 2>/dev/null
}

# Value of key $2 in lock reason $1 ("… key:value …")
function _wt_lock_field() {
  tr ' ' '\n' <<<"$1" | sed -n "s/^$2://p" | head -n 1
}

# One row per linked worktree of repo $1, tab-separated:
# dir, branch (or "(detached)"), live (alive|dead|unknown), dirty count, unpushed count, class (safe|keep:<reason>), lock
# $2: a session id whose own registry entry doesn't count as live (wt-rm --self)
function wt-status() {
  # Declared once, outside the loop: zsh prints a variable that `local` names again without a value
  local repo=${1:-.} self=$2 main live_rows reg_rc=0 dir branch lock live dirty unpushed class f sid cwd owner
  main=$(_wt_main "$repo") || { echo "wt-status: not a git repository: $repo" >&2; return 1; }
  live_rows=$(_wt_live_sessions "$self") || reg_rc=$?
  git --no-optional-locks -C "$main" worktree list --porcelain | awk '
    function flush() { if (dir != "" && !prunable) printf "%s\t%s\t%s\n", dir, branch, lock; dir = branch = lock = ""; prunable = 0 }
    /^worktree / { flush(); dir = substr($0, 10); next }
    /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch); next }
    /^locked/    { lock = substr($0, 8); if (lock == "") lock = "locked"; next }
    /^prunable/  { prunable = 1; next }
    END { flush() }' | while IFS=$'\t' read -r dir branch lock; do
    [[ "$dir" == "$main" ]] && continue
    live=dead class=""
    if [[ $reg_rc -ne 0 ]]; then live=unknown
    else
      # Alive when a running session's cwd is inside the tree (covers --tmux, whose lock names the launcher's id),
      # or its id is the lock's owner (covers /wt runs, which keep cwd in the main checkout and use git -C)
      owner=$(_wt_lock_field "$lock" session)
      while IFS=$'\t' read -r sid cwd; do
        [[ -n "$cwd" && ( "$cwd" == "$dir" || "$cwd" == "$dir"/* ) ]] && { live=alive; break; }
        [[ -n "$owner" && "$sid" == "$owner" ]] && { live=alive; break; }
      done <<<"$live_rows"
    fi
    dirty=$(git --no-optional-locks -C "$dir" status --porcelain 2>/dev/null | grep -c .)
    if [[ -n "$branch" ]]; then
      unpushed=$(git --no-optional-locks -C "$dir" rev-list --count HEAD --not --exclude="$branch" --branches --remotes 2>/dev/null)
    else
      unpushed=$(git --no-optional-locks -C "$dir" rev-list --count HEAD --not --branches --remotes 2>/dev/null)
    fi
    if [[ $live == alive ]]; then class=keep:live
    elif [[ $live == unknown ]]; then class=keep:unknown
    elif [[ "$dirty" != 0 ]]; then class=keep:dirty
    elif [[ "${unpushed:-1}" != 0 ]]; then class=keep:unpushed
    else
      while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        cmp -s "$dir/$f" "$main/$f" || { class=keep:include; break; }
      done < <(_wt_include_files "$main" "$dir")
      class=${class:-safe}
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$dir" "${branch:-(detached)}" "$live" "$dirty" "${unpushed:-?}" "$class" "$lock"
  done
}

# Create a locked worktree <main>/.claude/worktrees/<name> on a new or existing branch and copy .worktreeinclude files.
# wt-new <repo> <name> [--branch b] [--base ref] [--session id] [--skill s]; progress to stderr, the path last on stdout
function wt-new() {
  local repo=$1 name=$2 branch="" base="" session="" skill=cw made=0 main dir reason base_sha ticket f
  shift 2 2>/dev/null || { echo "usage: wt-new <repo> <name> [--branch b] [--base ref] [--session id]" >&2; return 2; }
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch) branch=$2; shift 2 ;;
      --base) base=$2; shift 2 ;;
      --session) session=$2; shift 2 ;;
      --skill) skill=$2; shift 2 ;;
      *) echo "wt-new: unknown option $1" >&2; return 2 ;;
    esac
  done
  if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ || "$name" == *..* || "$name" == .* ]]; then
    echo "wt-new: bad worktree name '$name'" >&2; return 2
  fi
  branch=${branch:-chore/$name}
  git check-ref-format --branch "$branch" >/dev/null 2>&1 || { echo "wt-new: bad branch name '$branch'" >&2; return 2; }
  main=$(_wt_main "$repo") || { echo "wt-new: not a git repository: $repo" >&2; return 1; }
  dir="$main/.claude/worktrees/$name"
  [[ -e "$dir" ]] && { echo "wt-new: $dir already exists" >&2; return 1; }

  git -C "$main" worktree prune
  if ! git -C "$main" check-ignore -q .claude/worktrees/probe; then
    echo ".claude/worktrees/" >>"$(git -C "$main" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  fi

  if [[ -z "$base" ]]; then
    if git -C "$main" remote get-url origin >/dev/null 2>&1 && git -C "$main" fetch -q origin 2>/dev/null &&
      base=$(git -C "$main" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then :
    else
      base=HEAD
      echo "wt-new: no origin or fetch failed; branching from local HEAD" >&2
    fi
  fi
  base_sha=$(git -C "$main" rev-parse --short "$base^{commit}" 2>/dev/null) || { echo "wt-new: unknown base '$base'" >&2; return 1; }

  [[ "$branch" =~ ^[a-z]+/([0-9]+)_ ]] && ticket=${BASH_REMATCH[1]:-${match[1]}}
  reason="claude-skill:$skill${ticket:+ ticket:$ticket} branch:$branch started:$(date +%F)${session:+ session:$session} base:$base_sha"
  if git -C "$main" show-ref -q --verify "refs/heads/$branch"; then
    git -C "$main" worktree add -q --lock --reason "$reason" "$dir" "$branch" >&2 || return 1
  else
    made=1
    git -C "$main" worktree add -q --lock --reason "$reason made:1" --no-track -b "$branch" "$dir" "$base" >&2 || return 1
  fi

  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    mkdir -p "$(dirname "$dir/$f")" && cp -p "$main/$f" "$dir/$f" && echo "wt-new: copied $f" >&2
  done < <(git -C "$main" ls-files --others --ignored --exclude-from="$main/.worktreeinclude" 2>/dev/null)
  echo "$dir"
}

# Remove worktree $dir when wt-status calls it safe; else print why and exit 1 (tree stays, still locked).
# --self <id>: session <id> doesn't count as live (its own cleanup). --discard: skip the check and force-remove.
# Deletes the branch only when wt-new made it (made:1) and it has no commit past its base
function wt-rm() {
  local self="" discard=0 dir main row class lock branch base made
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --self) self=$2; shift 2 ;;
      --discard) discard=1; shift ;;
      *) dir=${1%/}; shift ;;
    esac
  done
  [[ -n "$dir" ]] || { echo "usage: wt-rm [--self <session id>] [--discard] <worktree dir>" >&2; return 2; }
  main=$(_wt_main "$dir") || { echo "wt-rm: not a worktree: $dir" >&2; return 1; }
  dir=$(cd "$dir" && pwd -P) || return 1
  [[ "$dir" != "$(cd "$main" && pwd -P)" ]] || { echo "wt-rm: refusing to remove the main checkout" >&2; return 1; }
  row=$(wt-status "$main" "$self" | awk -F '\t' -v d="$dir" '$1 == d')
  [[ -n "$row" ]] || { echo "wt-rm: $dir is not a linked worktree of $main" >&2; return 1; }
  branch=$(cut -f2 <<<"$row") class=$(cut -f6 <<<"$row") lock=$(cut -f7 <<<"$row")
  [[ "$branch" == "(detached)" ]] && branch=""
  if [[ $discard -eq 0 && "$class" != safe ]]; then
    echo "wt-rm: kept $dir ($class)" >&2; return 1
  fi

  [[ -n "$lock" ]] && git -C "$main" worktree unlock "$dir" 2>/dev/null
  if [[ $discard -eq 1 ]]; then
    git -C "$main" worktree remove --force --force "$dir"
  else
    git -C "$main" worktree remove "$dir"
  fi || {
    [[ -n "$lock" ]] && git -C "$main" worktree lock --reason "$lock" "$dir" 2>/dev/null
    echo "wt-rm: kept $dir (git worktree remove failed)" >&2; return 1
  }
  git -C "$main" worktree prune
  echo "wt-rm: removed $dir" >&2

  base=$(_wt_lock_field "$lock" base) made=$(_wt_lock_field "$lock" made)
  if [[ -n "$branch" && "$made" == 1 && -n "$base" ]] &&
    [[ "$(git -C "$main" rev-list --count "$base..refs/heads/$branch" 2>/dev/null)" == 0 ]]; then
    git -C "$main" branch -q -D -- "$branch" && echo "wt-rm: deleted branch $branch (no commits)" >&2
  elif [[ -n "$branch" ]]; then
    echo "wt-rm: kept branch $branch" >&2
  fi
  return 0
}

# Remove every safe worktree of repo $1; dry run unless --apply. Applied runs append to ${WT_SWEEP_LOG:-~/.cache/wt-sweep.log}
function wt-sweep() {
  local repo="" apply=0 main lockdir log=${WT_SWEEP_LOG:-$HOME/.cache/wt-sweep.log} dir class rc=0
  while [[ $# -gt 0 ]]; do
    case "$1" in --apply) apply=1 ;; *) repo=$1 ;; esac
    shift
  done
  main=$(_wt_main "${repo:-.}") || { echo "wt-sweep: not a git repository: ${repo:-.}" >&2; return 1; }
  lockdir="$(git -C "$main" rev-parse --path-format=absolute --git-common-dir)/wt-sweep.lock"
  mkdir "$lockdir" 2>/dev/null || { echo "wt-sweep: another sweep is running ($lockdir)" >&2; return 1; }
  trap 'rmdir "$lockdir" 2>/dev/null' EXIT INT TERM

  while IFS=$'\t' read -r dir _ _ _ _ class _; do
    if [[ "$class" != safe ]]; then
      printf 'keep\t%s\t%s\n' "$class" "$dir"
    elif [[ $apply -eq 0 ]]; then
      printf 'would remove\t%s\n' "$dir"
    elif wt-rm "$dir" 2>&1; then
      printf '%s removed %s\n' "$(date '+%F %T')" "$dir" >>"$log"
    else
      printf '%s failed %s\n' "$(date '+%F %T')" "$dir" >>"$log"; rc=1
    fi
  done < <(wt-status "$main")

  rmdir "$lockdir" 2>/dev/null
  trap - EXIT INT TERM
  return $rc
}
