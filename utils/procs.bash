#!/usr/bin/env bash
# procs — live process viewer (fzf HUD), multi-select, safe kill.
#
#   procs                         interactive (fzf HUD; numbered menu fallback)
#   procs list [--mem] [-n N] [--group]
#   procs kill [--sudo] [-y] <pid>...
#
# Sourced into bash and zsh: no zsh special var names (path, status, commands, signals ...);
# `command cat` etc. because zsh may alias cat=bat. fzf actions run via `bash -c` and source this file.
# Env: PROCS_TERM_TIMEOUT (3s before SIGKILL), PROCS_TOP_N (30 rows for `procs list`),
#      PROCS_ROWS (1000 rows in the viewer), PROCS_FZF_FORCE_LEGACY=1 (static fzf flow, no live HUD).

: "${PROCS_TERM_TIMEOUT:=3}"
: "${PROCS_TOP_N:=30}"
: "${PROCS_ROWS:=1000}"

if [ -n "${ZSH_VERSION:-}" ]; then
  eval '_PROCS_SELF=${(%):-%x}'
else
  _PROCS_SELF="${BASH_SOURCE[0]}"
fi
case "$_PROCS_SELF" in /*) ;; *) _PROCS_SELF="$PWD/$_PROCS_SELF" ;; esac

# ------------------------------------------------------------------------------
# Identity & protection
# ------------------------------------------------------------------------------

# _procs_stat_field <pid> <n>: field n (1=state, 2=ppid, 20=starttime) of /proc/<pid>/stat,
# parsed after the last ") " so comm with spaces/parens cannot shift columns.
_procs_stat_field() {
  local s
  s=$(command cat "/proc/$1/stat" 2>/dev/null) || return 1
  s=${s##*) }
  printf '%s\n' "$s" | awk -v n="$2" '{print $n}'
}

_procs_start() { _procs_stat_field "$1" 20; }

# 0 = protected (never kill): pid 1/2, kernel threads, own shell and its ancestors.
_procs_protected() {
  local target="$1" p pp
  [ "$target" = 1 ] && return 0
  [ "$target" = 2 ] && return 0
  pp=$(_procs_stat_field "$target" 2) || return 1
  [ "$pp" = 2 ] && return 0
  p=$$
  while [ -n "$p" ] && [ "$p" != 0 ] && [ "$p" != 1 ]; do
    [ "$p" = "$target" ] && return 0
    p=$(_procs_stat_field "$p" 2) || break
  done
  return 1
}

_procs_alive() {
  local st
  st=$(_procs_stat_field "$1" 1) || return 1
  [ "$st" != Z ] && [ "$st" != X ]
}

# _procs_kill_checked <pid> <start> <sudo 0|1> [signal=TERM]
# TERM escalates to KILL after $PROCS_TERM_TIMEOUT; any other signal is sent once.
_procs_kill_checked() {
  local target="$1" want="$2" use_sudo="${3:-0}" want_sig="${4:-TERM}" cur sig i ticks
  want_sig=${want_sig#SIG}
  if ! _procs_alive "$target"; then
    printf '  %s: already gone\n' "$target"; return 0
  fi
  cur=$(_procs_start "$target")
  if [ "$cur" != "$want" ]; then
    printf '  %s: PID reused, skipped\n' "$target"; return 1
  fi
  if _procs_protected "$target"; then
    printf '  %s: protected (init/kernel/own shell chain), skipped\n' "$target"; return 1
  fi
  if [ "$want_sig" = TERM ]; then set -- TERM KILL; else set -- "$want_sig"; fi
  for sig in "$@"; do
    if ! kill -"$sig" "$target" 2>/dev/null; then
      if [ "$use_sudo" = 1 ]; then
        sudo kill -"$sig" "$target" 2>/dev/null || true
      else
        if _procs_alive "$target"; then
          printf '  %s: permission denied, run: sudo kill -%s %s\n' "$target" "$sig" "$target"
          return 1
        fi
      fi
    fi
    case "$sig" in
      TERM | KILL) ;;
      *) printf '  %s: sent %s\n' "$target" "$sig"; return 0 ;;
    esac
    ticks=$((PROCS_TERM_TIMEOUT * 10))
    [ "$sig" = KILL ] && ticks=20
    i=0
    while [ "$i" -lt "$ticks" ]; do
      _procs_alive "$target" || { printf '  %s: killed (%s)\n' "$target" "$sig"; return 0; }
      sleep 0.1
      i=$((i + 1))
    done
  done
  printf '  %s: still alive after KILL\n' "$target"
  return 1
}

# ------------------------------------------------------------------------------
# Sampler
# ------------------------------------------------------------------------------

# _procs_sample <statedir> <cpu|mem> <group 0|1> <mine 0|1> <n> <color 0|1>
# One /proc/*/stat pass + one ps. Emits a header row, then rows
#   id1 <TAB> id2 <TAB> display <TAB> spec
# id1/id2 = pid/start (group mode: g:<comm> / 0); spec = "pid:start[,pid:start...]" (kill + preview target).
# CPU% = jiffy delta against the previous sample kept in <statedir>/prev; samples < 1 s apart
# reuse the last computed CPU values (a forced refresh would otherwise show 0.0 everywhere).
_procs_sample() {
  local st="$1" sortby="${2:-cpu}" group="${3:-0}" mine="${4:-0}" n="${5:-300}" color="${6:-0}"
  local now prev_t dk dt keep tab hz memkb
  tab=$(printf '\t')
  now=$(date +%s.%N)
  prev_t=$(command cat "$st/t" 2>/dev/null)
  [ -n "$prev_t" ] || prev_t=0
  dk=$(awk -v a="$now" -v b="$prev_t" 'BEGIN { d = (b > 0) ? a - b : 0; printf "%.3f %d", d, (d > 0 && d < 1) }')
  dt=${dk%% *}; keep=${dk##* }
  [ -f "$st/valid" ] || keep=0
  hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
  memkb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
  rm -f "$st/prev.new"
  {
    if [ "$color" = 1 ]; then printf '0\t0\t\033[1m'; else printf '0\t0\t'; fi
    printf '%7s  %-10s %6s %6s %6s %4s  %-16s %s' PID USER 'CPU%' 'MEM%' RSS THR PROGRAM COMMAND
    if [ "$color" = 1 ]; then printf '\033[0m'; fi
    printf '\t0:0\n'
    for f in /proc/[0-9]*/stat; do { read -r l < "$f"; } 2>/dev/null && printf '%s\n' "$l"; done |
      LC_NUMERIC=C awk -v prev="$st/prev" -v out="$st/prev.new" -v keep="$keep" -v dt="$dt" -v hz="$hz" \
        -v memkb="$memkb" -v me="${USER:-}" -v home="$HOME" -v mode="$sortby" -v grp="$group" \
        -v mine="$mine" -v color="$color" '
        function hum(k) { return k >= 1048576 ? sprintf("%.1fG", k/1048576) : k >= 1024 ? sprintf("%dM", k/1024) : sprintf("%dK", k) }
        function heat(v, lo, mid, hi) { return !color ? "" : v < lo ? "\033[90m" : v < mid ? "" : v < hi ? "\033[33m" : "\033[1;31m" }
        function sgr(c) { return color ? "\033[" c "m" : "" }
        function tilde(s,   i) {
          if (home == "") return s
          while ((i = index(s, home)) > 0) s = substr(s, 1, i - 1) "~" substr(s, i + length(home))
          return s
        }
        function fmt(pidtxt, usr, cpu, mem, rss, thr, prog, args, own) {
          return sprintf("%s%7s%s  %s%-10.10s%s %s%6.1f%s %s%6.1f%s %6s %4s  %s%-16.16s%s %s%s%s",
            sgr(90), pidtxt, sgr(0), own ? "" : sgr(90), usr, sgr(0), heat(cpu, 5, 50, 100), cpu, sgr(0),
            heat(mem, 1, 5, 15), mem, sgr(0), hum(rss), thr, own ? sgr("1;36") : sgr(36), prog, sgr(0), sgr(90), args, sgr(0))
        }
        BEGIN {
          while ((getline l < prev) > 0) { split(l, a, " "); pj[a[1] " " a[2]] = a[3]; pc[a[1] " " a[2]] = a[4] }
          close(prev)
          cmd = "ps -eww -o pid=,user:16=,rss=,args="
          while ((cmd | getline l) > 0) {
            split(l, a, " "); p = a[1]; u[p] = a[2]; r[p] = a[3]
            s = l; sub(/^ *[0-9]+ +[^ ]+ +[0-9]+ */, "", s); args[p] = s
          }
          close(cmd)
        }
        {
          pid = $1; c = $0; sub(/^[0-9]+ \(/, "", c); sub(/\) [^)]*$/, "", c)
          rest = $0; sub(/.*\) /, "", rest); split(rest, f, " ")
          ppid = f[2]; j = f[12] + f[13]; start = f[20]; thr = f[18]
          if (ppid == 2 || pid == 2 || !(pid in u)) next            # kernel threads / vanished
          key = pid " " start
          if (keep) cpu = (key in pc) ? pc[key] : 0
          else cpu = (key in pj && dt > 0) ? (j - pj[key]) / hz / dt * 100 : 0
          if (!keep) print pid, start, j, cpu > out
          own = (u[pid] == me)
          if (mine == 1 && !own) next
          mem = memkb > 0 ? r[pid] * 100 / memkb : 0
          a2 = tilde(args[pid]); if (a2 == "") a2 = "[" c "]"
          if (grp != 1) {
            sk = (mode == "mem") ? sprintf("%012d", r[pid]) : sprintf("%012.3f%012d", cpu, r[pid])
            printf "%s\t%s\t%s\t%s\t%s:%s\n", sk, pid, start, fmt(pid, u[pid], cpu, mem, r[pid], thr, c, a2, own), pid, start
            next
          }
          if (!(c in cnt)) { order[++no] = c; gu[c] = u[pid]; ga[c] = a2 } else if (gu[c] != u[pid]) gu[c] = "mixed"
          cnt[c]++; gcpu[c] += cpu; grss[c] += r[pid]; gthr[c] += thr
          gs[c] = (c in gs) ? gs[c] "," pid ":" start : pid ":" start
        }
        END {
          for (k = 1; k <= no; k++) {
            c = order[k]; m = memkb > 0 ? grss[c] * 100 / memkb : 0
            sk = (mode == "mem") ? sprintf("%012d", grss[c]) : sprintf("%012.3f%012d", gcpu[c], grss[c])
            printf "%s\tg:%s\t0\t%s\t%s\n", sk, c, fmt("(x" cnt[c] ")", gu[c], gcpu[c], m, grss[c], gthr[c], c, ga[c], gu[c] == me), gs[c]
          }
        }' |
      LC_ALL=C sort -t "$tab" -k1,1r | head -n "$n" | cut -f2-
  }
  if [ "$keep" != 1 ] && [ -f "$st/prev.new" ]; then
    mv "$st/prev.new" "$st/prev"
    printf '%s\n' "$now" > "$st/t"
    [ "$dt" = "0.000" ] || : > "$st/valid"
  fi
}

# State dir files: mode (cpu|mem), group (0|1), mine (0|1), paused (flag), rows (cache)
_procs_state_init() { printf 'cpu\n' > "$1/mode"; printf '0\n' > "$1/group"; printf '0\n' > "$1/mine"; }

_procs_state_get() { local v; v=$(command cat "$1/$2" 2>/dev/null); printf '%s\n' "${v:-$3}"; }

# Rows for the fzf session (reload command); frozen while paused.
_procs_rows_cmd() {
  local st="$1"
  if [ -f "$st/paused" ] && [ -f "$st/rows" ]; then command cat "$st/rows"; return; fi
  _procs_sample "$st" "$(_procs_state_get "$st" mode cpu)" "$(_procs_state_get "$st" group 0)" \
    "$(_procs_state_get "$st" mine 0)" "$PROCS_ROWS" 1 > "$st/rows.new" && mv "$st/rows.new" "$st/rows"
  command cat "$st/rows"
}

# _procs_toggle <statedir> sort|group|mine|pause
_procs_toggle() {
  local st="$1" v
  case "$2" in
    sort) [ "$(_procs_state_get "$st" mode cpu)" = cpu ] && v=mem || v=cpu; printf '%s\n' "$v" > "$st/mode" ;;
    group) [ "$(_procs_state_get "$st" group 0)" = 1 ] && v=0 || v=1; printf '%s\n' "$v" > "$st/group" ;;
    mine) [ "$(_procs_state_get "$st" mine 0)" = 1 ] && v=0 || v=1; printf '%s\n' "$v" > "$st/mine" ;;
    pause) if [ -f "$st/paused" ]; then rm -f "$st/paused"; else : > "$st/paused"; fi; return ;;
  esac
  rm -f "$st/rows"   # view changed: next reload recomputes even while paused
}

# ------------------------------------------------------------------------------
# HUD, labels, previews
# ------------------------------------------------------------------------------

# Border label: cores · sort · scope · refresh state
_procs_label() {
  local st="$1" run="⏵ 2s" scope="all users" kind=""
  [ -f "$st/paused" ] && run="⏸ paused"
  [ "$(_procs_state_get "$st" mine 0)" = 1 ] && scope="mine"
  [ "$(_procs_state_get "$st" group 0)" = 1 ] && kind=" · grouped"
  printf ' procs · %s cores · sort %s ▼%s · %s · %s ' "$(nproc)" "$(_procs_state_get "$st" mode cpu)" "$kind" "$scope" "$run"
}

# CPU / MEM bars (htop-style), width from $FZF_COLUMNS; frozen while paused.
_procs_meters() {
  local st="$1" w cols="${FZF_COLUMNS:-}" cu cn cs ci cio cirq csirq csteal busy total pb pt
  if [ -f "$st/paused" ] && [ -f "$st/meters" ]; then command cat "$st/meters"; return; fi
  w=36
  if [ -n "$cols" ]; then w=$((cols * 6 / 10 - 52)); [ "$w" -lt 10 ] && w=10; [ "$w" -gt 36 ] && w=36; fi
  read -r _ cu cn cs ci cio cirq csirq csteal _ < /proc/stat
  busy=$((cu + cn + cs + cirq + csirq + csteal)); total=$((cu + cn + cs + ci + cio + cirq + csirq + csteal))
  pb=0; pt=0
  { read -r pb pt < "$st/cpu"; } 2>/dev/null
  printf '%s %s\n' "$busy" "$total" > "$st/cpu" 2>/dev/null
  awk -v b=$((busy - pb)) -v t=$((total - pt)) -v w="$w" '
    function bar(p, col,   n, s, k) { n = int(p * w / 100 + .5); s = col; for (k = 0; k < w; k++) { if (k == n) s = s "\033[90m"; s = s (k < n ? "■" : "·") } return s "\033[0m" }
    function col(p) { return p < 50 ? "\033[32m" : p < 80 ? "\033[33m" : "\033[31m" }
    FILENAME == "/proc/meminfo" && /^MemTotal:/ { mt = $2 } FILENAME == "/proc/meminfo" && /^MemAvailable:/ { ma = $2 }
    FILENAME == "/proc/meminfo" && /^SwapTotal:/ { swt = $2 } FILENAME == "/proc/meminfo" && /^SwapFree:/ { swf = $2 }
    FILENAME == "/proc/loadavg" { l = $1 " " $2 " " $3; split($4, q, "/"); tasks = q[2] }
    FILENAME == "/proc/uptime" { up = $1 }
    END {
      cp = t > 0 ? b * 100 / t : 0; mp = mt > 0 ? (mt - ma) * 100 / mt : 0
      printf " \033[1mCPU\033[0m %s %5.1f%%   \033[90mload\033[0m %s   \033[90mtasks\033[0m %s\n", bar(cp, col(cp)), cp, l, tasks
      printf " \033[1mMEM\033[0m %s %5.1f%%   \033[90mused\033[0m %.1f/%.1fG   \033[90mswap\033[0m %.1fG   \033[90mup\033[0m %dh%02dm", bar(mp, col(mp)), mp, (mt-ma)/1048576, mt/1048576, (swt-swf)/1048576, up/3600, (up%3600)/60
    }' /proc/meminfo /proc/loadavg /proc/uptime > "$st/meters.new" && mv "$st/meters.new" "$st/meters"
  command cat "$st/meters"
}

# _procs_first_pid <spec> -> first pid of "pid:start[,...]"
_procs_first_pid() { local s="${1%%,*}"; printf '%s\n' "${s%%:*}"; }

# Process card for the preview; <spec> may be a group.
_procs_info() {
  local spec="$1" p l c ports kids
  p=$(_procs_first_pid "$spec")
  case "$p" in '' | *[!0-9]* | 0) printf '\033[90mno process selected\033[0m\n'; return ;; esac
  read -r l < "/proc/$p/stat" 2>/dev/null || { printf 'process %s is gone\n' "$p"; return; }
  c=${l#*\(}; c=${c%\)*}
  printf '\033[1;36m%s\033[0m  \033[90mpid %s · parent %s\033[0m\n\n' "$c" "$p" "$(_procs_stat_field "$p" 2)"
  case "$spec" in *,*)
    printf '  \033[33mgroup of %s processes:\033[0m %s\n\n' "$(printf '%s\n' "$spec" | tr ',' '\n' | wc -l)" \
      "$(printf '%s\n' "$spec" | tr ',' '\n' | sed 's/:.*//' | head -n 12 | paste -sd ' ')" ;;
  esac
  command ps -o user=,stat=,lstart=,etime=,time=,nlwp=,rss= -p "$p" | awk '{
    printf "  \033[90m%-9s\033[0m %s\n  \033[90m%-9s\033[0m %s\n  \033[90m%-9s\033[0m %s %s %s %s\n  \033[90m%-9s\033[0m %s   \033[90mcpu time\033[0m %s\n  \033[90m%-9s\033[0m %s   \033[90mrss\033[0m %dM\n",
      "user", $1, "state", $2, "started", $4, $5, $6, $7, "elapsed", $8, $9, "threads", $10, $11/1024 }'
  printf '  \033[90m%-9s\033[0m %s\n' cwd "$(readlink "/proc/$p/cwd" 2>/dev/null | sed "s|^$HOME|~|")"
  ports=$(ss -ltnupH 2>/dev/null | awk -v p="pid=$p," 'index($0, p) { print $1 " " $5 }' | sort -u | paste -sd ',' | sed 's/,/, /g')
  [ -n "$ports" ] && printf '  \033[90m%-9s\033[0m \033[33m%s\033[0m\n' listening "$ports"
  printf '\n\033[90m── command ──\033[0m\n%s\n' "$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | sed "s|$HOME|~|g")"
  kids=$(command ps --ppid "$p" -o pid=,comm= 2>/dev/null | head -n 8)
  [ -n "$kids" ] && printf '\n\033[90m── children ──\033[0m\n%s\n'  "$kids"
  return 0
}

_procs_tree() {
  local p
  p=$(_procs_first_pid "$1")
  case "$p" in '' | *[!0-9]* | 0) printf '\033[90mno process selected\033[0m\n'; return ;; esac
  if command -v pstree >/dev/null 2>&1; then
    pstree -p -a -s -l -U "$p" 2>/dev/null | sed "s|$HOME|~|g"
  else
    command ps --forest -o pid=,user=,args= -g "$(command ps -o pgid= -p "$p" | tr -d ' ')" 2>/dev/null | sed "s|$HOME|~|g"
  fi
}

_procs_keys() {
  cat <<'EOF'
  enter       send TERM (confirm; KILL after 3s)
  ctrl-k      pick a signal: TERM INT HUP KILL STOP CONT
  tab         select / unselect row
  space       pause / resume auto-refresh (2s)
  ctrl-r      refresh now

  ctrl-s      sort cpu ↔ mem
  ctrl-g      group by program
  ctrl-u      mine only ↔ all users

  ctrl-t      process tree       ctrl-o  info card
  ctrl-p      toggle preview     shift-↑/↓ scroll preview
  esc         quit

  grey rows = other users (kill needs --sudo)
  selection follows pid + start time, never a reused pid
EOF
}

# ------------------------------------------------------------------------------
# Kill flow
# ------------------------------------------------------------------------------

_procs_anykey() {
  printf '\n  press any key…'
  if [ -n "${BASH_VERSION:-}" ]; then read -rsn1 < /dev/tty 2>/dev/null; else read -rsk1 < /dev/tty 2>/dev/null; fi
  return 0
}

# _procs_do_kill <sudo> <yes> [signal] ; targets "pid start" on stdin (one per line)
_procs_do_kill() {
  local use_sudo="$1" assume_yes="$2" want_sig="${3:-TERM}" targets line p s ans total=0 failed=0
  targets=$(command cat)
  [ -n "$targets" ] || { echo "Nothing selected."; return 0; }
  echo "Targets:"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    p=${line%% *}
    printf '  %s  %s\n' "$p" "$(command ps -o user=,args= -p "$p" 2>/dev/null | cut -c1-100)"
    total=$((total + 1))
  done <<EOF
$targets
EOF
  if [ "$assume_yes" != 1 ]; then
    printf 'Send %s to %s process(es)? [y/N] ' "$want_sig" "$total"
    read -r ans < /dev/tty 2>/dev/null || read -r ans
    case "$ans" in y | Y | yes) ;; *) echo "Cancelled."; return 0 ;; esac
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    p=${line%% *}; s=${line#* }
    _procs_kill_checked "$p" "$s" "$use_sudo" "$want_sig" || failed=$((failed + 1))
  done <<EOF
$targets
EOF
  [ "$failed" -eq 0 ]
}

# specs ("pid:start[,pid:start...]") as args -> "pid start" lines; header (0) and junk dropped
_procs_specs_to_targets() {
  printf '%s\n' "$@" | tr ',' '\n' | while IFS=: read -r p s; do
    case "$p" in '' | *[!0-9]* | 0) continue ;; esac
    printf '%s %s\n' "$p" "$s"
  done | awk '!seen[$0]++'
}

# In-fzf kill (execute): _procs_kill_ui <signal> <spec>...
_procs_kill_ui() {
  local want_sig="$1"
  shift
  printf '\n'
  _procs_specs_to_targets "$@" | _procs_do_kill "${PROCS_SUDO:-0}" "${PROCS_YES:-0}" "$want_sig"
  _procs_anykey
}

# ctrl-k: pick a signal in a nested fzf, then kill
_procs_signal_pick() {
  local sig
  sig=$(printf '%s\n' TERM INT HUP KILL STOP CONT | fzf --height 12 --reverse --border rounded \
    --prompt 'signal › ' --header 'send which signal?  (esc cancels)' --no-multi) || return 0
  [ -n "$sig" ] || return 0
  _procs_kill_ui "$sig" "$@"
}

# fzf output lines (field 4 = spec) -> "pid start" lines
_procs_lines_to_targets() {
  local tab specs
  tab=$(printf '\t')
  specs=$(awk -F"$tab" '{ print $4 }')
  [ -n "$specs" ] || return 0
  # shellcheck disable=SC2086
  printf '%s\n' "$specs" | tr ',' '\n' | while IFS=: read -r p s; do
    case "$p" in '' | *[!0-9]* | 0) continue ;; esac
    printf '%s %s\n' "$p" "$s"
  done | awk '!seen[$0]++'
}

# ------------------------------------------------------------------------------
# Interactive
# ------------------------------------------------------------------------------

# 0 = this fzf knows every option/action the HUD uses (exit 2 = unsupported option)
_procs_fzf_modern() {
  local rc
  [ "${PROCS_FZF_FORCE_LEGACY:-0}" = 1 ] && return 1
  printf 'x\n' | fzf --filter x --track --id-nth 1,2 --gutter ' ' --footer f --with-shell 'bash -c' \
    --info inline-right --border-label-pos 3 --preview-window 'right,40%,border-rounded,wrap,hidden' \
    --bind 'start:ignore,every(2):transform-header(true)+transform-border-label(true)+reload-sync(true),ctrl-t:change-preview-label(x)+change-preview(true)+show-preview' \
    > /dev/null 2>&1
  rc=$?
  [ "$rc" -ne 2 ]
}

_procs_interactive_hud() {
  local use_sudo="$1" assume_yes="$2" state sd
  sd=$(mktemp -d "${TMPDIR:-/tmp}/procs.XXXXXX") || return 1
  state="$sd/s"; mkdir -p "$state"
  _procs_state_init "$state"
  export PROCS_SELF="$_PROCS_SELF" PROCS_STATE="$state" PROCS_SUDO="$use_sudo" PROCS_YES="$assume_yes"
  # prime the CPU delta so the first screen already has values
  _procs_sample "$state" cpu 0 0 1 0 > /dev/null; sleep 0.4
  local src='. "$PROCS_SELF"; '
  local R="${src}_procs_rows_cmd \"\$PROCS_STATE\""
  local L="${src}_procs_label \"\$PROCS_STATE\""
  local M="${src}_procs_meters \"\$PROCS_STATE\""
  local T="${src}_procs_toggle \"\$PROCS_STATE\""
  local pw='right,40%,border-rounded,wrap'
  [ "$(tput cols 2>/dev/null || echo 120)" -lt 110 ] && pw="$pw,hidden"   # narrow: ctrl-p / ctrl-t / ctrl-o / ? bring it up
  _procs_rows_cmd "$state" | fzf --ansi --multi --layout reverse --no-sort --track --id-nth 1,2 --header-lines 1 \
    --delimiter '\t' --with-nth 3 --with-shell 'bash -c' --pointer '▌' --marker '●' --gutter ' ' \
    --color 'border:8,label:6:bold,preview-border:8,preview-label:6:bold,header:-1,info:8,separator:8,scrollbar:8,footer:8' \
    --color 'prompt:6:bold,pointer:5,marker:5,hl:3:bold,hl+:3:bold,fg+:-1:bold,bg+:236,query:-1:bold' \
    --border rounded --border-label "$(_procs_label "$state")" --border-label-pos 3 \
    --header "$(_procs_meters "$state")" \
    --preview "${src}_procs_info {4}" --preview-label ' info ' \
    --preview-window "$pw" \
    --prompt '  filter › ' --info inline-right \
    --footer 'enter kill · tab select · space pause · ctrl-k signal · ctrl-s sort · ctrl-g group · ctrl-u mine · ? keys' \
    --bind "start,every(2):transform-header($M)+transform-border-label($L)+reload-sync($R)" \
    --bind "space:execute-silent($T pause)+transform-border-label($L)" \
    --bind "ctrl-r:reload-sync($R)" \
    --bind "ctrl-s:execute-silent($T sort)+transform-border-label($L)+reload-sync($R)" \
    --bind "ctrl-g:execute-silent($T group)+transform-border-label($L)+reload-sync($R)" \
    --bind "ctrl-u:execute-silent($T mine)+transform-border-label($L)+reload-sync($R)" \
    --bind "ctrl-t:change-preview-label( tree )+change-preview(${src}_procs_tree {4})+show-preview" \
    --bind "ctrl-o:change-preview-label( info )+change-preview(${src}_procs_info {4})+show-preview" \
    --bind "?:change-preview-label( keys )+change-preview(${src}_procs_keys)+show-preview" \
    --bind "enter:execute(${src}_procs_kill_ui TERM {+4})+reload-sync($R)" \
    --bind "ctrl-k:execute(${src}_procs_signal_pick {+4})+reload-sync($R)" \
    --bind 'tab:toggle+down' --bind 'ctrl-p:toggle-preview' --bind 'shift-up:preview-up,shift-down:preview-down' > /dev/null
  rm -rf "$sd"
  unset PROCS_SELF PROCS_STATE PROCS_SUDO PROCS_YES
  return 0
}

# Static fzf flow for fzf builds without the HUD options: no auto-refresh, kill on exit.
_procs_interactive_legacy() {
  local use_sudo="$1" assume_yes="$2" picked sd state
  sd=$(mktemp -d "${TMPDIR:-/tmp}/procs.XXXXXX") || return 1
  state="$sd/s"; mkdir -p "$state"
  _procs_state_init "$state"
  export PROCS_SELF="$_PROCS_SELF" PROCS_STATE="$state"
  _procs_sample "$state" cpu 0 0 1 0 > /dev/null; sleep 0.4
  local rel='bash -c '"'"'. "$PROCS_SELF"; _procs_rows_cmd "$PROCS_STATE"'"'"
  local tog='bash -c '"'"'. "$PROCS_SELF"; _procs_toggle "$PROCS_STATE" '
  picked=$(_procs_rows_cmd "$state" | fzf -m --ansi --reverse --header-lines=1 \
    --delimiter="$(printf '\t')" --with-nth=3 --height=80% \
    --prompt="procs > " \
    --header="TAB/SPACE select · ENTER kill · ctrl-r refresh · ctrl-s cpu↔mem · ctrl-g group · ctrl-u mine/all" \
    --bind="space:toggle" \
    --bind="ctrl-r:reload($rel)" \
    --bind="ctrl-s:execute-silent(${tog}sort')+reload($rel)" \
    --bind="ctrl-g:execute-silent(${tog}group')+reload($rel)" \
    --bind="ctrl-u:execute-silent(${tog}mine')+reload($rel)" \
    --preview-window=right:50%:wrap \
    --preview='bash -c '"'"'. "$PROCS_SELF"; _procs_info {4}'"'")
  rm -rf "$sd"
  unset PROCS_SELF PROCS_STATE
  [ -n "$picked" ] || { echo "Nothing selected."; return 0; }
  printf '%s\n' "$picked" | _procs_lines_to_targets | _procs_do_kill "$use_sudo" "$assume_yes"
}

_procs_interactive() {
  local use_sudo="$1" assume_yes="$2"
  if command -v fzf > /dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    if _procs_fzf_modern; then
      _procs_interactive_hud "$use_sudo" "$assume_yes"
    else
      _procs_interactive_legacy "$use_sudo" "$assume_yes"
    fi
  else
    local tab rows idx=0 sel num sd
    tab=$(printf '\t')
    sd=$(mktemp -d "${TMPDIR:-/tmp}/procs.XXXXXX") || return 1
    _procs_sample "$sd" cpu 0 0 1 0 > /dev/null; sleep 0.3
    rows=$(_procs_sample "$sd" cpu 0 0 20 0 | tail -n +2)
    rm -rf "$sd"
    [ -n "$rows" ] || { echo "No processes."; return 0; }
    printf '\n=== Top processes by CPU ===\n\n'
    while IFS= read -r line; do
      idx=$((idx + 1)); printf '  [%2d] %s\n' "$idx" "$(printf '%s\n' "$line" | cut -f3)"
    done <<EOF
$rows
EOF
    printf '\nNumbers to kill (space-separated, empty = cancel): '
    read -r sel
    [ -n "$sel" ] || { echo "Cancelled."; return 0; }
    printf '%s\n' "$sel" | tr ' ' '\n' | while IFS= read -r num; do
      case "$num" in "" | *[!0-9]*) continue ;; esac
      printf '%s\n' "$rows" | sed -n "${num}p"
    done | _procs_lines_to_targets | _procs_do_kill "$use_sudo" "$assume_yes"
  fi
}

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------

_procs_help() {
  cat <<'EOF'
procs — live process viewer, select, kill

  procs                              interactive (live fzf HUD, or numbered menu)
  procs list [--mem] [-n N] [--group]  show top processes (default: CPU, 30)
  procs kill [--sudo] [-y] <pid>...  TERM, then KILL after $PROCS_TERM_TIMEOUT (3s)

Safety: pid 1, kernel threads and your own shell chain are never killed;
a PID reused since selection is skipped; other users' processes (grey) need --sudo.
Interactive keys: enter kill · tab select · space pause · ctrl-k signal picker ·
  ctrl-s cpu↔mem · ctrl-g group · ctrl-u mine/all · ctrl-t tree · ctrl-o info · ctrl-p preview · ? keys
Env: PROCS_FZF_FORCE_LEGACY=1 static fzf flow · PROCS_ROWS (viewer rows, 1000)
EOF
}

procs() {
  local sub="${1:-}" use_sudo=0 assume_yes=0 sortby=cpu group=0 n="$PROCS_TOP_N" p
  case "$sub" in
    -h | --help | help) _procs_help ;;
    list)
      shift
      while [ $# -gt 0 ]; do
        case "$1" in
          --mem) sortby=mem ;;
          --group) group=1 ;;
          -n) shift; n="${1:-$PROCS_TOP_N}" ;;
          *) echo "procs list: unknown option $1" >&2; return 2 ;;
        esac
        shift
      done
      local sd color=0
      sd=$(mktemp -d "${TMPDIR:-/tmp}/procs.XXXXXX") || return 1
      [ -t 1 ] && color=1
      _procs_sample "$sd" "$sortby" "$group" 0 1 0 > /dev/null; sleep 0.3
      _procs_sample "$sd" "$sortby" "$group" 0 "$n" "$color" | awk -F'\t' '{print $3}'
      rm -rf "$sd"
      ;;
    kill)
      shift
      local pidlist=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --sudo) use_sudo=1 ;;
          -y | --yes) assume_yes=1 ;;
          *[!0-9]* | "") echo "procs kill: bad pid '$1'" >&2; return 2 ;;
          *) pidlist="$pidlist $1" ;;
        esac
        shift
      done
      [ -n "$pidlist" ] || { echo "procs kill: no pids" >&2; return 2; }
      printf '%s\n' "$pidlist" | tr ' ' '\n' | while IFS= read -r p; do
        [ -n "$p" ] || continue
        _procs_alive "$p" || { echo "  $p: no such process" >&2; continue; }
        printf '%s %s\n' "$p" "$(_procs_start "$p")"
      done | _procs_do_kill "$use_sudo" "$assume_yes"
      ;;
    "" | --sudo | -y | --yes)
      while [ $# -gt 0 ]; do
        case "$1" in --sudo) use_sudo=1 ;; -y | --yes) assume_yes=1 ;; esac
        shift
      done
      _procs_interactive "$use_sudo" "$assume_yes"
      ;;
    *) echo "procs: unknown command '$sub' (try --help)" >&2; return 2 ;;
  esac
}
