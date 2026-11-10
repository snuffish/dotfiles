#!/bin/bash
# ollama-fzf: fzf manager for the Ollama service and its models.
# Local when ollama.service exists on this host, else over ssh to $OLLAMA_TARGET.
# Menus are facades: every row is a typed verb (`ollama-fzf <verb>`).
# bash 3.2 and zsh safe: no mapfile, assoc arrays, ${x,,}, read -p.

: "${OLLAMA_TARGET:=snuffish-pc}" # Host alias in ~/.ssh/config
: "${OLLAMA_PORT:=11436}"

# --- environment -------------------------------------------------------------

# Prints 1 when ollama.service runs on this host, else 0. OLLAMA_FZF_REMOTE=1/0 overrides.
_ofz_detect() {
  case "${OLLAMA_FZF_REMOTE:-}" in
    1) echo 0; return ;;
    0) echo 1; return ;;
  esac
  if command -v systemctl >/dev/null 2>&1 && systemctl cat ollama.service >/dev/null 2>&1; then
    echo 1
  else
    echo 0
  fi
}

_ofz_is_local() {
  [ -n "${_OFZ_LOCAL:-}" ] || _OFZ_LOCAL=$(_ofz_detect)
  [ "$_OFZ_LOCAL" = 1 ]
}

# Run a command where Ollama lives; remote gets a tty for polkit/prompts.
_ofz_run() {
  if _ofz_is_local; then
    "$@"
  else
    command ssh -t -- "$OLLAMA_TARGET" "$@"
  fi
}

# Same, for captured output: no tty, never prompts, fails fast.
_ofz_capture() {
  if _ofz_is_local; then
    "$@"
  else
    command ssh -T -o BatchMode=yes -o ConnectTimeout=5 -- "$OLLAMA_TARGET" "$@"
  fi
}

_ofz_valid_model() {
  case "$1" in
    "" | -*) return 1 ;;
  esac
  printf '%s' "$1" | command grep -Eq '^[A-Za-z0-9._:/@-]+$'
}

_ofz_host() {
  if _ofz_is_local; then echo "local"; else echo "$OLLAMA_TARGET"; fi
}

_ofz_tunnel_up() {
  type _otn_pid >/dev/null 2>&1 || return 1
  [ -n "$(_otn_pid 2>/dev/null)" ]
}

# --- verbs -------------------------------------------------------------------

# One row per verb: "<verb>\t<description>". Used by help, menu and select.
_ofz_rows() {
  printf '%-10s %s\n' \
    status "Show service and loaded models" \
    start "Start the service" \
    stop "Stop the service" \
    restart "Restart the service" \
    toggle "Start if stopped, stop if running" \
    enable "Enable at boot" \
    disable "Disable at boot" \
    logs "Follow journal (logs N = last N lines)" \
    unload "Unload a loaded model" \
    list "List installed models" \
    pull "Download a model" \
    rm "Remove a model (asks y/N)"
  if ! _ofz_is_local; then
    printf '%-10s %s\n' tunnel "Toggle SSH tunnel (ollama-tunnel)"
  fi
}

_ofz_usage() {
  echo "Usage: ollama-fzf [verb] [arg]   (no verb = menu)"
  _ofz_rows | command sed 's/^/  /'
}

# Writes the snapshot to $1 and sets _OFZ_ACTIVE, _OFZ_ENABLED, _OFZ_LOADED.
_ofz_snapshot() {
  local out=$1 ps_out
  _OFZ_ACTIVE="unreachable"
  _OFZ_ENABLED="?"
  _OFZ_LOADED=0
  if ! _ofz_capture true >/dev/null 2>&1; then
    echo "Host $(_ofz_host): unreachable" >"$out"
    return 0
  fi
  _OFZ_ACTIVE=$(_ofz_capture systemctl is-active ollama 2>/dev/null)
  _OFZ_ENABLED=$(_ofz_capture systemctl is-enabled ollama 2>/dev/null)
  ps_out=$(_ofz_capture ollama ps 2>/dev/null)
  _OFZ_LOADED=$(printf '%s\n' "$ps_out" | command awk 'NR>1 && NF {n++} END {print n+0}')
  {
    echo "Host:    $(_ofz_host)"
    echo "Active:  $_OFZ_ACTIVE"
    echo "Enabled: $_OFZ_ENABLED"
    if ! _ofz_is_local; then
      if _ofz_tunnel_up; then echo "Tunnel:  up (port $OLLAMA_PORT)"; else echo "Tunnel:  down"; fi
    fi
    echo
    _ofz_capture systemctl status ollama --no-pager -n 5 2>/dev/null
    echo
    echo "Loaded models:"
    if [ -n "$ps_out" ]; then printf '%s\n' "$ps_out"; else echo "  (server down or none)"; fi
  } >"$out"
}

_ofz_status() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/ofz.XXXXXX") || return 1
  _ofz_snapshot "$tmp"
  command cat "$tmp"
  command rm -f "$tmp"
}

_ofz_is_active() { [ "$(_ofz_capture systemctl is-active ollama 2>/dev/null)" = active ]; }
_ofz_is_enabled() { [ "$(_ofz_capture systemctl is-enabled ollama 2>/dev/null)" = enabled ]; }

_ofz_svc() {
  local verb=$1
  case "$verb" in
    start) if _ofz_is_active; then echo "Ollama is already running."; return 0; fi ;;
    stop) if ! _ofz_is_active; then echo "Ollama is not running."; return 0; fi ;;
    enable) if _ofz_is_enabled; then echo "Ollama is already enabled."; return 0; fi ;;
    disable) if ! _ofz_is_enabled; then echo "Ollama is already disabled."; return 0; fi ;;
  esac
  if _ofz_run systemctl "$verb" ollama; then
    echo "ollama: $verb done."
  else
    echo "Failed. Try: systemctl $verb ollama" >&2
    return 1
  fi
}

_ofz_logs() {
  local n=${1:-}
  if [ -z "$n" ]; then
    _ofz_run journalctl -u ollama -f
  elif printf '%s' "$n" | command grep -Eq '^[0-9]+$'; then
    _ofz_run journalctl -u ollama -n "$n" --no-pager
  else
    echo "logs: N must be a number" >&2
    return 1
  fi
}

# Pick one name from stdin: fzf, else numbered list. Prints the name.
_ofz_pick() {
  local prompt=$1 names=() line choice i
  while IFS= read -r line; do
    [ -n "$line" ] && names+=("$line")
  done
  [ ${#names[@]} -gt 0 ] || return 1
  if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "${names[@]}" | fzf --height 40% --layout reverse --header "$prompt"
  else
    i=0
    for line in "${names[@]}"; do
      i=$((i + 1))
      printf '%s) %s\n' "$i" "$line" >&2
    done
    printf '%s [number]: ' "$prompt" >&2
    read -r choice </dev/tty
    printf '%s' "$choice" | command grep -Eq '^[0-9]+$' || return 1
    [ "$choice" -ge 1 ] && [ "$choice" -le ${#names[@]} ] || return 1
    # zsh arrays are 1-based, bash 0-based: resolve by counting
    i=0
    for line in "${names[@]}"; do
      i=$((i + 1))
      [ "$i" = "$choice" ] && { printf '%s\n' "$line"; break; }
    done
  fi
}

_ofz_unload() {
  local names model
  names=$(_ofz_capture ollama ps 2>/dev/null | command awk 'NR>1 && NF {print $1}')
  if [ -z "$names" ]; then
    echo "No model loaded (or server down)."
    return 0
  fi
  model=$(printf '%s\n' "$names" | _ofz_pick "Unload which model?") || { echo "Cancelled."; return 0; }
  [ -n "$model" ] || { echo "Cancelled."; return 0; }
  _ofz_valid_model "$model" || { echo "Invalid model name: $model" >&2; return 1; }
  _ofz_run ollama stop "$model" && echo "Unloaded $model."
}

_ofz_list() {
  _ofz_run ollama list || { echo "ollama list failed: service down?" >&2; return 1; }
}

_ofz_pull() {
  local m=${1:-}
  if [ -z "$m" ]; then
    printf 'Model to pull: '
    read -r m
  fi
  if ! _ofz_valid_model "$m"; then
    echo "Aborted: empty or invalid model name." >&2
    return 1
  fi
  _ofz_run ollama pull "$m"
}

_ofz_rm() {
  local m=${1:-} ans
  if [ -z "$m" ]; then
    m=$(_ofz_capture ollama list 2>/dev/null | command awk 'NR>1 && NF {print $1}' | _ofz_pick "Remove which model?") || { echo "Cancelled."; return 0; }
  fi
  if ! _ofz_valid_model "$m"; then
    echo "Aborted: empty or invalid model name." >&2
    return 1
  fi
  printf 'Remove %s? [y/N] ' "$m"
  read -r ans
  case "$ans" in
    y | Y) _ofz_run ollama rm "$m" ;;
    *) echo "Not removed." ;;
  esac
}

# --- menu --------------------------------------------------------------------

# Prints the chosen verb. Runs in a command substitution, so the EXIT trap
# removes the temp file without touching the caller's traps.
_ofz_menu_pick() {
  local tmp header choice opts=() line
  tmp=$(mktemp "${TMPDIR:-/tmp}/ofz.XXXXXX") || return 1
  trap 'command rm -f "$tmp"' EXIT
  _ofz_snapshot "$tmp"
  header="Ollama ($(_ofz_host) · $_OFZ_ACTIVE · $_OFZ_ENABLED · $_OFZ_LOADED loaded"
  if ! _ofz_is_local; then
    if _ofz_tunnel_up; then header="$header · tunnel up"; else header="$header · tunnel down"; fi
  fi
  header="$header)"
  if command -v fzf >/dev/null 2>&1; then
    choice=$(_ofz_rows | fzf --height 40% --layout reverse \
      --header "$header" \
      --preview "command cat '$tmp'" \
      --preview-window "right:50%:wrap" | command awk '{print $1}')
  else
    echo "$header" >&2
    while IFS= read -r line; do
      opts+=("${line%% *}")
    done <<EOF
$(_ofz_rows)
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
  printf '%s' "$choice"
}

_ofz_menu() {
  local choice
  if ! { [ -t 0 ] && [ -t 1 ]; }; then
    _ofz_usage >&2
    return 1
  fi
  choice=$(_ofz_menu_pick)
  [ -n "$choice" ] || return 0
  ollama-fzf "$choice"
}

# --- entry -------------------------------------------------------------------

ollama-fzf() {
  local verb=${1:-} arg=${2:-} rc=0
  _OFZ_LOCAL=$(_ofz_detect)
  case "$verb" in
    "") _ofz_menu; rc=$? ;;
    help | -h | --help) _ofz_usage ;;
    status) _ofz_status; rc=$? ;;
    start | stop | restart | enable | disable) _ofz_svc "$verb"; rc=$? ;;
    toggle) if _ofz_is_active; then _ofz_svc stop; else _ofz_svc start; fi; rc=$? ;;
    logs) _ofz_logs "$arg"; rc=$? ;;
    unload) _ofz_unload; rc=$? ;;
    list) _ofz_list; rc=$? ;;
    pull) _ofz_pull "$arg"; rc=$? ;;
    rm) _ofz_rm "$arg"; rc=$? ;;
    tunnel)
      if _ofz_is_local; then
        echo "tunnel: not needed here: ollama runs locally" >&2
        rc=1
      else
        ollama-tunnel toggle; rc=$?
      fi
      ;;
    *)
      echo "Unknown verb: $verb" >&2
      _ofz_usage >&2
      rc=1
      ;;
  esac
  unset _OFZ_LOCAL
  return $rc
}
