#!/usr/bin/env bash
# "?" keys card for the fzf pickers (gb, gw, cr, agr, ar, cms, adopr): on an empty query it shows the picker's keys and
# what its row icons and colours mean in the preview, until the cursor moves (fzf's preview(...) action is temporary,
# so the picker's own preview mode comes back); with a query, "?" is typed as usual
#   fzf-keys.sh bind NAME   the fzf action for "?": --bind "?:transform:bash <this> bind NAME"
#   fzf-keys.sh NAME        the card

self="${BASH_SOURCE[0]}"

if [[ "$1" == bind ]]; then
  if [[ -n "$FZF_QUERY" ]]; then echo 'put(?)'; else echo "preview(bash $self $2)+show-preview"; fi
  exit 0
fi

b=$'\033[1m' d=$'\033[90m' g=$'\033[32m' r=$'\033[31m' y=$'\033[33m' c=$'\033[36m' m=$'\033[35m' bl=$'\033[34m' x=$'\033[0m'

title() { printf '%s  keys · %s%s\n\n' "$b" "$1" "$x"; }
foot() { printf '\n%s  ? on an empty query shows this card; move the cursor to close it%s\n' "$d" "$x"; }

# Keys shared by the three session pickers (cr, agr, ar)
session_keys() {
  cat <<EOF
  ctrl-s      copy the session id
  ctrl-t      this dir ↔ all dirs
  ctrl-g      fuzzy over titles ↔ text in transcripts
  ctrl-r      pattern mode: regex or glob over the list
  ctrl-p      show ↔ hide the preview
  esc         quit
EOF
}

# Row parts from claude/sessions.sh, utils/session_tree.py and (ar) utils/unified-sessions.sh
session_legend() {
  cat <<EOF

  columns: age · short id · ${m}branch${x} · title (${bl}directory${x} first in all dirs)
  ${g}●${x}  on the age: written in the last 2 minutes, likely still open
  ·  new session    ⟲ after /clear    ⑂ fork    ↳ subagent
  ├ └  under the session it came from
  ${r}wt:<name>${x}  ran in that worktree    ${r}wt→<name>${x}  locked that worktree
EOF
  [[ "$1" == ar ]] && printf '  %s[claude]%s  %s[agy]%s  which agent\n' "$y" "$x" "$c" "$x"
}

case "$1" in
  gb)
    title gb
    cat <<EOF
  enter       check out the branch, or cd to the worktree that has it
  ctrl-t      local branches ↔ all (remotes too)
  ctrl-r      fuzzy ↔ pattern: regex or glob on branch + subject
  ctrl-d      diff against HEAD    ctrl-s  log
  ctrl-y      copy the branch name
  esc         quit

  ${g}●${x}  checked out here
  ${r}◆${x}  checked out in another worktree (${r}wt:<name>${x}); enter goes there
  🔒 that worktree is locked, then the lock reason
  ${c}cyan${x} remote branch (${d}origin${x})    ${m}magenta${x} local branch
  ${y}↑2 ↓1${x}  ahead / behind its upstream
  last column: subject of the newest commit
EOF
    foot
    ;;
  gw)
    title gw
    cat <<EOF
  enter       cd to the worktree
  ctrl-s      status preview    ctrl-d  diff preview (untracked too)
  ctrl-o      open in Antigravity
  ctrl-y      copy the path
  ctrl-x      delete (wt-rm refuses dirty, unpushed and live ones)
  alt-c       sweep: delete every ${g}safe${x} worktree
  ctrl-r      prune entries whose folder is gone
  ctrl-f      fuzzy ↔ pattern: regex or glob on the label
  shift-↑/↓   scroll the preview
  esc         quit

  ${g}●${x}  the worktree you are in
  ${r}✎3${x}  changed files    ${y}↑2 ↓1${x}  ahead / behind its upstream
  ${y}🔒 skill #ticket${x} date   locked by an agent; a date older than 3 days is ${r}red${x}
  ${y}🔒 reason${x}   locked by hand
  ${g}safe${x}        clean, pushed and no session in it: alt-c may delete it
  ${d}keep:live${x}   a running session works in it
  ${d}keep:dirty${x}  uncommitted changes    ${d}keep:unpushed${x}  commits on no other branch
  ${d}keep:include${x} worktree-include files differ from the main checkout
  ${d}keep:unknown${x} the session registry could not be read
  ${r}dead${x}        locked, but no live session is in it
EOF
    foot
    ;;
  cr)
    title cr
    cat <<EOF
  enter       resume in its own directory (a fork when it is open elsewhere)
  ctrl-o      resume as a fork (new session id)
EOF
    session_keys
    session_legend
    foot
    ;;
  agr)
    title agr
    cat <<EOF
  enter       resume in its own directory (focuses it when already open)
  ctrl-f      fork into a new agy session
  ctrl-u      show ↔ hide subagent sessions
EOF
    session_keys
    session_legend
    foot
    ;;
  ar)
    title ar
    cat <<EOF
  enter       resume (Claude: a fork when open elsewhere; agy: focus it)
  ctrl-f      fork with the same agent
  ctrl-x      cross-fork: Claude → agy, agy → Claude
  ctrl-l      follow the transcript live (ctrl-c stops)
  ctrl-a      all agents → Claude → agy
EOF
    session_keys
    session_legend ar
    foot
    ;;
  cms)
    title cms
    cat <<EOF
  enter       print the record
  ctrl-o      resume the Claude session it came from
  ctrl-y      copy the ref
  ctrl-r      reveal a hidden sensitive memory in the preview
  ctrl-s      memories → summaries → prompts
  ctrl-t      this project ↔ all projects
  ctrl-g      fuzzy ↔ full-text search
  esc         quit

  refs: #<id> memory · S<id> summary · P<id> prompt
  ${y}●${x} bugfix  ${y}◆${x} feature  ${y}↻${x} refactor  ${y}✓${x} change  ${y}○${x} discovery  ${y}⚖${x} decision
  ${y}⚠${x} security alert  ${y}⚷${x} security note  ${y}⊘${x} sensitive  ${y}🎯${x} summary  ${y}❯${x} prompt
  ${bl}blue${x} project name (all projects only)
EOF
    foot
    ;;
  adopr)
    title adopr
    cat <<EOF
  enter       open in the browser
  ctrl-y      copy the URL
  ctrl-r      refresh from Azure DevOps
  ctrl-f      fuzzy ↔ pattern (PR list)
  ctrl-a      PR list ↔ activity
  esc         quit (keeps view, query and position)

  PR list: id · role · state · title · age
    ${c}author${x} your PR    ${m}reviewer${x} you review it
    ${d}draft${x}  ${g}active${x}  ${bl}completed${x}  ${r}abandoned${x}
  activity: PR or #work item · kind · who · text · age
    ${y}comment${x}  ${d}vote / status${x}  ${bl}work item type${x}
    ${c}you${x}  ${m}others${x}    @ mentioned · assigned · touched
EOF
    foot
    ;;
  *)
    echo "fzf-keys.sh: no card for '$1'" >&2
    exit 2
    ;;
esac
