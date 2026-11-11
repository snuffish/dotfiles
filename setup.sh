#!/usr/bin/env bash
# Recreates every ~/.terminal link (Claude Code, Gemini, ~/.local/bin) on macOS and Linux.
# Config links come from CONFIG_LINKS in skills/sync-skills/sync_skills.py; this wraps it and checks the result.
set -euo pipefail

TERMINAL="$HOME/.terminal"
TERMINAL_REAL="$(cd "$TERMINAL" && pwd -P)"
SYNC="$TERMINAL/skills/sync-skills/sync_skills.py"
CM_SYNC_SRC="$HOME/Projects/cm-sync/cm-sync"
fail=0
ok()   { printf '  ✓ %s\n' "$1"; }
warn() { printf '  ⚠ %s\n' "$1"; }
bad()  { printf '  ✗ %s\n' "$1"; fail=1; }

command -v python3 >/dev/null || { echo "✗ python3 not on PATH" >&2; exit 1; }
[ -f "$SYNC" ] || { echo "✗ $SYNC not found: clone the repo to ~/.terminal first" >&2; exit 1; }

echo "Settings"
settings="$HOME/.claude/settings.json"
if [ -f "$settings" ] && [ ! -L "$settings" ]; then
  if python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); from sync_skills import json_covers; sys.exit(0 if json_covers(sys.argv[2], sys.argv[3]) else 1)' \
      "$(dirname "$SYNC")" "$settings" "$TERMINAL/claude/settings.json"; then
    backup="$settings.bak-setup-$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$settings" "$backup"
    ok "real settings.json is covered by the repo copy; moved to $backup"
  else
    echo "✗ $settings has keys missing from $TERMINAL/claude/settings.json: merge them in by hand, then rerun" >&2
    exit 1
  fi
fi

plan_lint="$HOME/.claude/plan-lint.py"
if [ -L "$plan_lint" ]; then
  case "$(readlink "$plan_lint")" in
    "$TERMINAL"/*|"$TERMINAL_REAL"/*) rm "$plan_lint"; ok "removed stale $plan_lint link" ;;
  esac
fi

echo "Sync"
python3 -I "$SYNC" --apply || fail=1

echo "cm-sync"
if [ -f "$CM_SYNC_SRC" ]; then
  mkdir -p "$HOME/.local/bin"
  dest="$HOME/.local/bin/cm-sync"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    bad "$dest is a real file; move it away and rerun"
  else
    ln -sfn "$CM_SYNC_SRC" "$dest"
  fi
else
  warn "cm-sync not cloned: git clone git@github.com:snuffish/cm-sync.git ~/Projects/cm-sync"
fi

echo "quiet"
mkdir -p "$HOME/.local/bin"
if [ -e "$HOME/.local/bin/quiet" ] && [ ! -L "$HOME/.local/bin/quiet" ]; then
  bad "$HOME/.local/bin/quiet is a real file; move it away and rerun"
else
  ln -sfn "$TERMINAL/claude/quiet" "$HOME/.local/bin/quiet"
fi

echo "Links"
points_into_terminal() { [ -L "$1" ] && case "$(readlink "$1")" in "$TERMINAL"/*|"$TERMINAL_REAL"/*|claude/*) return 0 ;; esac; return 1; }
for link in ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/statusline.sh ~/.claude/agents \
            ~/.claude/session-title.sh ~/.gemini/GEMINI.md ~/.local/bin/sync-skills "$TERMINAL/AGENTS.md"; do
  if points_into_terminal "$link"; then ok "$link"; else bad "$link is not a link into ~/.terminal"; fi
done
if [ -f "$CM_SYNC_SRC" ]; then
  if [ -L "$HOME/.local/bin/cm-sync" ]; then ok "~/.local/bin/cm-sync"; else bad "~/.local/bin/cm-sync missing"; fi
fi
if [ -L "$HOME/.local/bin/quiet" ]; then ok "~/.local/bin/quiet"; else bad "~/.local/bin/quiet missing"; fi
skill_links=$(find "$HOME/.claude/skills" -maxdepth 1 -type l 2>/dev/null | wc -l)
if [ "$skill_links" -ge 1 ]; then ok "~/.claude/skills: $skill_links links"; else bad "~/.claude/skills has no links"; fi

echo "Workspaces"
for spec in "$TERMINAL"/skills/Projects/*/.workspaces; do
  [ -f "$spec" ] || continue
  while IFS= read -r ws; do
    case "$ws" in ''|'#'*) continue ;; esac
    ws="${ws/#\~/$HOME}"
    if [ -d "$ws" ]; then
      if [ -L "$ws/CLAUDE.local.md" ]; then ok "$ws/CLAUDE.local.md"; else bad "$ws/CLAUDE.local.md is not a link"; fi
    else
      warn "$ws not on this machine"
    fi
  done < "$spec"
done

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) warn '~/.local/bin is not on PATH: add export PATH="$HOME/.local/bin:$PATH" to your shell profile' ;;
esac

if [ "$fail" -eq 0 ]; then echo "✓ done"; else echo "✗ some checks failed"; exit 1; fi
