#!/usr/bin/env bash
# fzf file browser: pull/push single or multiple files between this Mac and Snuffish-PC.
# Usage: remote-files.sh pull|push. RF_HOST=local runs everything on this machine with cp (simulation).
# The other subcommands are fzf binds that call back into this script; state lives in $RF_STATE.

set -uo pipefail

RF_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
export RF_SELF
S="${RF_STATE:-}"

# Run a command on the browse side: the PC for pull (unless local), this machine otherwise.
_rf_exec() {
  if [[ "${RF_SIDE:-}" == pull && "${RF_HOST:-}" != local ]]; then
    ssh -n -o BatchMode=yes "$RF_HOST" "$(printf '%q ' "$@")"
  else
    "$@"
  fi
}

# fzf action arguments end at the first ")", so keep brackets out of them
_rf_safe() { printf '%s' "$1" | tr '()' '[]'; }

_rf_label() {
  local cwd where
  cwd=$(<"$S/cwd")
  [[ "$RF_SIDE" == pull ]] && where="$RF_HOST" || where=local
  _rf_safe " ${RF_SIDE^^} · $where:$cwd "
}

_rf_join() { [[ "$1" == / ]] && printf '/%s' "$2" || printf '%s/%s' "$1" "$2"; }

_rf_prompt() { printf 'change-prompt(%s ▸ )' "$1"; }

cmd_list() {
  local cwd
  cwd=$(<"$S/cwd")
  echo '../'
  _rf_exec bash -c 'cd -- "$1" 2>/dev/null && ls -1Ap' _ "$cwd"
}

# Show the cwd listing with an empty query; fzf drops its marks on reload, so re-select basket files by row
_rf_reload() {
  local cwd base sel
  cwd=$(<"$S/cwd")
  [[ "$cwd" == / ]] && base="" || base="$cwd"
  cmd_list >"$S/listing"
  sel=$(RF_BASE="$base" awk -v b="$S/basket" '
    BEGIN { base = ENVIRON["RF_BASE"]; while ((getline l < b) > 0) m[l] = 1 }
    !/\/$/ && ((base "/" $0) in m) { printf "+pos(%d)+select", NR }' "$S/listing")
  printf 'clear-query+reload-sync(cat -- "%s")+clear-selection%s+pos(1)+change-border-label(%s)+change-header()' \
    "$S/listing" "$sel" "$(_rf_label)"
}

cmd_finddirs() {
  local cwd
  cwd=$(<"$S/cwd")
  _rf_exec find "$cwd" -mindepth 1 -maxdepth 4 \( -name .git -o -name node_modules -o -name .cache \) -prune -o -type d -print
}

_rf_browse() {
  echo BROWSE >"$S/mode"
  printf '%s+enable-search' "$(_rf_prompt BROWSE)"
}

_rf_enter_mode() { # <GOTO|FIND>
  local cur
  cur=$(<"$S/mode")
  if [[ "$cur" == "$1" ]]; then
    # Pressing the same key again leaves the mode
    _rf_browse
    if [[ "$cur" == FIND ]]; then printf '+%s' "$(_rf_reload)"; else printf '+clear-query+change-header()'; fi
    return
  fi
  echo "$1" >"$S/mode"
  printf 'change-header()+'
  case "$1" in
    FIND) printf 'clear-query+reload-sync("%s" finddirs)+clear-selection+pos(1)+enable-search+%s' "$RF_SELF" "$(_rf_prompt FIND)" ;;
    *)
      [[ "$cur" == FIND ]] && printf 'reload-sync(cat -- "%s")+' "$S/listing"
      printf 'disable-search+clear-query+%s' "$(_rf_prompt "$1")"
      ;;
  esac
}

cmd_goto_start() { _rf_enter_mode GOTO; }
cmd_find_start() { _rf_enter_mode FIND; }

_rf_toggle() { # <full path>
  if grep -Fxq -- "$1" "$S/basket"; then
    grep -Fxv -- "$1" "$S/basket" >"$S/basket.tmp" || true
    mv "$S/basket.tmp" "$S/basket"
  else
    echo "$1" >>"$S/basket"
  fi
}

cmd_toggle() { # <item> <down|up>
  local item="${1:-}" cwd
  [[ "$(<"$S/mode")" == BROWSE && -n "$item" && "$item" != */ ]] || return
  cwd=$(<"$S/cwd")
  _rf_toggle "$(_rf_join "$cwd" "$item")"
  printf 'toggle+%s+refresh-preview' "${2:-down}"
}

cmd_back() {
  local cwd
  [[ "$(<"$S/mode")" == BROWSE ]] || return
  cwd=$(<"$S/cwd")
  dirname -- "$cwd" >"$S/cwd"
  _rf_reload
}

# Resolve a typed path (~, relative, absolute) to a directory on the browse side
_rf_resolve_dir() {
  local p="$1" cwd home
  cwd=$(<"$S/cwd")
  if [[ "$p" == "~" || "$p" == "~/"* ]]; then
    home=$(_rf_exec bash -c 'printf %s "$HOME"')
    p="$home${p:1}"
  fi
  [[ "$p" == /* ]] || p="$(_rf_join "$cwd" "$p")"
  _rf_exec bash -c 'cd -- "$1" 2>/dev/null && pwd' _ "$p"
}

cmd_enter() { # <item> <query>
  local mode item="${1:-}" query="${2:-}" cwd new
  mode=$(<"$S/mode")
  cwd=$(<"$S/cwd")
  case "$mode" in
    BROWSE)
      if [[ "$item" == '../' ]]; then
        cmd_back
      elif [[ "$item" == */ ]]; then
        _rf_join "$cwd" "${item%/}" >"$S/cwd"
        _rf_reload
      fi
      ;;
    GOTO)
      [[ -n "$query" ]] || return
      if new=$(_rf_resolve_dir "$query") && [[ -n "$new" ]]; then
        echo "$new" >"$S/cwd"
        printf '%s+%s' "$(_rf_browse)" "$(_rf_reload)"
      else
        printf 'change-header(%s)' "$(_rf_safe "✗ not a directory: $query")"
      fi
      ;;
    FIND)
      [[ -n "$item" ]] || return
      echo "$item" >"$S/cwd"
      printf '%s+%s' "$(_rf_browse)" "$(_rf_reload)"
      ;;
  esac
}

cmd_basket() {
  local n
  n=$(grep -c . "$S/basket" || true)
  echo "Basket ($n)"
  sort "$S/basket" | awk '{ i = match($0, /[^\/]*$/); d = substr($0, 1, i - 1); f = substr($0, i); if (d != last) { print d; last = d } print "  " f }'
  echo "→ $(<"$S/dest")"
}

cmd_clear() {
  : >"$S/basket"
  printf 'clear-selection+refresh-preview'
}

cmd_transfer() {
  if [[ -s "$S/basket" ]]; then
    printf 'become("%s" do-transfer)' "$RF_SELF"
  else
    printf 'change-header(Basket is empty)'
  fi
}

cmd_do_transfer() {
  local dest p n=0
  local files=()
  dest=$(<"$S/dest")
  while IFS= read -r p; do
    [[ -n "$p" ]] && files+=("$p")
  done <"$S/basket"
  n=${#files[@]}
  if [[ "$RF_HOST" == local ]]; then
    mkdir -p -- "$dest" && cp -- "${files[@]}" "$dest/" || return 1
  elif [[ "$RF_SIDE" == pull ]]; then
    local srcs=()
    for p in "${files[@]}"; do srcs+=("$RF_HOST:$p"); done
    mkdir -p -- "$dest" && scp -- "${srcs[@]}" "$dest/" || return 1
  else
    ssh -n "$RF_HOST" "mkdir -p -- $(printf '%q' "$dest")" && scp -- "${files[@]}" "$RF_HOST:$dest/" || return 1
  fi
  echo "✓ $n file(s) → ${dest%/}/"
}

cmd_start() { # pull|push
  command -v fzf >/dev/null || { echo "remote-files: fzf not found" >&2; return 1; }
  export RF_SIDE="$1" RF_HOST="${RF_HOST:-snuffish-pc}"
  # Prompt for password or host key here, not inside a bind
  if [[ "$RF_HOST" != local ]]; then
    ssh -O check "$RF_HOST" 2>/dev/null || ssh -fN "$RF_HOST" || return 1
  fi
  RF_STATE=$(mktemp -d) || return 1
  export RF_STATE
  S="$RF_STATE"
  trap 'rm -rf "$S"' EXIT
  : >"$S/basket"
  echo BROWSE >"$S/mode"
  if [[ "$RF_SIDE" == pull ]]; then
    _rf_exec pwd >"$S/cwd"
    echo "${RF_DEST:-$HOME/Downloads}" >"$S/dest"
  else
    pwd >"$S/cwd"
    echo "${RF_DEST:-Downloads/}" >"$S/dest"
  fi
  cmd_list >"$S/listing"
  fzf --layout reverse --border --multi --marker '● ' --with-shell 'bash -c' <"$S/listing" \
    --prompt 'BROWSE ▸ ' --border-label "$(_rf_label)" \
    --preview '"$RF_SELF" basket' --preview-window right:40% --preview-label ' Basket ' \
    --footer 'Enter open · Tab select · ⌫/⌥↑ back · ^G goto · ^F find · ^T transfer · ^X clear' \
    --bind 'enter:transform:"$RF_SELF" enter {} {q}' \
    --bind 'tab:transform:"$RF_SELF" toggle {} down' \
    --bind 'shift-tab:transform:"$RF_SELF" toggle {} up' \
    --bind 'backward-eof:transform:"$RF_SELF" back' \
    --bind 'alt-up:transform:"$RF_SELF" back' \
    --bind 'ctrl-g:transform:"$RF_SELF" goto-start' \
    --bind 'ctrl-f:transform:"$RF_SELF" find-start' \
    --bind 'ctrl-x:transform:"$RF_SELF" clear' \
    --bind 'ctrl-t:transform:"$RF_SELF" transfer'
}

case "${1:-}" in
  pull | push) cmd_start "$1" ;;
  list | finddirs | goto-start | find-start | toggle | back | enter | basket | clear | transfer | do-transfer)
    sub="${1//-/_}"
    shift
    "cmd_$sub" "$@"
    ;;
  *) echo "usage: ${0##*/} pull|push" >&2; exit 2 ;;
esac
