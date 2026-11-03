#!/usr/bin/env bash
# procs — top CPU/memory processes, multi-select, safe kill.
#
#   procs                         interactive (fzf; numbered menu fallback)
#   procs list [--mem] [-n N] [--group]
#   procs kill [--sudo] [-y] <pid>...
#
# Sourced into bash and zsh: no zsh special var names (path, status, commands, signals ...).
# Env: PROCS_TERM_TIMEOUT (default 3s before SIGKILL), PROCS_TOP_N (default 30 rows).

: "${PROCS_TERM_TIMEOUT:=3}"
: "${PROCS_TOP_N:=30}"

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
  s=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
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

# _procs_kill_checked <pid> <start> <sudo 0|1>
_procs_kill_checked() {
  local target="$1" want="$2" use_sudo="${3:-0}" cur sig i ticks
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
  for sig in TERM KILL; do
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
# Rows
# ------------------------------------------------------------------------------

# _procs_starts_csv "p1,p2" -> "s1,s2"
_procs_starts_csv() {
  local out="" p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    out="${out:+$out,}$(_procs_start "$p")"
  done <<EOF
$(printf '%s\n' "$1" | tr ',' '\n')
EOF
  printf '%s\n' "$out"
}

# _procs_rows <cpu|mem> <0|1 group> <N>
# Output: header + rows "pids<TAB>starts<TAB>display" (pids/starts comma lists).
_procs_rows() {
  local sortby="${1:-cpu}" group="${2:-0}" n="${3:-$PROCS_TOP_N}" tab pids usr c m r cmd starts lock
  tab=$(printf '\t')
  printf 'PIDS\tSTARTS\t%-12s %6s %6s %7s  %s\n' USER 'CPU%' 'MEM%' RSS COMMAND
  {
    if [ "$sortby" = cpu ]; then
      LC_ALL=C top -bn2 -d0.5 -w512 2>/dev/null |
        awk '/^ *PID /{f++; next} f==2 && $1 ~ /^[0-9]+$/ && $12 != "top" {print $1, $9}'
    else
      echo "0 0"
    fi
  } > "${TMPDIR:-/tmp}/.procs.cpu.$$"
  ps -eww -o pid=,user:32=,rss=,pmem=,args= 2>/dev/null |
    awk -v mode="$sortby" -v g="$group" -v me="${USER:-}" -v cpufile="${TMPDIR:-/tmp}/.procs.cpu.$$" '
      BEGIN { while ((getline l < cpufile) > 0) { split(l, a, " "); cpu[a[1]] = a[2] } }
      {
        pid=$1; usr=$2; rss=$3; pm=$4; cmd=$5; for (i=6;i<=NF;i++) cmd=cmd" "$i
        k=split($5, pp, "/"); comm=pp[k]
        c = (pid in cpu) ? cpu[pid] : 0
        if (g != 1) { printf "%s\t%s\t%s\t%s\t%s\t%s\n", pid, usr, c, pm, rss, cmd; next }
        if (!(comm in cnt)) { order[++no]=comm; u[comm]=usr; pl[comm]=pid } else { pl[comm]=pl[comm]","pid; if (u[comm]!=usr) u[comm]="mixed" }
        cnt[comm]++; sc[comm]+=c; sm[comm]+=pm; sr[comm]+=rss
      }
      END { if (g == 1) for (j=1;j<=no;j++) { cm=order[j]; printf "%s\t%s\t%.1f\t%.1f\t%d\t%s (x%d)\n", pl[cm], u[cm], sc[cm], sm[cm], sr[cm], cm, cnt[cm] } }
    ' |
    if [ "$sortby" = cpu ]; then sort -t "$tab" -k3,3nr -k5,5nr; else sort -t "$tab" -k5,5nr; fi |
    head -n "$n" |
    while IFS="$tab" read -r pids usr c m r cmd; do
      lock=""
      if [ "$usr" != "${USER:-}" ]; then lock="🔒 "; fi
      starts=$(_procs_starts_csv "$pids")
      [ "$sortby" = mem ] && [ "$group" != 1 ] && c="-"
      [ "$sortby" = mem ] && [ "$group" = 1 ] && c="-"
      printf '%s\t%s\t%-12.12s %6s %6s %6sM  %s%.110s\n' "$pids" "$starts" "$usr" "$c" "$m" "$((r / 1024))" "$lock" "$cmd"
    done
  rm -f "${TMPDIR:-/tmp}/.procs.cpu.$$"
}

# State file "<cpu|mem> <0|1>" for the fzf session.
_procs_rows_state() {
  local sortby group
  read -r sortby group < "$1"
  _procs_rows "$sortby" "$group"
}

_procs_toggle() {
  local sortby group
  read -r sortby group < "$1"
  case "$2" in
    sort) [ "$sortby" = cpu ] && sortby=mem || sortby=cpu ;;
    group) [ "$group" = 1 ] && group=0 || group=1 ;;
  esac
  printf '%s %s\n' "$sortby" "$group" > "$1"
}

# ------------------------------------------------------------------------------
# Kill flow
# ------------------------------------------------------------------------------

# _procs_do_kill <sudo> <yes> ; targets "pid start" on stdin (one per line)
_procs_do_kill() {
  local use_sudo="$1" assume_yes="$2" targets line p s ans total=0 failed=0
  targets=$(cat)
  [ -n "$targets" ] || { echo "Nothing selected."; return 0; }
  echo "Targets:"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    p=${line%% *}
    printf '  %s  %s\n' "$p" "$(ps -o user=,args= -p "$p" 2>/dev/null | cut -c1-100)"
    total=$((total + 1))
  done <<EOF
$targets
EOF
  if [ "$assume_yes" != 1 ]; then
    printf 'Kill %s process(es)? [y/N] ' "$total"
    read -r ans < /dev/tty 2>/dev/null || read -r ans
    case "$ans" in y | Y | yes) ;; *) echo "Cancelled."; return 0 ;; esac
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    p=${line%% *}; s=${line#* }
    _procs_kill_checked "$p" "$s" "$use_sudo" || failed=$((failed + 1))
  done <<EOF
$targets
EOF
  [ "$failed" -eq 0 ]
}

# fzf output lines -> "pid start" lines
_procs_lines_to_targets() {
  local line pids starts tab
  tab=$(printf '\t')
  while IFS="$tab" read -r pids starts _; do
    [ -n "$pids" ] || continue
    awk -v a="$pids" -v b="$starts" 'BEGIN{n=split(a,x,",");split(b,y,",");for(i=1;i<=n;i++)print x[i], y[i]}'
  done
}

_procs_interactive() {
  local use_sudo="$1" assume_yes="$2" picked state
  if command -v fzf >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    state=$(mktemp "${TMPDIR:-/tmp}/procs.state.XXXXXX") || return 1
    echo "cpu 0" > "$state"
    export PROCS_SELF="$_PROCS_SELF" PROCS_STATE="$state"
    local rel='bash -c '"'"'. "$PROCS_SELF"; _procs_rows_state "$PROCS_STATE"'"'"
    local tog='bash -c '"'"'. "$PROCS_SELF"; _procs_toggle "$PROCS_STATE" '
    picked=$(_procs_rows_state "$state" | fzf -m --reverse --header-lines=1 \
      --delimiter="$(printf '\t')" --with-nth=3 --height=80% \
      --prompt="procs > " \
      --header="TAB/SPACE select · ENTER kill · ctrl-r refresh · ctrl-s cpu↔mem · ctrl-g group · 🔒 other user" \
      --bind="space:toggle" \
      --bind="ctrl-r:reload($rel)" \
      --bind="ctrl-s:execute-silent(${tog}sort')+reload($rel)" \
      --bind="ctrl-g:execute-silent(${tog}group')+reload($rel)" \
      --preview-window=right:50%:wrap \
      --preview='p={1}; p=${p%%,*}; grep -E "^(Name|State|Threads|VmRSS|Uid):" /proc/$p/status 2>/dev/null; echo; tr "\0" " " < /proc/$p/cmdline 2>/dev/null')
    rm -f "$state"
    unset PROCS_SELF PROCS_STATE
    [ -n "$picked" ] || { echo "Nothing selected."; return 0; }
    printf '%s\n' "$picked" | _procs_lines_to_targets | _procs_do_kill "$use_sudo" "$assume_yes"
  else
    local tab rows idx=0 sel num pids starts
    tab=$(printf '\t')
    rows=$(_procs_rows cpu 0 20 | tail -n +2)
    [ -n "$rows" ] || { echo "No processes."; return 0; }
    printf '\n=== Top processes by CPU ===\n\n'
    while IFS="$tab" read -r pids starts disp; do
      idx=$((idx + 1)); printf '  [%2d] %s\n' "$idx" "$disp"
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
procs — top CPU/memory processes, select, kill

  procs                              interactive (fzf, or numbered menu)
  procs list [--mem] [-n N] [--group]  show top processes (default: CPU, 30)
  procs kill [--sudo] [-y] <pid>...  TERM, then KILL after $PROCS_TERM_TIMEOUT (3s)

Safety: pid 1, kernel threads and your own shell chain are never killed;
a PID reused since selection is skipped; other users' processes (🔒) need --sudo.
Interactive keys: space/TAB select · enter kill · ctrl-r refresh · ctrl-s cpu↔mem · ctrl-g group
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
      _procs_rows "$sortby" "$group" "$n" | awk -F'\t' '{print $3}'
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
