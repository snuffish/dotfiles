# Skill registry, hook and agent-tooling commands from skills/, claude/ and utils/. Every recipe runs from the repository root.

set working-directory := '..'

python := 'python3 -I'

# List the recipes
default:
    @{{just_executable()}} --justfile {{justfile()}} --list --unsorted

# Run the drift check and every test suite
ci: drift test

# Report loader and config links (check only); pass --targets, --config-only or --registry through
sync *args:
    {{python}} skills/sync-skills/sync_skills.py {{args}}

# Fix the loader and config links: `just agents sync-apply --targets claude`
sync-apply *args:
    {{python}} skills/sync-skills/sync_skills.py --apply {{args}}

# Check the skills' claims against the code; pass --file '<glob>', --project <name>, --json, --strict, --mcp or --update-stale through
drift *args:
    {{python}} skills/skill-drift/scripts/check_skill_drift.py {{args}}

# List the logged skill gaps; pass --json or --dir <folder> through
gaps *args:
    {{python}} skills/skill-gap/scripts/list_gaps.py {{args}}

# Check that skills/simplify mirrors Claude Code's built-in /simplify
simplify-mirror *args:
    {{python}} skills/simplify/scripts/check_native_mirror.py {{args}}

# Run the hook, worktree and /proceed runner tests
test:
    {{python}} claude/test_safety_guard.py
    {{python}} claude/test_session_look.py
    {{python}} claude/test_wt.py
    {{python}} claude/test_plan_lint.py
    {{python}} skills/proceed/scripts/test_run_plan.py
    {{python}} skills/on-snuffish-pc/scripts/test_on_pc.py

# Run the adopr badge tests; two of them call the real az and need an Azure DevOps sign-in and default organization
test-adopr:
    python3 -m unittest utils/test_adopr_badge.py
