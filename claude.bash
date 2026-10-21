#!/bin/bash

# claude-mem sync between devices: https://github.com/snuffish/cm-sync
function cm-sync() {
  local engine="$HOME/Projects/cm-sync/cm_sync.py"
  if [[ ! -f "$engine" ]]; then
    echo "cm-sync is not installed: git clone git@github.com:snuffish/cm-sync.git ~/Projects/cm-sync" >&2
    return 1
  fi
  CM_SYNC_REPO="${CM_SYNC_REPO:-$HOME/.terminal/memory}" \
  CM_SYNC_REMOTE="${CM_SYNC_REMOTE:-git@github.com:snuffish/claude-memory.git}" \
    python3 -I "$engine" "$@"
}

# Lint the skills registry and check ~/.claude/skills against it; --apply fixes the links
function sync-skills() {
  python3 -I "$HOME/.terminal/skills/sync-skills/sync_skills.py" "$@"
}

# Pick one of this directory's Claude Code sessions with fzf and resume it; extra args go to claude
function claude-resume() {
  local dir="$HOME/.claude/projects/${PWD//[^[:alnum:]]/-}"
  local pick
  if [[ ! -d "$dir" ]]; then
    echo "No Claude sessions for $PWD" >&2
    return 1
  fi
  pick="$(
    for f in "$dir"/*.jsonl; do
      jq -rn --arg f "$f" '
        [inputs] as $l
        | ($l | map(select(.type == "user" and (.isMeta | not))
                    | .message.content | if type == "array" then map(.text? // empty) | join(" ") else . end
                    | select(type == "string" and length > 0 and (startswith("<") | not)))
              | first // "") as $prompt
        | ([$l[] | .customTitle // empty] | last) // ([$l[] | .aiTitle // empty] | last) // $prompt
        | select(. != "") as $title
        | ([$l[] | .timestamp // empty] | last // "") as $ts
        | [if $ts == "" then "" else $ts[0:19] + "Z" | fromdate | localtime | strftime("%Y-%m-%d %H:%M") end,
($f | split("/") | last | rtrimstr(".jsonl")), ($title | gsub("\\s+"; " ") | .[0:100]), $f] | @tsv
      ' "$f"
    done | sort -r | fzf --header 'Select session to resume (ctrl-s copies its id):' --delimiter='\t' --with-nth=1,2,3 --tiebreak=index \
      --bind="ctrl-s:execute-silent(printf %s {2} | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null))+abort" \
      --preview="jq -r 'select(.type == \"user\" or .type == \"assistant\") | .message.content | if type == \"array\" then map(.text? // empty) | join(\" \") else . end | select(type == \"string\" and length > 0) | \"• \" + .[0:400]' {4} | tail -n 40" \
      --preview-window wrap --height 50% --layout reverse
  )" || return
  claude --resume "$(cut -f2 <<< "$pick")" "$@"
}

# Open the claude-mem dashboard in the browser
function cm() {
  local url
  url="$(cm-sync url)" || return 1
  case "$ENV_PROFILE" in
    Mac) command open "$url" ;;
    Windows) explorer.exe "$url" ;;
    *) xdg-open "$url" >/dev/null 2>&1 & ;;
  esac
}

alias cr="claude-resume"
