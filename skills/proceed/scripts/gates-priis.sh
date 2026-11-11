#!/usr/bin/env bash
# PRIIS gate stages for run-plan.sh. Usage: gates-priis.sh <format|tests|budget|drift> <base-ref>   (cwd: the worktree)
# Exit 0 pass, 3 not applicable (the last stdout line becomes a caveat), anything else fail.
set -uo pipefail

stage="${1:?stage}"
base="${2:?base ref}"
root="$(git rev-parse --show-toplevel)" || exit 1
cd "$root" || exit 1

mb="$(git merge-base "$base" HEAD)" || { echo "no merge base between $base and HEAD" >&2; exit 1; }
files="$({ git diff --name-only --diff-filter=d "$mb"; git ls-files -o --exclude-standard; } | sort -u)"
has() { printf '%s\n' "$files" | grep -q -e "$1"; }
skip() { echo "$1"; exit 3; }

UNIT_PROJECTS="GR.PRIIS.Library.UnitTests GR.PRIIS.API.UnitTests GR.PRIIS.ServiceDefaults.UnitTests GR.PRIIS.Worker.UnitTests GR.PRIIS.ArchitectureTests"
INTEGRATION="GR.PRIIS.API.IntegrationTests"
WEB="frontend/source/priis-web"

case "$stage" in
  format)
    ran=0
    if has '^backend/.*\.cs$'; then
      ran=1
      if command -v pwsh >/dev/null 2>&1; then
        pwsh -NoProfile -File backend/scripts/format-changed.ps1 -Base "$base" || exit 1
      else
        list=()
        while IFS= read -r f; do list+=("$f"); done < <(printf '%s\n' "$files" | grep -e '^backend/.*\.cs$')
        dotnet format backend/GR.PRIIS.Backend.slnx --include "${list[@]}" || exit 1
      fi
    fi
    if has "^frontend/"; then
      ran=1
      (cd "$WEB" && npm run organize-imports) || exit 1
    fi
    [ "$ran" = 1 ] || skip "format: no backend or frontend files changed"
    ;;
  tests)
    ran=0
    if has "^backend/"; then
      ran=1
      dotnet build backend/GR.PRIIS.Backend.slnx -c Release || exit 1
      for p in $UNIT_PROJECTS; do
        dotnet test --project "backend/tests/$p" -c Release --no-build || exit 1
      done
      if has "^backend/tests/$INTEGRATION/"; then
        docker info >/dev/null 2>&1 || { echo "integration tests changed but Docker is not running (they need the SQL container)" >&2; exit 1; }
        dotnet test --project "backend/tests/$INTEGRATION" -c Release --no-build || exit 1
      fi
    fi
    if has "^frontend/"; then
      ran=1
      (cd "$WEB" && npx tsc -b && npm run test:unit) || exit 1
    fi
    [ "$ran" = 1 ] || skip "tests: no backend or frontend files changed"
    ;;
  budget)
    [ -f backend/scripts/test-budget.py ] || skip "test-budget: backend/scripts/test-budget.py is not on this branch (chore/test-budget-gate, !19009)"
    has "^backend/" || skip "test-budget: no backend files changed"
    dotnet build backend/GR.PRIIS.Backend.slnx -c Release || exit 1
    python3 -I backend/scripts/test-budget.py || exit 1
    ;;
  drift)
    [ -f .claude/scripts/check_skill_drift.py ] || skip "drift: .claude/scripts/check_skill_drift.py is not on this branch"
    python3 -I .claude/scripts/check_skill_drift.py --no-fix || exit 1
    ;;
  *)
    echo "unknown stage: $stage" >&2
    exit 2
    ;;
esac
