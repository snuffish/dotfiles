#!/bin/bash

# SOCKS Proxy & SSH Tunnel Helpers
IVO_PROXY_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"
PROXY_INTERFACE="Wi-Fi"
PROXY_HOST="127.0.0.1"
PROXY_PORT="9090"
SSH_TUNNEL_KEY="$HOME/.ssh/gr_rsa"
SSH_TUNNEL_TARGET="christoffer.engman@priis-docker01.gr.internal"

ivo-tunnel-pid() {
  pgrep -f "ssh.*-D.*$PROXY_PORT.*priis-docker01" 2>/dev/null || lsof -nP -iTCP:"$PROXY_PORT" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $2}' | head -n1
}

ivo-tunnel-start() {
  local pid
  pid=$(ivo-tunnel-pid)
  if [ -n "$pid" ]; then
    echo "SSH tunnel is already running (PID: $pid, port $PROXY_PORT)."
    return 0
  fi

  echo "Starting SSH tunnel to $SSH_TUNNEL_TARGET on port $PROXY_PORT..."
  ssh -f -N -D "$PROXY_PORT" -i "$SSH_TUNNEL_KEY" \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    "$SSH_TUNNEL_TARGET"

  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: Failed to start SSH tunnel (exit code $exit_code)."
    return $exit_code
  fi

  local waited=0
  while [ $waited -lt 6 ]; do
    pid=$(ivo-tunnel-pid)
    if [ -n "$pid" ]; then
      echo "SSH tunnel connected (PID: $pid)."
      return 0
    fi
    sleep 0.5
    waited=$((waited + 1))
  done

  echo "Warning: SSH tunnel started, but port $PROXY_PORT is not yet listening."
}

ivo-tunnel-stop() {
  local pid
  pid=$(ivo-tunnel-pid)
  if [ -n "$pid" ]; then
    echo "Stopping SSH tunnel (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    echo "SSH tunnel stopped."
  else
    echo "SSH tunnel is not running."
  fi
}

proxy-on() {
  if ! ivo-tunnel-start; then
    echo "Aborting: Wi-Fi proxy not enabled because SSH tunnel failed to start."
    return 1
  fi

  networksetup -setsocksfirewallproxy "$PROXY_INTERFACE" "$PROXY_HOST" "$PROXY_PORT"
  networksetup -setsocksfirewallproxystate "$PROXY_INTERFACE" on
  echo "SOCKS proxy enabled on $PROXY_INTERFACE ($PROXY_HOST:$PROXY_PORT)"
}

proxy-off() {
  networksetup -setsocksfirewallproxystate "$PROXY_INTERFACE" off
  echo "SOCKS proxy disabled on $PROXY_INTERFACE"
  ivo-tunnel-stop
}

proxy-status() {
  local tunnel_pid
  tunnel_pid=$(ivo-tunnel-pid)
  local proxy_state
  proxy_state=$(networksetup -getsocksfirewallproxy "$PROXY_INTERFACE" 2>/dev/null | awk '/^Enabled: / {print $2}')

  echo "=== IVO Proxy & SSH Tunnel Status ==="
  if [ -n "$tunnel_pid" ]; then
    echo "SSH Tunnel:  RUNNING (PID: $tunnel_pid, port $PROXY_PORT -> $SSH_TUNNEL_TARGET)"
  else
    echo "SSH Tunnel:  STOPPED"
  fi

  if [ "$proxy_state" = "Yes" ]; then
    echo "macOS Proxy: ENABLED on $PROXY_INTERFACE ($PROXY_HOST:$PROXY_PORT)"
  else
    echo "macOS Proxy: DISABLED on $PROXY_INTERFACE"
  fi
  echo "====================================="
}

proxy-toggle() {
  local tunnel_pid
  tunnel_pid=$(ivo-tunnel-pid)
  local proxy_state
  proxy_state=$(networksetup -getsocksfirewallproxy "$PROXY_INTERFACE" 2>/dev/null | awk '/^Enabled: / {print $2}')

  if [ -n "$tunnel_pid" ] || [ "$proxy_state" = "Yes" ]; then
    proxy-off
  else
    proxy-on
  fi
}

proxy-menu() {
  local action="$1"

  if [ -z "$action" ]; then
    local tunnel_pid
    tunnel_pid=$(ivo-tunnel-pid)
    local proxy_state
    proxy_state=$(networksetup -getsocksfirewallproxy "$PROXY_INTERFACE" 2>/dev/null | awk '/^Enabled: / {print $2}')

    local overall_status="OFF"
    if [ -n "$tunnel_pid" ] && [ "$proxy_state" = "Yes" ]; then
      overall_status="ACTIVE (Tunnel + Proxy)"
    elif [ -n "$tunnel_pid" ]; then
      overall_status="Tunnel only (Proxy OFF)"
    elif [ "$proxy_state" = "Yes" ]; then
      overall_status="Proxy only (Tunnel OFF!)"
    fi

    local script_file="${IVO_PROXY_SCRIPT:-${BASH_SOURCE[0]:-$0}}"

    if command -v fzf >/dev/null 2>&1; then
      local choice
      choice=$(printf "%-14s %s\n" \
        "toggle"        "Toggle SSH tunnel & Wi-Fi proxy" \
        "on"            "Start SSH tunnel + enable Wi-Fi proxy" \
        "off"           "Disable Wi-Fi proxy + stop SSH tunnel" \
        "status"        "Show detailed status of tunnel and proxy" \
        "tunnel-start"  "Start SSH tunnel only" \
        "tunnel-stop"   "Stop SSH tunnel only" \
        | fzf --height 45% --layout reverse \
              --header "IVO Proxy & Tunnel (Status: $overall_status)" \
              --preview "bash -c '. \"$script_file\" && proxy-status'" \
              --preview-window "right:50%:wrap" | awk '{print $1}')
      [ -z "$choice" ] && return 0
      action="$choice"
    else
      echo "IVO Proxy & Tunnel (Status: $overall_status)"
      local PS3="Select an option: "
      select opt in "toggle" "on" "off" "status" "tunnel-start" "tunnel-stop" "quit"; do
        case "$opt" in
          quit) return 0 ;;
          toggle|on|off|status|tunnel-start|tunnel-stop) action="$opt"; break ;;
          *) echo "Invalid option: $REPLY" ;;
        esac
      done
    fi
  fi

  case "$action" in
    on|start)                   proxy-on ;;
    off|stop)                   proxy-off ;;
    toggle)                     proxy-toggle ;;
    status)                     proxy-status ;;
    tunnel-start|tunnel-on)     ivo-tunnel-start ;;
    tunnel-stop|tunnel-off)     ivo-tunnel-stop ;;
    *) echo "Unknown option: $action. Available: toggle, on, off, status, tunnel-start, tunnel-stop" ;;
  esac
}

ivo-proxy() {
  proxy-menu "$@"
}

alias ivo-proxy="proxy-menu"
