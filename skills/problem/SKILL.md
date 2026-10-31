---
name: problem
description: "Diagnoses something that is failing now: an error message, a failing build, lint or test, a crash, or behaviour that \"stopped working\", often after a recent change. Audits git status and recent commits, logs, the active files and past conversation transcripts, finds the root cause, writes a fix plan and fixes only after approval. Use for /problem, \"this is broken\", \"why does this fail?\", \"I get this error\", \"the tests fail after your change\"."
---

# Skill: `/problem` — Troubleshooting, Diagnostics & Context Recovery

Use this skill whenever the user reports an error (compiler error, lint error, failing test, runtime exception, logic bug) or states that something in a previous implementation is not working.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-implementation_plan-<suffix>.md` (suffix from the error, ticket, or bug description, e.g. `-fix-audit-review`, `-auth-token-failure`)
- `../_modules/git-worktrees.md`

---

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| The failure is in the PR's CI pipeline, not local | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |
| Nothing is failing — the code just smells, or past decisions need re-aligning | [`/refine`](../refine/SKILL.md) |
| Research before deciding how to change something | [`/investigate`](../investigate/SKILL.md) |
| Dead code, unused exports, leftover debug statements in one file | [`/clean`](../clean/SKILL.md) |

---

## Step 1 — Analyze the Symptom & Scope

1. **Logs & Output**: Read the compilation logs, test failures, console messages, or stack traces provided by the user.
2. **Key Identifiers**: Extract the filenames, line numbers, classes, functions, variable names, or database tables involved.
3. **Classification**: Classify as a build error (compile/lint), test assertion failure, database/schema conflict, or runtime exception.

## Step 2 — Audit Current Workspace State (Git Delta)

1. **Unstaged & Staged Changes**: Run `git status`, `git diff`, and `git diff --staged` to see what was recently added, changed, or deleted.
2. **Recent Commits**: Run `git log -n 5` to inspect recent commits on this branch that may have introduced the issue.

## Step 3 — Historical Context & Cross-Layer Verification

Follow `core` › *Codebase investigation* (*Historical decisions* and *Cross-Layer Mapping*):
- When the failure traces to an earlier change, find the commit or conversation turn that introduced it (`git log -S'<symbol>'`, claude-mem, or host transcripts per `core` › *Codebase investigation* › *Historical decisions*) and reconstruct the original request, approved plan, and assumptions.
- Verify symbol definitions and structural mismatches across layers (`core` › *Codebase investigation* › *Cross-Layer Mapping*): API/DTO field names, casing and types (`Guid` vs `number`), client validation schema vs domain entity rules, and imports/path aliases against the project's Profile and References.

## Step 4 — Root Cause Analysis & Fix Plan (`/plan` Case B)

Consolidate findings (Symptom, Root Cause, Historical Decision, Proposed Fix) and write `<prefix>-implementation_plan-<suffix>.md` via [`/plan`](../plan/SKILL.md) › *Case B* (using its skeleton, `Status` values, self-review, and link block). Wait at `core` › *The `/proceed` gate* before editing any workspace files, then run `core` › *Post-edit verification* once approved.
