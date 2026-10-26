#!/bin/bash
# Unified session data for agent-resume (code.bash):
#   unified-sessions.sh list <scope> [TEXT] [agent_filter]
#   unified-sessions.sh preview <file> [TEXT]
#   unified-sessions.sh key <scope|mode|agent|change>

claude_sessions="$HOME/.terminal/claude/sessions.sh"
agy_sessions="$HOME/.terminal/antigravity/sessions.sh"

# ------------------------------------------------------------------------------
# 1. Preview Router
# ------------------------------------------------------------------------------
if [[ "$1" == preview ]]; then
  file="$2"
  if [[ "$file" == *"antigravity-cli"* || "$file" == *"-4"* && "$file" == *".db"* ]]; then
    exec bash "$agy_sessions" preview "$file" "$3"
  else
    exec bash "$claude_sessions" preview "$file" "$3"
  fi
fi

# ------------------------------------------------------------------------------
# 2. Key Actions (Scope, Mode, Agent Filter)
# ------------------------------------------------------------------------------
if [[ "$1" == key ]]; then
  scope=here; [[ "$FZF_PROMPT" == All* ]] && scope=all
  text=; [[ "$FZF_PROMPT" == *text* ]] && text=1

  # Agent filter from prompt prefix: "All", "Claude", "Antigravity"
  agent=all
  [[ "$FZF_PROMPT" == *\[Claude\]* ]] && agent=claude
  [[ "$FZF_PROMPT" == *\[Agy\]* ]] && agent=antigravity

  case "$2" in
    scope) if [[ $scope == all ]]; then scope=here; else scope=all; fi ;;
    mode) if [[ $text ]]; then text=; else text=1; fi ;;
    agent)
      case "$agent" in
        all) agent=claude ;;
        claude) agent=antigravity ;;
        antigravity) agent=all ;;
      esac
      ;;
    change) [[ $text ]] || exit 0 ;;
  esac

  label='This dir'; [[ $scope == all ]] && label=All
  if [[ "$agent" == "claude" ]]; then
    label="$label [Claude]"
  elif [[ "$agent" == "antigravity" ]]; then
    label="$label [Agy]"
  fi

  if [[ $text ]]; then
    echo "change-prompt($label text> )+disable-search+reload(bash $0 list $scope {q} $agent)+refresh-preview"
  else
    echo "change-prompt($label> )+enable-search+reload(bash $0 list $scope '' $agent)+refresh-preview"
  fi
  exit 0
fi

# ------------------------------------------------------------------------------
# 3. List Mode: Merge & Sort
# ------------------------------------------------------------------------------
scope="${2:-here}"
query="$3"
agent_filter="${4:-all}"

python3 -I -c '
import subprocess, os, sys, signal
try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except Exception:
    pass

scope = sys.argv[1]
query = sys.argv[2]
agent_filter = sys.argv[3]
claude_sh = sys.argv[4]
agy_sh = sys.argv[5]

rows = []

if agent_filter in ("all", "claude") and os.path.isfile(claude_sh):
    cmd = ["bash", claude_sh, "list", scope]
    if query: cmd.append(query)
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
        for line in out.splitlines():
            if not line: continue
            parts = line.split("\t")
            if len(parts) >= 7:
                mtime = os.path.getmtime(parts[5]) if os.path.isfile(parts[5]) else 0
                parts[3] = "\033[33m[claude]\033[0m " + parts[3]
                rows.append((mtime, parts + ["claude"]))
    except Exception:
        pass

if agent_filter in ("all", "antigravity") and os.path.isfile(agy_sh):
    cmd = ["bash", agy_sh, "list", scope]
    if query: cmd.append(query)
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
        for line in out.splitlines():
            if not line: continue
            parts = line.split("\t")
            if len(parts) >= 7:
                mtime = os.path.getmtime(parts[5]) if os.path.isfile(parts[5]) else 0
                parts[3] = "\033[36m[agy]\033[0m    " + parts[3]
                rows.append((mtime, parts + ["antigravity"]))
    except Exception:
        pass

rows.sort(key=lambda x: x[0], reverse=True)
for _, r in rows:
    print("\t".join(r))
' "$scope" "$query" "$agent_filter" "$claude_sessions" "$agy_sessions"
