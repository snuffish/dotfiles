---
name: insights
description: Audits recent AI session transcripts for developer habits, tool usage, friction points, and recurring steering, generating an interactive HTML dashboard and project rule improvements.
---

# Skill: `/insights` — AI Workflow & Session Analytics

Generates a comprehensive diagnostic audit of developer workflows, tool metrics, friction points, and recurring steering across recent AI sessions. Emits a clean interactive HTML dashboard (matching Claude Code Insights styling) and an actionable markdown artifact with copyable rule recommendations.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-insights_report-<suffix>.md` and an interactive HTML report `insights_report.html`

---

## When to Use

Use `/insights` when you want to:
- Audit recent AI session habits, prompt patterns, and task distributions.
- Quantify tool reliability (shell command exit codes, file edit anchor mismatches, background tasks).
- Identify recurring friction (speculative search loops, state desync with remote PRs, commit granularity issues).
- Generate copyable, actionable additions for `~/.claude-mem/MY-RULES.md` and `AGENTS.md`.

---

## Step 1 — Run Metrics & Transcripts Extraction

1. Execute the analytics generator script from the skill's real directory:
   ```bash
   python3 "$(dirname "$(realpath "$0")")/scripts/generate_insights.py" --sessions 50 --outdir "$ARTIFACT_DIR"
   ```
   *(If `$ARTIFACT_DIR` is not set by the harness, output to `<workspace-root>/docs/insights/` or `<appDataDir>/brain/<conversation-id>/`)*.
2. The script computes:
   - Total user prompts, session counts, date spans, and prompts-per-day velocity.
   - Tool invocation distribution (`run_command`, `read_file`, `edit_file`, `manage_task`, `write_file`).
   - Command reliability and non-zero exit frequency.
   - User intent classification (e.g. `/create-prompt`, `/proceed`, `/investigate`, `/problem`, plain requests).

---

## Step 2 — Synthesize Friction Points & Project Rule Improvements

1. **Audit Repeated Interventions**: Review session logs for patterns where the user had to course-correct the assistant:
   - Monolithic vs. staged chunk commits.
   - Pre-flight checks on existing remote branches and open PRs.
   - Speculative filesystem traversals vs. targeted CodeGraph navigation.
   - Worktree isolation vs. in-place edits.
2. **Formulate High-Impact Rules**: Draft targeted, concise rules to resolve the identified friction points for:
   - `~/.claude-mem/MY-RULES.md` (universal developer preferences).
   - `AGENTS.md` / `CLAUDE.md` (repository-level operational constraints).

---

## Step 3 — Present Outputs & Gate Next Steps

1. **Artifact Delivery**: Write the synthesis into `<prefix>-insights_report-<suffix>.md` linking to the standalone interactive `insights_report.html` dashboard.
2. **Follow Artifact Protocol**: Do not dump the entire raw report into chat. Provide concise bullet highlights in chat pointing to the dashboard.
3. **Closing Gate**: Stop at `core` › *The `/proceed` gate*:
   > **Next Step Gate:** Reply `/proceed` (or "go ahead") to apply the recommended rule updates to `MY-RULES.md` and `AGENTS.md`, or specify scope/changes.
