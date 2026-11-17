#!/usr/bin/env bash
# SessionStart hook: tell Claude which machine it is on and which Python uv resolves here,
# so it does not guess (Mac vs Snuffish-PC, a Python without torch wheels).
line="host=$(hostname -s)"
if command -v uv >/dev/null 2>&1; then
  py=$(uv python find 2>/dev/null) && line+=" uv-python=$py"
fi
echo "$line"
