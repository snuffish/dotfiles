#!/bin/bash

ag() {
  antigravity-ide "${@:-.}"
}

alias antigravity-editor="antigravity-ide"


_agy_normalize_args() {
  _agy_normalized=()
  while [[ $# -gt 0 ]]; do
    local arg="$1"
    arg="${arg#\"}"
    arg="${arg%\"}"
    arg="${arg#\'}"
    arg="${arg%\'}"

    case "$arg" in
      /resume|resume|--resume|-r)
        if [[ -n "$2" && "$2" != -* ]]; then
          _agy_normalized+=("--conversation" "$2")
          shift 2
          continue
        else
          _agy_normalized+=("--continue")
          shift
          continue
        fi
        ;;
      *)
        _agy_normalized+=("$1")
        shift
        ;;
    esac
  done
}

agy() {
  local _agy_normalized=()
  _agy_normalize_args "$@"
  set -- "${_agy_normalized[@]}"

  # If running non-interactively, pass through directly
  if [[ ! -t 0 ]]; then
    command agy "$@"
    return $?
  fi

  # Pass through common subcommands and help flags without prompting
  case "$1" in
    agent|agents|changelog|help|install|mcp|mic-serve|models|plugin|plugins|update|--help|-h|--version|-v)
      command agy "$@"
      return $?
      ;;
  esac

  # If user already passed permission or mode flags, pass through directly
  for arg in "$@"; do
    if [[ "$arg" == "--dangerously-skip-permissions" || "$arg" == "--mode" ]]; then
      command agy "$@"
      return $?
    fi
  done

  local response
  printf "Auto-approve all actions for this session? [y/N]: "
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    command agy --mode accept-edits --dangerously-skip-permissions "$@"
  else
    command agy "$@"
  fi
}

agyy() {
  local _agy_normalized=()
  _agy_normalize_args "$@"
  echo "⚡ Launching in auto-approval mode..."
  command agy --mode accept-edits --dangerously-skip-permissions "${_agy_normalized[@]}"
}

_agy_open_pid() {
  local lock="$HOME/.gemini/antigravity-cli/presence/$1.lock" pid
  [[ -f "$lock" ]] || return 1
  pid="$(lsof -t "$lock" 2>/dev/null | head -n1)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && { echo "$pid"; return 0; }
  return 1
}

# Pick an Antigravity session with fzf and resume it; extra args go to agy
antigravity-resume() {
  local picker="$HOME/.terminal/utils/agent-session-picker.sh"
  local driver="$HOME/.terminal/antigravity/sessions.sh"
  local focus_script="$HOME/.terminal/utils/agent-focus.sh"
  local fork_script="$HOME/.terminal/utils/agent-session-fork.py"
  local scope=here prompt='This dir> ' out key pick id cwd pid

  local db="$HOME/.gemini/antigravity-cli/conversation_summaries.db"
  if [[ -f "$db" ]]; then
    if ! sqlite3 -batch -noheader "file:$db?mode=ro" -cmd ".timeout 2000" \
      "SELECT 1 FROM conversation_summaries WHERE workspace_uris LIKE '%$PWD%' LIMIT 1;" 2>/dev/null | grep -q 1; then
      scope=all
      prompt='All> '
    fi
  fi

  out="$(
    source "$picker"
    run_agent_session_picker \
      --driver "$driver" \
      --title "Resume Antigravity session" \
      --header $'[Enter] Resume · [Ctrl-F] Fork · [Ctrl-S] Copy ID\n[Ctrl-T] This dir/All · [Ctrl-G] Titles/Text · [Ctrl-U] Subagents' \
      --scope "$scope" \
      --prompt "$prompt" \
      --bind "ctrl-u:transform:bash $driver key subagent"
  )" || return

  key="$(head -n 1 <<< "$out")"
  pick="$(sed -n 2p <<< "$out")"
  id="$(cut -f5 <<< "$pick")"
  cwd="$(cut -f7 <<< "$pick")"
  [[ -n "$id" ]] || return 0

  if [[ "$key" == "ctrl-f" ]]; then
    echo "Forking Antigravity session ${id:0:8}..." >&2
    local new_id
    new_id="$(python3 "$fork_script" --from agy --to agy --id "$id" --cwd "${cwd:-$PWD}")" || return 1
    (cd "${cwd:-$PWD}" && agy --conversation "$new_id" "$@")
    return $?
  fi

  if pid="$(_agy_open_pid "$id")"; then
    echo "Session ${id:0:8} is already open in agy (pid $pid)." >&2
    echo "Focusing active terminal window/pane..." >&2
    bash "$focus_script" "$pid"
    return 0
  fi

  (cd "${cwd:-$PWD}" && agy --conversation "$id" "$@")
}

agry() {
  antigravity-resume --mode accept-edits --dangerously-skip-permissions "$@"
}

alias agr="antigravity-resume"

# Pick from both Claude Code and Antigravity sessions in a unified picker
agent-resume() {
  local picker="$HOME/.terminal/utils/agent-session-picker.sh"
  local driver="$HOME/.terminal/utils/unified-sessions.sh"
  local focus_script="$HOME/.terminal/utils/agent-focus.sh"
  local fork_script="$HOME/.terminal/utils/agent-session-fork.py"
  local scope=here prompt='This dir> ' out key pick id cwd agent pid

  out="$(
    source "$picker"
    run_agent_session_picker \
      --driver "$driver" \
      --title "Resume Agent session (Claude / Antigravity)" \
      --header $'[Enter] Resume · [Ctrl-F] Fork · [Ctrl-X] Cross-fork · [Ctrl-L] Tail · [Ctrl-S] Copy ID\n[Ctrl-T] This dir/All · [Ctrl-G] Titles/Text · [Ctrl-A] All/Claude/Agy' \
      --scope "$scope" \
      --prompt "$prompt" \
      --expect ctrl-l \
      --bind "ctrl-a:transform:bash $driver key agent"
  )" || return

  key="$(head -n 1 <<< "$out")"
  pick="$(sed -n 2p <<< "$out")"
  id="$(cut -f5 <<< "$pick")"
  cwd="$(cut -f7 <<< "$pick")"
  agent="$(cut -f8 <<< "$pick")"
  [[ -n "$id" ]] || return 0

  case "$key" in
    ctrl-l)
      # Follow the transcript live (claude-tail reads both agents' formats); ctrl-c stops it
      claude-tail "$(cut -f6 <<< "$pick")"
      ;;
    ctrl-x)
      if [[ "$agent" == "claude" ]]; then
        echo "Forking Claude session ${id:0:8} -> Antigravity..." >&2
        local new_id
        new_id="$(python3 "$fork_script" --from claude --to agy --id "$id" --cwd "${cwd:-$PWD}")" || return 1
        (cd "${cwd:-$PWD}" && agy --conversation "$new_id" "$@")
      else
        echo "Forking Antigravity session ${id:0:8} -> Claude..." >&2
        local new_id
        new_id="$(python3 "$fork_script" --from agy --to claude --id "$id" --cwd "${cwd:-$PWD}")" || return 1
        (cd "${cwd:-$PWD}" && claude --resume "$new_id" "$@")
      fi
      ;;
    ctrl-f)
      if [[ "$agent" == "claude" ]]; then
        (cd "${cwd:-$PWD}" && claude --resume "$id" --fork-session "$@")
      else
        echo "Forking Antigravity session ${id:0:8}..." >&2
        local new_id
        new_id="$(python3 "$fork_script" --from agy --to agy --id "$id" --cwd "${cwd:-$PWD}")" || return 1
        (cd "${cwd:-$PWD}" && agy --conversation "$new_id" "$@")
      fi
      ;;
    *)
      if [[ "$agent" == "antigravity" ]]; then
        if pid="$(_agy_open_pid "$id")"; then
          echo "Session ${id:0:8} is already open in agy (pid $pid)." >&2
          echo "Focusing active terminal window/pane..." >&2
          bash "$focus_script" "$pid"
          return 0
        fi
        (cd "${cwd:-$PWD}" && agy --conversation "$id" "$@")
      else
        if [[ -z "$key" ]] && pid="$(_claude_open_pid "$id" 2>/dev/null)"; then
          echo "Session ${id:0:8} is open in claude (pid $pid): resuming a fork of it" >&2
          bash "$focus_script" "$pid"
          key=fork
        fi
        (cd "${cwd:-$PWD}" && claude --resume "$id" ${key:+--fork-session} "$@")
      fi
      ;;
  esac
}

ary() {
  agent-resume --mode accept-edits --dangerously-skip-permissions "$@"
}

alias ar="agent-resume"


agp() {
  echo "[AG_USER_DIR] $AG_USER_DIR"
  (
    cd "$AG_USER_DIR" || exit
    git add . && echo "[*] Adding files"
    echo "[*] Commiting files"
    git commit -m "push" || echo "No changes to commit"
    echo "[*] Pushing files"
    git push
  )
}

agpull() {
  echo "[AG_USER_DIR] $AG_USER_DIR"
  echo "[*] Pulling"
  git -C "$AG_USER_DIR" pull
}

alias tf="tail -f"
findPort() {
  lsof -i :$1
}
#alias port="findPort"

alias killPort="npx kill-port"

process() {
  if [[ -z "$1" ]]; then
    echo "Usage: process <process_name>"
    return 1
  fi
  sudo ps aux | grep -i "$1"
}

alias header="curl -I -L"
alias portListener="sudo netstat -tolpn"

alias tsd="tsx watch"

if ! declare -f sync-skills >/dev/null 2>&1; then
  alias sync-skills='python3 -I "$HOME/.terminal/skills/sync-skills/sync_skills.py"'
fi
