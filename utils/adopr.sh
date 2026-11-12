#!/usr/bin/env bash
# Pick from your Azure DevOps pull requests (the PRs you created or review) with fzf
#   adopr.sh [--all]    --all also lists completed and abandoned PRs
#   adopr.sh --activity opens on the activity view (the tmux badge's prefix + A popup)
# Enter opens the PR in the browser, Ctrl-Y copies its URL, Ctrl-R refreshes, Ctrl-F toggles pattern mode
# (utils/fzf-pattern.sh). Read-only: one `az repos pr list` for the PRs you created and one for those you review per
# refresh. The lists and PR threads are cached in $ADOPR_CACHE (default ~/.cache/adopr): the picker opens on the cache and
# refreshes the PR list in the background; threads are re-fetched after $ADOPR_THREAD_TTL minutes (default 10) or on
# Ctrl-R. The Ctrl-A activity view also lists work items you changed, own or were @-mentioned in (one WIQL per refresh,
# the last $ADOPR_WI_DAYS days, default 7; @RecentMentions has its own fixed 30-day window), with the fields and the 3
# newest comments of the focused item in the preview. Closing the picker saves its view, pattern mode, query and cursor
# position next to the PR cache, and the next start reopens there. The subcommands below are the picker's own callbacks.

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
fp="$(dirname "$self")/fzf-pattern.sh"

ADOPR_CACHE="${ADOPR_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/adopr}"
export ADOPR_CACHE

die() { echo "adopr: $*" >&2; exit 1; }

# The signed-in user, read from az's profile so the login check costs no az call
current_user() {
  jq -r '[.subscriptions[]? | select(.isDefault)][0].user.name // empty' "$HOME/.azure/azureProfile.json" 2>/dev/null
}

_me="$(current_user)"
ADOPR_WI="${ADOPR_WI:-$ADOPR_CACHE/workitems-${_me//[^[:alnum:]]/_}.json}"
export ADOPR_WI

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

# Work items you changed, own or were @-mentioned in as $ADOPR_WI: {items: [...]} (50 newest) or {error: "..."}.
# Reused until older than $ADOPR_THREAD_TTL minutes; "fresh" fetches. A failure is stored, not fatal, so the PR rows stay.
fetch_workitems() {
  local days="${ADOPR_WI_DAYS:-7}" ttl="${ADOPR_THREAD_TTL:-10}" t p1 p2 r1 r2 select where
  command mkdir -p -m 700 "$ADOPR_CACHE"
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo '{"error":"ADOPR_WI_DAYS must be a whole number of days"}' >"$ADOPR_WI"
    return 0
  fi
  if [[ "$1" != fresh ]] && jq -e '.items' "$ADOPR_WI" >/dev/null 2>&1 && [[ -n "$(find "$ADOPR_WI" -mmin "-$ttl")" ]]; then
    return 0
  fi
  t="$(mktemp -d)" || return 1
  select='SELECT [System.Id],[System.Title],[System.WorkItemType],[System.State],[System.ChangedDate],[System.ChangedBy],[System.AssignedTo] FROM WorkItems'
  where="WHERE [System.Id] IN (@RecentMentions) OR ((EVER [System.ChangedBy] = @Me OR [System.AssignedTo] = @Me) AND [System.ChangedDate] >= @Today - $days) ORDER BY [System.ChangedDate] DESC"
  az boards query --wiql "$select $where" --only-show-errors -o json >"$t/w.json" 2>"$t/w.err" &
  p1=$!
  az boards query --wiql 'SELECT [System.Id] FROM WorkItems WHERE [System.Id] IN (@RecentMentions)' --only-show-errors -o json \
    >"$t/m.json" 2>"$t/m.err" &
  p2=$!
  wait "$p1"; r1=$?
  wait "$p2"; r2=$?
  if [[ $r1 -eq 0 && $r2 -eq 0 ]]; then
    jq -n --slurpfile w "$t/w.json" --slurpfile m "$t/m.json" --arg me "$(current_user)" '
      def clean: gsub("[\u0001-\u001f\u007f]"; " ");
      ($m[0] | map(.id)) as $mine
      | {items: ($w[0][0:50] | map(. as $i | {id: .id, type: (.fields["System.WorkItemType"] | clean),
          state: (.fields["System.State"] | clean), title: (.fields["System.Title"] | clean),
          changed: .fields["System.ChangedDate"], by: (.fields["System.ChangedBy"].displayName // "" | clean),
          mine: (.fields["System.ChangedBy"].uniqueName == $me),
          assigned: (.fields["System.AssignedTo"].uniqueName == $me), mention: (.id | IN($mine[])),
          url: ((.url | capture("^https://(?<host>[^/]+)/") | .host
              | if endswith(".visualstudio.com") then "dev.azure.com/" + split(".")[0] else "dev.azure.com" end) as $base
            | "https://" + $base + "/PRIIS/_workitems/edit/" + (.id | tostring))}))}' >"$ADOPR_WI.$$" &&
      command mv -f "$ADOPR_WI.$$" "$ADOPR_WI"
  else
    jq -n --arg e "$(cat "$t/w.err" "$t/m.err" | head -c 200)" \
      '{error: ("work items: " + ($e | gsub("[\u0001-\u001f\u007f]"; " ")))}' >"$ADOPR_WI"
  fi
  command rm -rf -- "$t"
}

# Fields, parent and 3 newest comments of work item $1 as $ADOPR_CACHE/wi/$1.json, reused for $ADOPR_THREAD_TTL minutes
fetch_wi_detail() {
  [[ "$1" =~ ^[0-9]+$ ]] || return 1
  local ttl="${ADOPR_THREAD_TTL:-10}" out="$ADOPR_CACHE/wi/$1.json"
  command mkdir -p -m 700 "$ADOPR_CACHE/wi"
  [[ -z "$(find "$out" -mmin "-$ttl" 2>/dev/null)" ]] || return 0
  az boards work-item show --id "$1" --expand relations --only-show-errors -o json >"$out.w.$$" 2>/dev/null &&
    az devops invoke --area wit --resource comments --route-parameters project=PRIIS workItemId="$1" \
      --query-parameters top=3 order=desc --api-version 7.1-preview --only-show-errors -o json >"$out.c.$$" 2>/dev/null &&
    jq -n --slurpfile w "$out.w.$$" --slurpfile c "$out.c.$$" '
      {fields: $w[0].fields,
       parent: ([$w[0].relations[]? | select(.rel == "System.LinkTypes.Hierarchy-Reverse") | .url | capture("/(?<n>[0-9]+)$").n][0]),
       comments: ($c[0].comments // [] | map({by: .createdBy.displayName, at: .createdDate, text: .text}))}' >"$out.$$" &&
    command mv -f "$out.$$" "$out"
  local rc=$?
  command rm -f -- "$out.w.$$" "$out.c.$$" "$out.$$"
  return $rc
}

# Preview of work item $1: the listed fields at once, then the cached or fetched detail
wi_preview() {
  jq -r --argjson id "$1" '.items[]? | select(.id == $id)
    | "\u001b[1m#\(.id) \(.title)\u001b[0m", "\(.type) · \(.state)",
      "Changed   \(.changed[0:16] | sub("T"; " ")) by \(.by)", ""' "$ADOPR_WI"
  fetch_wi_detail "$1" || { echo "(could not read the work item)"; return 0; }
  jq -r '
    def text: gsub("<[^>]+>"; "") | gsub("&nbsp;"; " ") | gsub("&lt;"; "<") | gsub("&gt;"; ">") | gsub("&amp;"; "&")
      | gsub("[\u0001-\u0008\u000b-\u001f\u007f]"; " ");
    def clean: gsub("[\u0001-\u001f\u007f]"; " ");
    "Assigned  \(.fields["System.AssignedTo"].displayName // "–" | clean)",
    "Iteration \(.fields["System.IterationPath"] // "–" | clean)",
    "Parent    \(if .parent then "#" + .parent else "–" end)", "",
    "\u001b[1mComments\u001b[0m",
    (if (.comments | length) == 0 then "  none" else (.comments[0:3][] | "\u001b[1m\(.by | clean)\u001b[0m  \(.at[0:16] | sub("T"; " "))", "  \(.text | text)", "") end)' \
    "$ADOPR_CACHE/wi/$1.json"
}

# Threads of the 15 newest PRs into $ADOPR_DIR/activity.json. Cached ones are reused until they are older than
# $ADOPR_THREAD_TTL minutes (default 10); the rest are fetched six az calls at a time. "fresh" fetches all.
fetch_activity() {
  local id ttl="${ADOPR_THREAD_TTL:-10}" stale=() ids=() files=() wp
  command mkdir -p "$ADOPR_CACHE/threads"
  fetch_workitems "$1" &
  wp=$!
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
  wait "$wp"
  jq -s '.' "${files[@]}" >"$ADOPR_DIR/activity.json"
}

# The comment events of the cached PR threads, shared by the activity rows and the tmux badge counts: one parser
ADOPR_ENTRIES_JQ='
  def epoch: (.[0:19] + "Z" | fromdateiso8601);
  def kind: if .t != "system" then "comment" elif (.x | test(" voted ")) then "vote" else "status" end;
  def pr_events($me): [.[] | .id as $pr | .threads[]? | .id as $th | .threadContext.filePath as $fp
    | .comments[]? | select(.isDeleted | not) | select(.content != "Policy status has been updated")
    | {pr: $pr, th: $th, fp: $fp, d: .publishedDate, t: .commentType, who: .author.displayName,
       mine: (.author.uniqueName == $me), x: (.content // "")}];
'

# $ADOPR_CACHE/activity.json: the threads the activity view last showed, kept for the badge
persist_activity() {
  command cp "$ADOPR_DIR/activity.json" "$ADOPR_CACHE/activity.json.$$" &&
    command mv -f "$ADOPR_CACHE/activity.json.$$" "$ADOPR_CACHE/activity.json"
}

# $ADOPR_CACHE/seen: epoch of the newest entry the activity view showed; only ever moves forward
mark_seen() {
  local newest seen
  newest="$(jq -n -r --arg me "$(current_user)" --slurpfile act "$ADOPR_CACHE/activity.json" --slurpfile wi "$ADOPR_WI" \
    "$ADOPR_ENTRIES_JQ"'[($act[0] | pr_events($me)[].d), ($wi[0].items[]? | .changed)] | map(select(. != null) | epoch) | max // empty')"
  [[ "$newest" =~ ^[0-9]+$ ]] || return 0
  seen="$(cat "$ADOPR_CACHE/seen" 2>/dev/null)"
  [[ "$seen" =~ ^[0-9]+$ && "$seen" -ge "$newest" ]] && return 0
  printf %s "$newest" >"$ADOPR_CACHE/seen.$$" && command mv -f "$ADOPR_CACHE/seen.$$" "$ADOPR_CACHE/seen"
}

# $ADOPR_CACHE/badge: the tmux pill with what others did since the activity view was last opened (empty when nothing):
# ✎ comments, ✓ votes and status changes, # work items that mention or are assigned to you. Reads only the caches.
badge() {
  local act="$ADOPR_CACHE/activity.json" wi="$ADOPR_WI" seen now text
  [[ -r "$act" ]] || act=/dev/null
  [[ -r "$wi" ]] || wi=/dev/null
  now="$(date +%s)"
  seen="$(cat "$ADOPR_CACHE/seen" 2>/dev/null)"
  [[ "$seen" =~ ^[0-9]+$ ]] || seen=$((now - 86400))
  command mkdir -p -m 700 "$ADOPR_CACHE"
  text="$(jq -n -r --argjson seen "$seen" --arg me "$(current_user)" --slurpfile act "$act" --slurpfile wi "$wi" \
    "$ADOPR_ENTRIES_JQ"'
    ($act[0] // [] | pr_events($me) | map(select(.mine | not) | select((.d | epoch) > $seen))) as $pr
    | ([$wi[0].items[]? | select(.mine | not) | select(.mention or .assigned) | select(.changed != null)
        | select((.changed | epoch) > $seen)] | length) as $w
    | ([$pr[] | select(kind == "comment")] | length) as $c
    | ([$pr[] | select(kind != "comment")] | length) as $v
    | [(if $c > 0 then "✎ \($c)" else empty end), (if $v > 0 then "✓ \($v)" else empty end),
       (if $w > 0 then "# \($w)" else empty end)]
    | if length == 0 then "" else "#[fg=colour16,bg=colour179,bold] ADO " + join(" ") + " #[default]" end')" || return 1
  write_badge "$text"
}

write_badge() {
  command mkdir -p -m 700 "$ADOPR_CACHE"
  printf %s "$1" >"$ADOPR_CACHE/badge.$$" && command mv -f "$ADOPR_CACHE/badge.$$" "$ADOPR_CACHE/badge"
}

# Rows: PR ID, KIND (comment/vote/status), WHO, TEXT, AGE (shown), URL, PR:THREAD (hidden); every comment in the
# cached threads, newest first. Showing them marks them seen and clears the badge.
activity() {
  fetch_activity "$1" || return 1
  persist_activity 2>/dev/null
  jq -r --argjson now "$(date +%s)" --arg me "$(current_user)" --slurpfile prs "$ADOPR_PRS" --slurpfile wi "$ADOPR_WI" \
    "$ADOPR_ENTRIES_JQ"'
    def age: ($now - (.d[0:19] + "Z" | fromdateiso8601)) as $s
      | if $s < 3600 then "\($s / 60 | floor)m" elif $s < 86400 then "\($s / 3600 | floor)h" else "\($s / 86400 | floor)d" end;
    def paint($c): "\u001b[\($c)m" + . + "\u001b[0m";
    def short: gsub("\\s+"; " ") | if length > 100 then .[0:99] + "…" else . end;
    (pr_events($me)
      | map(. as $c | ($prs[0][] | select(.id == $c.pr) | .url) as $url
        | {d: .d, r: [(.pr | tostring | paint("1")), (kind | paint(if . == "comment" then "33" else "90" end)),
           (.who | paint(if $c.mine then "36" else "35" end)), (.x | short), (age | paint("90")),
           "\($url)?discussionId=\(.th)", "\(.pr):\(.th)"]}))
    + ([$wi[0].items[]? | . + {d: .changed} | . as $w
      | {d: .d, r: [("#\(.id)" | paint("1")), (.type | ascii_downcase | sub("user story"; "story") | paint("34")),
           (.by | paint(if $w.mine then "36" else "35" end)),
           ("[\(.state)] \(.title)" | short) + " · " + (if .mention then "@" elif .assigned then "assigned" else "touched" end),
           (age | paint("90")), .url, "wi:\(.id)"]}])
    + ([$wi[0].error // empty | . as $e
      | {d: ($now | todate), r: ["!" | paint("31"), ("error" | paint("31")), ("workitems" | paint("90")), ($e | short),
           ("now" | paint("90")), "", "err"]}])
    | sort_by(.d) | reverse | .[].r | @tsv' "$ADOPR_DIR/activity.json"
  local rc=$?
  { mark_seen && badge; } 2>/dev/null
  return $rc
}

# Every comment of thread $1 (PR:THREAD), from the cache
activity_preview() {
  [[ "$1" == wi:* ]] && { wi_preview "${1#wi:}"; return; }
  [[ "$1" == err ]] && { jq -r '.error // ""' "$ADOPR_WI"; return; }
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

# Saves the view, pattern mode, query and cursor position for the next start (the picker's exit binds)
save_state() {
  local view=prs pattern=
  [[ "$FZF_PROMPT" == Activity* ]] && view=activity
  [[ "$FZF_PROMPT" == *pattern* ]] && pattern=1
  printf 'view=%s\npattern=%s\npos=%s\nquery=%s\n' "$view" "$pattern" "${FZF_POS:-1}" "$FZF_QUERY" >"$ADOPR_STATE.$$" &&
    command mv -f "$ADOPR_STATE.$$" "$ADOPR_STATE"
}

open_url() {
  [[ -n "$1" ]] || return 0
  if command -v open >/dev/null 2>&1; then open "$1"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1
  else explorer.exe "$1"; fi
}

copy_url() {
  printf %s "$1" | { wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null || clip.exe; }
}

# Background refresh for the old tmux badge (no scheduler runs it since tmux/ado/ replaced it): fetches the PRs, threads and work items
# fresh into the caches and rewrites the badge. A sign-in or az failure leaves a grey "ADO !" until the next good poll.
poll() {
  local me
  command -v az >/dev/null 2>&1 || die "az is not installed"
  command -v jq >/dev/null 2>&1 || die "jq is not installed"
  command mkdir -p -m 700 "$ADOPR_CACHE"
  # A lock left by a killed poll expires after half an hour
  [[ -z "$(find "$ADOPR_CACHE/poll.lock" -maxdepth 0 -mmin +30 2>/dev/null)" ]] || command rmdir "$ADOPR_CACHE/poll.lock"
  command mkdir "$ADOPR_CACHE/poll.lock" 2>/dev/null || return 0
  ADOPR_DIR="$(mktemp -d)" || { command rmdir "$ADOPR_CACHE/poll.lock"; return 1; }
  FZFP_DIR="$ADOPR_DIR"
  export ADOPR_DIR FZFP_DIR
  trap 'command rm -rf -- "$ADOPR_DIR"; command rmdir "$ADOPR_CACHE/poll.lock"' EXIT
  me="$(current_user)"
  ADOPR_PRS="$ADOPR_CACHE/prs-active-${me//[^[:alnum:]]/_}.json"
  ADOPR_STATE="${ADOPR_PRS%.json}.state"
  export ADOPR_PRS ADOPR_STATE
  # fetch and fetch_activity `die`, which would end the whole script: run them in a subshell
  if [[ -n "$me" ]] && ( fetch && fetch_activity fresh ); then
    persist_activity && badge
  else
    write_badge '#[fg=colour244] ADO ! #[default]'
    return 1
  fi
}

case "$1" in
  badge) badge; exit ;;
  poll) poll; exit ;;
  rows) rows; exit ;;
  preview) preview "$2"; exit ;;
  fetch) fetch; exit ;;
  thread) fetch_threads "$2"; exit ;;
  wi) fetch_workitems "$2"; exit ;;
  widetail) fetch_wi_detail "$2"; exit ;;
  activity) activity "$2"; exit ;;
  apreview) activity_preview "$2"; exit ;;
  view) switch_view; exit ;;
  refresh) refresh; exit ;;
  pattern) pattern "$2" ;;
  save) save_state; exit ;;
  open) open_url "$2"; exit ;;
  copy) copy_url "$2"; exit ;;
esac

command -v az >/dev/null 2>&1 || die "az is not installed"
command -v fzf >/dev/null 2>&1 || die "fzf is not installed"
command -v jq >/dev/null 2>&1 || die "jq is not installed"
[[ "$1" == --all ]] && export ADOPR_ALL=1
force_activity=
[[ "$1" == --activity ]] && force_activity=1

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
ADOPR_STATE="${ADOPR_PRS%.json}.state"
export ADOPR_PRS ADOPR_STATE

# Open on the cached list at once and refresh it in the background unless it is under a minute old
stale=
if [[ -s "$ADOPR_PRS" ]]; then
  [[ -n "$(find "$ADOPR_PRS" -mmin -1)" ]] || stale=1
else
  fetch || exit 1
fi
rows >"$FZFP_DIR/rows"

title="My pull requests"
[[ -n "$ADOPR_ALL" ]] && title="My pull requests · all states"

# Reopen in the view, pattern mode, query and cursor position saved when the picker last closed
view=prs pattern= pos=1 query=
if [[ -r "$ADOPR_STATE" ]]; then
  while IFS='=' read -r key val; do
    case "$key" in
      view) view="$val" ;;
      pattern) pattern="$val" ;;
      query) query="$val" ;;
      pos) [[ "$val" =~ ^[0-9]+$ ]] && pos="$val" ;;
    esac
  done <"$ADOPR_STATE"
fi
[[ -n "$force_activity" ]] && view=activity

prompt="PRs> " label=" $title " preview="bash $self preview {1}" input="$FZFP_DIR/rows" opts=()
if [[ "$view" == activity ]] && bash "$self" activity >"$ADOPR_DIR/arows"; then
  prompt="Activity> " label=" My recent activity " preview="bash $self apreview {7}" input="$ADOPR_DIR/arows"
  # The PR list refreshes out of sight; Ctrl-A back to it reads the rows cache
  if [[ -n "$stale" ]]; then
    { bash "$self" fetch && bash "$self" rows >"$FZFP_DIR/rows.bg" && command mv -f "$FZFP_DIR/rows.bg" "$FZFP_DIR/rows"; } \
      >/dev/null 2>&1 &
    stale=
  fi
elif [[ -n "$pattern" ]]; then
  prompt="PRs pattern> " opts=(--disabled)
  bash "$fp" filter 2,3,4 "$query" <"$FZFP_DIR/rows" >"$ADOPR_DIR/frows"
  input="$ADOPR_DIR/frows"
fi
[[ -n "$stale" ]] &&
  opts+=(--bind="start:reload(bash $self fetch && bash $self rows | bash $fp pipe 2,3,4 || cat \"\$FZFP_DIR/rows\")")
[[ "$pos" -gt 1 ]] && opts+=(--bind="result:pos($pos)+unbind(result)")
save="execute-silent(bash $self save)"

fzf --ansi \
  --header $'[Enter] Open · [Ctrl-Y] Copy URL · [Ctrl-R] Refresh · [Ctrl-F] Pattern · [Ctrl-A] PRs/Activity' \
  --border rounded --border-label "$label" --preview-border rounded \
  --color 'border:8,label:6:bold,preview-border:8,preview-label:6:bold,info:8,separator:8,scrollbar:8' \
  --color 'prompt:6:bold,pointer:5,marker:5,hl:3:bold,hl+:3:bold,fg+:-1:bold,query:-1:bold' \
  --prompt "$prompt" --query "$query" --delimiter='\t' --with-nth=1,2,3,4,5 --no-sort \
  --bind='focus:transform-preview-label:printf " #%s " {1}' \
  --bind="enter:$save+execute-silent(bash $self open {6})+abort" \
  --bind="ctrl-y:$save+execute-silent(bash $self copy {6})+abort" \
  --bind="esc:$save+abort" --bind="ctrl-c:$save+abort" --bind="ctrl-g:$save+abort" --bind="ctrl-q:$save+abort" \
  --bind="ctrl-a:transform:bash $self view" \
  --bind="ctrl-f:transform:bash $self pattern toggle" \
  --bind="change:transform:bash $self pattern change" \
  --bind="ctrl-r:transform:bash $self refresh" \
  "${opts[@]}" \
  --preview="$preview" \
  --preview-window 'right,55%,wrap' --height 60% --layout reverse <"$input"
