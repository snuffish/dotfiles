#!/bin/bash
# Focus the terminal/tmux window where process $1 is running

focus_pid() {
  local pid="$1" tty pane
  [[ -n "$pid" ]] || return 1
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Process $pid is no longer running." >&2
    return 1
  fi

  tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  if [[ -n "$tty" && -n "$TMUX" ]]; then
    # Exact tty match: pts/1 must not pick the pane on pts/10
    pane=$(tmux list-panes -a -F '#{pane_id} #{pane_tty}' 2>/dev/null | awk -v t="/dev/$tty" '$2 == t {print $1; exit}')
    if [[ -n "$pane" ]]; then
      # A pane target switches session, window and pane at once; select-pane alone stays in the current window
      tmux switch-client -t "$pane" 2>/dev/null
      # A suspended process isn't what the pane shows
      [[ "$(ps -o stat= -p "$pid" 2>/dev/null)" == *T* ]] &&
        echo "Process $pid is suspended in pane $pane, behind what is shown there; fg in that shell brings it back." >&2
    fi
  fi

  if [[ "$(uname)" == "Darwin" ]]; then
    if pgrep -x Ghostty >/dev/null 2>&1; then
      osascript -e 'tell application "Ghostty" to activate' 2>/dev/null
    elif pgrep -x iTerm2 >/dev/null 2>&1; then
      osascript -e 'tell application "iTerm2" to activate' 2>/dev/null
    elif pgrep -x WezTerm >/dev/null 2>&1; then
      osascript -e 'tell application "WezTerm" to activate' 2>/dev/null
    elif pgrep -x Terminal >/dev/null 2>&1; then
      osascript -e 'tell application "Terminal" to activate' 2>/dev/null
    fi
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  focus_pid "$1"
fi
