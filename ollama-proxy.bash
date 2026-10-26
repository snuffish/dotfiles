#!/bin/bash

# Ollama SSH Tunnel Helpers
OLLAMA_PROXY_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"
OLLAMA_PORT="11436"
OLLAMA_TARGET="212.181.207.74"

ollama-tunnel-pid() {
  pgrep -f "ssh.*-L.*$OLLAMA_PORT.*$OLLAMA_TARGET" 2>/dev/null || lsof -nP -iTCP:"$OLLAMA_PORT" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $2}' | head -n1
}

ollama-tunnel-start() {
  local pid
  pid=$(ollama-tunnel-pid)
  if [ -n "$pid" ]; then
    echo "Ollama tunnel is already running (PID: $pid, port $OLLAMA_PORT)."
    return 0
  fi

  echo "Starting SSH tunnel to $OLLAMA_TARGET on port $OLLAMA_PORT..."
  ssh -f -N -L "$OLLAMA_PORT:127.0.0.1:11434" \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    "$OLLAMA_TARGET"

  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: Failed to start SSH tunnel (exit code $exit_code)."
    return $exit_code
  fi

  local waited=0
  while [ $waited -lt 6 ]; do
    pid=$(ollama-tunnel-pid)
    if [ -n "$pid" ]; then
      echo "Ollama tunnel connected (PID: $pid)."
      return 0
    fi
    sleep 0.5
    waited=$((waited + 1))
  done

  echo "Warning: Ollama tunnel started, but port $OLLAMA_PORT is not yet listening."
}

ollama-tunnel-stop() {
  local pid
  pid=$(ollama-tunnel-pid)
  if [ -n "$pid" ]; then
    echo "Stopping Ollama tunnel (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    echo "Ollama tunnel stopped."
  else
    echo "Ollama tunnel is not running."
  fi
}

ollama-status() {
  local tunnel_pid
  tunnel_pid=$(ollama-tunnel-pid)

  echo "=== Ollama SSH Tunnel Status ==="
  if [ -n "$tunnel_pid" ]; then
    echo "Tunnel:  RUNNING (PID: $tunnel_pid, port $OLLAMA_PORT -> $OLLAMA_TARGET)"
  else
    echo "Tunnel:  STOPPED"
  fi
  echo "================================"
}

ollama-toggle() {
  if ollama-tunnel-pid >/dev/null 2>&1 || [ -n "$(ollama-tunnel-pid)" ]; then
    ollama-tunnel-stop
  else
    ollama-tunnel-start
  fi
}

ollama-menu() {
  local action="$1"

  if [ -z "$action" ]; then
    local tunnel_pid
    tunnel_pid=$(ollama-tunnel-pid)
    local overall_status="OFF"
    if [ -n "$tunnel_pid" ]; then
      overall_status="ACTIVE (Tunnel Running)"
    fi

    local script_file="${OLLAMA_PROXY_SCRIPT:-${BASH_SOURCE[0]:-$0}}"

    if command -v fzf >/dev/null 2>&1; then
      local choice
      choice=$(printf "%-14s %s\n" \
        "toggle"        "Toggle Ollama SSH tunnel" \
        "on"            "Start Ollama SSH tunnel" \
        "off"           "Stop Ollama SSH tunnel" \
        "status"        "Show detailed status" \
        | fzf --height 40% --layout reverse \
              --header "Ollama Tunnel (Status: $overall_status)" \
              --preview "bash -c '. \"$script_file\" && ollama-status'" \
              --preview-window "right:50%:wrap" | awk '{print $1}')
      [ -z "$choice" ] && return 0
      action="$choice"
    else
      echo "Ollama Tunnel (Status: $overall_status)"
      local PS3="Select an option: "
      select opt in "toggle" "on" "off" "status" "quit"; do
        case "$opt" in
          quit) return 0 ;;
          toggle|on|off|status) action="$opt"; break ;;
          *) echo "Invalid option: $REPLY" ;;
        esac
      done
    fi
  fi

  case "$action" in
    on|start)                   ollama-tunnel-start ;;
    off|stop)                   ollama-tunnel-stop ;;
    toggle)                     ollama-toggle ;;
    status)                     ollama-status ;;
    *) echo "Unknown option: $action. Available: toggle, on, off, status" ;;
  esac
}

ollama-proxy() {
  ollama-menu "$@"
}

# If executed directly rather than sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ollama-proxy "$@"
fi
