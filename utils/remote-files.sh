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

# fzf drops its marks on reload: emit "+pos(N)+select" for every basket file in a listing.
# <listing> <prefix that turns a row into a full path: "<cwd>/", or "" for absolute rows>
_rf_select_rows() {
  RF_PREFIX="$2" awk -v b="$S/basket" '
    BEGIN { p = ENVIRON["RF_PREFIX"]; while ((getline l < b) > 0) m[l] = 1 }
    !/\/$/ && ((p $0) in m) { printf "+pos(%d)+select", NR }' "$1"
}

# Show the cwd listing with an empty query, the cursor on <focus name> when given, else the top row
_rf_reload() {
  local cwd sel row
  cwd=$(<"$S/cwd")
  cmd_list >"$S/listing"
  sel=$(_rf_select_rows "$S/listing" "${cwd%/}/")
  row=1
  [[ -n "${1:-}" ]] && row=$(awk -v f="$1" '$0 == f { print NR; exit }' "$S/listing")
  printf 'clear-query+reload-sync(cat -- "%s")+clear-selection%s+pos(%s)+change-border-label(%s)+change-header()' \
    "$S/listing" "$sel" "${row:-1}" "$(_rf_label)"
}

# Dirs (with a trailing "/") and files under cwd, relative to it so the fuzzy match skips the shared prefix
cmd_findall() {
  local cwd
  cwd=$(<"$S/cwd")
  _rf_exec bash -c '
    cd -- "$1" || exit
    prune=(\( -name .git -o -name node_modules -o -name .cache \) -prune -o)
    find . -mindepth 1 -maxdepth 4 "${prune[@]}" -type d -print | sed "s|^\./||; s|\$|/|"
    find . -mindepth 1 -maxdepth 4 "${prune[@]}" -type f -print | sed "s|^\./||"' _ "$cwd"
}

_rf_browse() {
  echo BROWSE >"$S/mode"
  printf '%s+enable-search' "$(_rf_prompt BROWSE)"
}

_rf_enter_mode() { # <GOTO|FIND|DEST>
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
    FIND)
      cmd_findall >"$S/found"
      printf 'clear-query+reload-sync(cat -- "%s")+clear-selection%s+pos(1)+enable-search+%s' \
        "$S/found" "$(_rf_select_rows "$S/found" "$(sed 's|/*$|/|' "$S/cwd")")" "$(_rf_prompt FUZZY)"
      ;;
    *)
      [[ "$cur" == FIND ]] && printf 'reload-sync(cat -- "%s")+' "$S/listing"
      printf 'disable-search+clear-query+%s' "$(_rf_prompt "$1")"
      ;;
  esac
}

cmd_goto_start() { _rf_enter_mode GOTO; }
cmd_find_start() { _rf_enter_mode FIND; }
cmd_dest_start() { _rf_enter_mode DEST; }

_rf_toggle() { # <full path>
  if grep -Fxq -- "$1" "$S/basket"; then
    grep -Fxv -- "$1" "$S/basket" >"$S/basket.tmp" || true
    mv "$S/basket.tmp" "$S/basket"
  else
    echo "$1" >>"$S/basket"
  fi
}

cmd_toggle() { # <item> <down|up>
  local item="${1:-}" mode cwd
  mode=$(<"$S/mode")
  [[ -n "$item" && "$item" != */ ]] || return
  case "$mode" in
    BROWSE) cwd=$(<"$S/cwd"); _rf_toggle "$(_rf_join "$cwd" "$item")" ;;
    FIND) cwd=$(<"$S/cwd"); _rf_toggle "$(_rf_join "$cwd" "$item")" ;;
    *) return ;;
  esac
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
  local mode item="${1:-}" query="${2:-}" cwd new dest
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
      item=$(_rf_join "$cwd" "$item")
      # A dir opens itself; a file opens its dir with the cursor on it
      if [[ "$item" == */ ]]; then
        echo "${item%/}" >"$S/cwd"
        printf '%s+%s' "$(_rf_browse)" "$(_rf_reload)"
      else
        dirname -- "$item" >"$S/cwd"
        printf '%s+%s' "$(_rf_browse)" "$(_rf_reload "$(basename -- "$item")")"
      fi
      ;;
    DEST)
      [[ -n "$query" ]] || return
      # Pull lands on this Mac; push dests are relative to the PC home, as scp's SFTP session starts there
      if [[ "$RF_SIDE" == pull || "$RF_HOST" == local ]]; then
        dest="${query/#\~/$HOME}"
      else
        dest="${query#\~/}"
      fi
      echo "$dest" >"$S/dest"
      printf '%s+clear-query+change-header()+refresh-preview' "$(_rf_browse)"
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
  fzf --layout reverse --border --multi --scheme path --marker '● ' --with-shell 'bash -c' <"$S/listing" \
    --prompt 'BROWSE ▸ ' --border-label "$(_rf_label)" \
    --preview '"$RF_SELF" basket' --preview-window right:40% --preview-label ' Basket ' \
    --footer 'Enter open · Tab select · ⌫/⌥↑ back · ^G goto · ^F fuzzy · ^D dest · ^T transfer · ^X clear' \
    --bind 'enter:transform:"$RF_SELF" enter {} {q}' \
    --bind 'tab:transform:"$RF_SELF" toggle {} down' \
    --bind 'shift-tab:transform:"$RF_SELF" toggle {} up' \
    --bind 'backward-eof:transform:"$RF_SELF" back' \
    --bind 'alt-up:transform:"$RF_SELF" back' \
    --bind 'ctrl-g:transform:"$RF_SELF" goto-start' \
    --bind 'ctrl-f:transform:"$RF_SELF" find-start' \
    --bind 'ctrl-d:transform:"$RF_SELF" dest-start' \
    --bind 'ctrl-x:transform:"$RF_SELF" clear' \
    --bind 'ctrl-t:transform:"$RF_SELF" transfer'
}

case "${1:-}" in
  pull | push) cmd_start "$1" ;;
  list | findall | goto-start | find-start | dest-start | toggle | back | enter | basket | clear | transfer | do-transfer)
    sub="${1//-/_}"
    shift
    "cmd_$sub" "$@"
    ;;
  *) echo "usage: ${0##*/} pull|push" >&2; exit 2 ;;
esac
