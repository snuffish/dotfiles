#!/usr/bin/env bash
# Shared fzf session picker for Claude Code, Antigravity, and Unified Agent sessions

run_agent_session_picker() {
  local driver="" title="" header="" scope="here" prompt="" extra_binds=() expect="ctrl-o,ctrl-f,ctrl-x"
  local out key pick id cwd

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --driver) driver="$2"; shift 2 ;;
      --title) title="$2"; shift 2 ;;
      --header) header="$2"; shift 2 ;;
      --scope) scope="$2"; shift 2 ;;
      --prompt) prompt="$2"; shift 2 ;;
      --bind) extra_binds+=("--bind=$2"); shift 2 ;;
      # Keys beyond the defaults that end the picker and come back as line 1, for the caller to act on
      --expect) expect+=",$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -n "$driver" ]] || { echo "run_agent_session_picker: --driver required" >&2; return 1; }
  [[ -n "$title" ]] || title="Session Picker"
  [[ -n "$prompt" ]] || {
    if [[ "$scope" == "all" ]]; then prompt="All> "; else prompt="This dir> "; fi
  }

  local header_args=()
  if [[ -n "$header" ]]; then
    local cols="${COLUMNS:-$(tput cols 2>/dev/null || echo 160)}"
    local max_len=$(( cols * 45 / 100 - 4 ))
    [[ $max_len -lt 35 ]] && max_len=35
    local wrapped_header
    wrapped_header="$(python3 -I -c '
import sys
max_len = int(sys.argv[1])
header = sys.argv[2]
out_lines = []
for line in header.split("\n"):
    if len(line) <= max_len:
        out_lines.append(line)
        continue
    parts = [p.strip() for p in line.split(" · ") if p.strip()]
    curr = ""
    for p in parts:
        if not curr:
            curr = p
        elif len(curr) + len(p) + 3 <= max_len:
            curr += " · " + p
        else:
            out_lines.append(curr)
            curr = p
    if curr:
        out_lines.append(curr)
print("\n".join(out_lines))
' "$max_len" "$header" 2>/dev/null || printf "%s" "$header")"
    header_args=(--header "$wrapped_header")
  fi

  out="$(
    bash "$driver" list "$scope" | fzf --ansi \
      "${header_args[@]}" \
      --border rounded --border-label " $title " --preview-border rounded \
      --color 'border:8,label:6:bold,preview-border:8,preview-label:6:bold,info:8,separator:8,scrollbar:8' \
      --color 'prompt:6:bold,pointer:5,marker:5,hl:3:bold,hl+:3:bold,fg+:-1:bold,query:-1:bold' \
      --prompt "$prompt" --delimiter='\t' --with-nth=1,2,3,4 --no-sort --expect="$expect" \
      --bind='focus:transform-preview-label:printf " %s " {4}' \
      --bind="ctrl-t:transform:bash $driver key scope" \
      --bind="ctrl-g:transform:bash $driver key mode" \
      --bind="change:transform:bash $driver key change" \
      --bind="ctrl-s:execute-silent(printf %s {5} | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null))+abort" \
      "${extra_binds[@]}" \
      --preview="bash $driver preview {6}" \
      --preview-window 'right,55%,wrap,follow' --height 60% --layout reverse
  )" || return 1

  printf "%s\n" "$out"
}
