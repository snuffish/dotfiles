#!/usr/bin/env bash
# Pick from your Azure DevOps pull requests (the PRs you created or review) with fzf
#   adopr.sh [--all]    --all also lists completed and abandoned PRs
# Enter opens the PR in the browser, Ctrl-Y copies its URL, Ctrl-R refreshes, Ctrl-F toggles pattern mode
# (utils/fzf-pattern.sh). Read-only: one `az repos pr list` for the PRs you created and one for those you review per
# refresh. The lists and PR threads are cached in $ADOPR_CACHE (default ~/.cache/adopr): the picker opens on the cache and
# refreshes the PR list in the background; threads are re-fetched after $ADOPR_THREAD_TTL minutes (default 10) or on
# Ctrl-R. The subcommands below are the picker's own callbacks.

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
fp="$(dirname "$self")/fzf-pattern.sh"

ADOPR_CACHE="${ADOPR_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/adopr}"
export ADOPR_CACHE

die() { echo "adopr: $*" >&2; exit 1; }

# The signed-in user, read from az's profile so the login check costs no az call
current_user() {
  jq -r '[.subscriptions[]? | select(.isDefault)][0].user.name // empty' "$HOME/.azure/azureProfile.json" 2>/dev/null
}

# Cache the PRs for the signed-in user as $ADOPR_PRS: newest first, one entry per PR, creator role wins
fetch() {
  local me status=active
  me="$(current_user)"
  [[ -n "$me" ]] || die "not signed in to Azure: run 'az login'"
  [[ -n "$ADOPR_ALL" ]] && status=all

  local query='[].{id:pullRequestId,title:title,draft:isDraft,status:status,created:creationDate,repo:repository.name,project:repository.project.name,desc:description,author:createdBy.displayName,src:sourceRefName,tgt:targetRefName,reviewers:reviewers[].{name:displayName,vote:vote,required:isRequired},apiUrl:url}'
  local who
  for who in creator reviewer; do
    az repos pr list "--$who" "$me" --status "$status" --top 50 --only-show-errors --query "$query" -o json \
      >"$ADOPR_DIR/$who.json" 2>"$ADOPR_DIR/$who.err" ||
      die "az repos pr list failed (if the sign-in expired, run 'az login'): $(head -c 300 "$ADOPR_DIR/$who.err")"
  done

  jq -n --slurpfile a "$ADOPR_DIR/creator.json" --slurpfile r "$ADOPR_DIR/reviewer.json" '
    ($a[0] | map(.id)) as $mine
    | ($a[0] | map(. + {role: "author"})) + ($r[0] | map(select(.id | IN($mine[]) | not) | . + {role: "review"}))
    | sort_by(.created) | reverse
    | map(. + {rid: (.apiUrl | capture("/repositories/(?<rid>[^/]+)/") | .rid)})
    | map(. + {url: ((.apiUrl | capture("^https://(?<host>[^/]+)/") | .host
          | if endswith(".visualstudio.com") then "dev.azure.com/" + split(".")[0] else "dev.azure.com" end) as $base
        | "https://" + $base + "/" + .project + "/_git/" + .repo + "/pullrequest/" + (.id | tostring))})' \
    >"$ADOPR_PRS.$$" || die "could not read the PR lists"
  # Replaced only once complete: the picker may be reading the cache
  command mv -f "$ADOPR_PRS.$$" "$ADOPR_PRS"
}

# Threads of PR $1 as $ADOPR_CACHE/threads/$1.json (one az call)
fetch_threads() {
  local rid out="$ADOPR_CACHE/threads/$1.json"
  rid="$(jq -r --argjson id "$1" '.[] | select(.id == $id) | .rid' "$ADOPR_PRS")"
  az devops invoke --area git --resource pullRequestThreads \
    --route-parameters project=PRIIS repositoryId="$rid" pullRequestId="$1" \
    --api-version 7.1 --only-show-errors -o json 2>"$ADOPR_DIR/thread-$1.err" |
    jq --argjson id "$1" '{id: $id, threads: .value}' >"$out.$$" || return 1
  command mv -f "$out.$$" "$out"
}

# Threads of the 15 newest PRs into $ADOPR_DIR/activity.json. Cached ones are reused until they are older than
# $ADOPR_THREAD_TTL minutes (default 10); the rest are fetched six az calls at a time. "fresh" fetches all.
fetch_activity() {
  local id ttl="${ADOPR_THREAD_TTL:-10}" stale=() ids=() files=()
  command mkdir -p "$ADOPR_CACHE/threads"
  while read -r id; do
    ids+=("$id")
    files+=("$ADOPR_CACHE/threads/$id.json")
    if [[ "$1" == fresh || -z "$(find "$ADOPR_CACHE/threads/$id.json" -mmin "-$ttl" 2>/dev/null)" ]]; then
      stale+=("$id")
    fi
  done < <(jq -r '.[0:15][].id' "$ADOPR_PRS")
  if [[ ${#stale[@]} -gt 0 ]]; then
    printf '%s\n' "${stale[@]}" | xargs -P 6 -I{} bash "$self" thread {} ||
      die "could not read the PR threads (if the sign-in expired, run 'az login')"
  fi
  jq -s '.' "${files[@]}" >"$ADOPR_DIR/activity.json"
}

# Rows: PR ID, KIND (comment/vote/status), WHO, TEXT, AGE (shown), URL, PR:THREAD (hidden); every comment in the
# cached threads, newest first
activity() {
  fetch_activity "$1" || return 1
  jq -r --argjson now "$(date +%s)" --arg me "$(current_user)" --slurpfile prs "$ADOPR_PRS" '
    def age: ($now - (.d[0:19] + "Z" | fromdateiso8601)) as $s
      | if $s < 3600 then "\($s / 60 | floor)m" elif $s < 86400 then "\($s / 3600 | floor)h" else "\($s / 86400 | floor)d" end;
    def paint($c): "\u001b[\($c)m" + . + "\u001b[0m";
    def kind: if .t != "system" then "comment" elif (.x | test(" voted ")) then "vote" else "status" end;
    [.[] | .id as $pr | .threads[]? | .id as $th | .threadContext.filePath as $fp
      | .comments[]? | select(.isDeleted | not) | select(.content != "Policy status has been updated")
      | {pr: $pr, th: $th, fp: $fp, d: .publishedDate, t: .commentType, who: .author.displayName,
         mine: (.author.uniqueName == $me), x: (.content // "")}]
    | sort_by(.d) | reverse | .[]
    | . as $c | ($prs[0][] | select(.id == $c.pr) | .url) as $url
    | [(.pr | tostring | paint("1")), (kind | paint(if . == "comment" then "33" else "90" end)),
       (.who | paint(if $c.mine then "36" else "35" end)), (.x | gsub("\\s+"; " ") | if length > 100 then .[0:99] + "…" else . end), (age | paint("90")),
       "\($url)?discussionId=\(.th)", "\(.pr):\(.th)"] | @tsv' "$ADOPR_DIR/activity.json"
}

# Every comment of thread $1 (PR:THREAD), from the cache
activity_preview() {
  jq -r --arg key "$1" '
    ($key | split(":") | map(tonumber)) as [$pr, $th]
    | .[] | select(.id == $pr) | .threads[] | select(.id == $th)
    | (if .threadContext.filePath then "\u001b[1m\(.threadContext.filePath)\u001b[0m" else "\u001b[1mPR #\($pr)\u001b[0m" end),
      "status: \(.status // "none")", "",
      (.comments[] | select(.isDeleted | not) | "\u001b[1m\(.author.displayName)\u001b[0m  \(.publishedDate[0:16] | sub("T"; " "))", (.content // ""), "")' \
    "$ADOPR_DIR/activity.json"
}

# fzf action for Ctrl-A: swap between the PR list and the activity view
switch_view() {
  if [[ "$FZF_PROMPT" == Activity* ]]; then
    echo "enable-search+clear-query+change-prompt(PRs> )+change-border-label( My pull requests )+change-preview(bash $self preview {1})+reload(cat \"\$FZFP_DIR/rows\")"
  else
    echo "enable-search+clear-query+change-prompt(Activity> )+change-border-label( My recent activity )+change-preview(bash $self apreview {7})+reload(bash $self activity)"
  fi
}

# fzf action for Ctrl-R: re-fetch and reload the current view
refresh() {
  if [[ "$FZF_PROMPT" == Activity* ]]; then
    echo "reload(bash $self fetch && bash $self activity fresh)"
  else
    echo "reload(bash $self fetch && bash $self rows | bash $fp pipe 2,3,4 || cat \"\$FZFP_DIR/rows\")"
  fi
}

# fzf action for Ctrl-F / query change: pattern mode filters the PR list's cache, so the activity view has none
pattern() {
  [[ "$FZF_PROMPT" == Activity* ]] && exit 0
  exec bash "$fp" "$1" 2,3,4
}

# Rows: ID, ROLE, STATE, TITLE, AGE (shown), URL (hidden)
rows() {
  jq -r --argjson now "$(date +%s)" '
    def age: ($now - (.created[0:19] + "Z" | fromdateiso8601)) as $s
      | if $s < 3600 then "\($s / 60 | floor)m" elif $s < 86400 then "\($s / 3600 | floor)h" else "\($s / 86400 | floor)d" end;
    def state: if .draft and .status == "active" then "draft" else .status end;
    def paint($c): "\u001b[\($c)m" + . + "\u001b[0m";
    .[] | [(.id | tostring | paint("1")), (.role | paint(if . == "author" then "36" else "35" end)),
           (state | paint(if . == "draft" then "90" elif . == "active" then "32" elif . == "completed" then "34" else "31" end)),
           .title, (age | paint("90")), .url] | @tsv' "$ADOPR_PRS"
}

# Description, reviewers and votes of PR $1, from the cache
preview() {
  jq -r --arg id "$1" '
    def vote: if . >= 10 then "approved" elif . >= 5 then "approved, with suggestions" elif . <= -10 then "rejected" elif . <= -5 then "waiting for author" else "no vote" end;
    .[] | select(.id == ($id | tonumber))
    | "\u001b[1m#\(.id) \(.title)\u001b[0m", "\(.author) · \(.src | ltrimstr("refs/heads/")) → \(.tgt | ltrimstr("refs/heads/"))", "",
      "\u001b[1mReviewers\u001b[0m",
      (if (.reviewers | length) == 0 then "  none" else (.reviewers[] | "  \(.name)\(if .required then " (required)" else "" end): \(.vote | vote)") end), "",
      "\u001b[1mDescription\u001b[0m", (.desc // "(none)")' "$ADOPR_PRS"
}

open_url() {
  if command -v open >/dev/null 2>&1; then open "$1"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1
  else explorer.exe "$1"; fi
}

copy_url() {
  printf %s "$1" | { wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null || clip.exe; }
}

case "$1" in
  rows) rows; exit ;;
  preview) preview "$2"; exit ;;
  fetch) fetch; exit ;;
  thread) fetch_threads "$2"; exit ;;
  activity) activity "$2"; exit ;;
  apreview) activity_preview "$2"; exit ;;
  view) switch_view; exit ;;
  refresh) refresh; exit ;;
  pattern) pattern "$2" ;;
  open) open_url "$2"; exit ;;
  copy) copy_url "$2"; exit ;;
esac

command -v az >/dev/null 2>&1 || die "az is not installed"
command -v fzf >/dev/null 2>&1 || die "fzf is not installed"
command -v jq >/dev/null 2>&1 || die "jq is not installed"
[[ "$1" == --all ]] && export ADOPR_ALL=1

ADOPR_DIR="$(mktemp -d)" || exit 1
FZFP_DIR="$ADOPR_DIR"
export ADOPR_DIR FZFP_DIR
trap 'command rm -rf -- "$ADOPR_DIR"' EXIT

me="$(current_user)"
[[ -n "$me" ]] || die "not signed in to Azure: run 'az login'"
status=active
[[ -n "$ADOPR_ALL" ]] && status=all
# The cache holds PR descriptions and comments: private to you, one list per user and scope
command mkdir -p -m 700 "$ADOPR_CACHE"
ADOPR_PRS="$ADOPR_CACHE/prs-$status-${me//[^[:alnum:]]/_}.json"
export ADOPR_PRS

# Open on the cached list at once and refresh it in the background unless it is under a minute old
start_bind=()
if [[ -s "$ADOPR_PRS" ]]; then
  [[ -n "$(find "$ADOPR_PRS" -mmin -1)" ]] ||
    start_bind=(--bind="start:reload(bash $self fetch && bash $self rows | bash $fp pipe 2,3,4 || cat \"\$FZFP_DIR/rows\")")
else
  fetch || exit 1
fi
rows >"$FZFP_DIR/rows"

title="My pull requests"
[[ -n "$ADOPR_ALL" ]] && title="My pull requests · all states"

fzf --ansi \
  --header $'[Enter] Open · [Ctrl-Y] Copy URL · [Ctrl-R] Refresh · [Ctrl-F] Pattern · [Ctrl-A] PRs/Activity' \
  --border rounded --border-label " $title " --preview-border rounded \
  --color 'border:8,label:6:bold,preview-border:8,preview-label:6:bold,info:8,separator:8,scrollbar:8' \
  --color 'prompt:6:bold,pointer:5,marker:5,hl:3:bold,hl+:3:bold,fg+:-1:bold,query:-1:bold' \
  --prompt "PRs> " --delimiter='\t' --with-nth=1,2,3,4,5 --no-sort \
  --bind='focus:transform-preview-label:printf " #%s " {1}' \
  --bind="enter:execute-silent(bash $self open {6})+abort" \
  --bind="ctrl-y:execute-silent(bash $self copy {6})+abort" \
  --bind="ctrl-a:transform:bash $self view" \
  --bind="ctrl-f:transform:bash $self pattern toggle" \
  --bind="change:transform:bash $self pattern change" \
  --bind="ctrl-r:transform:bash $self refresh" \
  "${start_bind[@]}" \
  --preview="bash $self preview {1}" \
  --preview-window 'right,55%,wrap' --height 60% --layout reverse <"$FZFP_DIR/rows"
