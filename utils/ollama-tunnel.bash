#!/bin/bash
# ollama-tunnel: SSH tunnel from this machine to the Ollama host (Mac side).
# On the Ollama host itself it is a no-op that says so.
# Menu rows are typed verbs (`ollama-tunnel <verb>`). bash 3.2 and zsh safe.

: "${OLLAMA_TARGET:=snuffish-pc}" # Host alias in ~/.ssh/config
: "${OLLAMA_PORT:=11436}"

_otn_is_local() {
  if type _ofz_is_local >/dev/null 2>&1; then
    _ofz_is_local
    return
  fi
  command -v systemctl >/dev/null 2>&1 && systemctl cat ollama.service >/dev/null 2>&1
}

_otn_pid() {
  command pgrep -f "ssh.*-L.*$OLLAMA_PORT.*$OLLAMA_TARGET" 2>/dev/null ||
    command lsof -nP -iTCP:"$OLLAMA_PORT" -sTCP:LISTEN 2>/dev/null | command awk 'NR>1 {print $2}' | command head -n1
}

_otn_start() {
  local pid rc waited=0
  pid=$(_otn_pid)
  if [ -n "$pid" ]; then
    echo "Ollama tunnel is already running (PID: $pid, port $OLLAMA_PORT)."
    return 0
  fi

  echo "Starting SSH tunnel to $OLLAMA_TARGET on port $OLLAMA_PORT..."
  command ssh -f -N -L "$OLLAMA_PORT:127.0.0.1:11434" \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    "$OLLAMA_TARGET"
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "Error: Failed to start SSH tunnel (exit code $rc)." >&2
    return $rc
  fi

  while [ $waited -lt 6 ]; do
    pid=$(_otn_pid)
    if [ -n "$pid" ]; then
      echo "Ollama tunnel connected (PID: $pid)."
      return 0
    fi
    sleep 0.5
    waited=$((waited + 1))
  done
  echo "Warning: Ollama tunnel started, but port $OLLAMA_PORT is not yet listening." >&2
}

_otn_stop() {
  local pid
  pid=$(_otn_pid)
  if [ -n "$pid" ]; then
    echo "Stopping Ollama tunnel (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    echo "Ollama tunnel stopped."
  else
    echo "Ollama tunnel is not running."
  fi
}

_otn_status() {
  local pid
  pid=$(_otn_pid)
  if [ -n "$pid" ]; then
    echo "Tunnel: RUNNING (PID: $pid, port $OLLAMA_PORT -> $OLLAMA_TARGET)"
  else
    echo "Tunnel: STOPPED"
  fi
}

_otn_toggle() {
  if [ -n "$(_otn_pid)" ]; then _otn_stop; else _otn_start; fi
}

_otn_rows() {
  printf '%-10s %s\n' \
    toggle "Toggle Ollama SSH tunnel" \
    on "Start Ollama SSH tunnel" \
    off "Stop Ollama SSH tunnel" \
    status "Show tunnel status"
}

_otn_usage() {
  echo "Usage: ollama-tunnel [on|off|toggle|status]   (no verb = menu)"
}

_otn_menu() {
  local choice header opts=() line
  if ! { [ -t 0 ] && [ -t 1 ]; }; then
    _otn_usage >&2
    return 1
  fi
  if [ -n "$(_otn_pid)" ]; then header="Ollama Tunnel (Status: ACTIVE)"; else header="Ollama Tunnel (Status: OFF)"; fi
  if command -v fzf >/dev/null 2>&1; then
    choice=$(_otn_rows | fzf --height 40% --layout reverse \
      --header "$header" \
      --preview "echo '$(_otn_status)'" \
      --preview-window "right:50%:wrap" | command awk '{print $1}')
  else
    echo "$header" >&2
    while IFS= read -r line; do
      opts+=("${line%% *}")
    done <<EOF
$(_otn_rows)
EOF
    local PS3="Select an option: " opt
    select opt in "${opts[@]}" quit; do
      case "$opt" in
        quit) break ;;
        "") echo "Invalid option: $REPLY" >&2 ;;
        *) choice=$opt; break ;;
      esac
    done
  fi
  [ -n "$choice" ] || return 0
  ollama-tunnel "$choice"
}

ollama-tunnel() {
  local verb=${1:-}
  case "$verb" in
    help | -h | --help) _otn_usage; return 0 ;;
  esac
  if _otn_is_local; then
    echo "ollama-tunnel: not needed here: ollama runs locally" >&2
    return 1
  fi
  case "$verb" in
    "") _otn_menu ;;
    on | start) _otn_start ;;
    off | stop) _otn_stop ;;
    toggle) _otn_toggle ;;
    status) _otn_status ;;
    *)
      echo "Unknown verb: $verb" >&2
      _otn_usage >&2
      return 1
      ;;
  esac
}
