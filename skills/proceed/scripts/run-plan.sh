#!/usr/bin/env bash
# Autonomous phase runner. Usage: run-plan.sh <plan.md> [--handoff H.md] [--base REF] [--resume] [--max-phases N] [--dry-run]
# Thin on purpose (bash 3.2 and Linux alike): the logic lives in run_plan.py. See its docstring for the exit codes.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || { echo "run-plan: python3 not found" >&2; exit 2; }
if [ -z "${RUN_PLAN_CLAUDE:-}" ]; then
  command -v claude >/dev/null 2>&1 || { echo "run-plan: claude not found on PATH" >&2; exit 2; }
fi
[ "$#" -ge 1 ] || { echo "usage: run-plan.sh <plan.md> [options]" >&2; exit 2; }

here="$(python3 -I -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")"
exec python3 -I "$here/run_plan.py" "$@"
