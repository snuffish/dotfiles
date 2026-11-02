---
name: refine
description: "Audits existing, working code for odd behaviour, code smells and missed improvements, checked against the project's skills and against decisions recorded in past conversations, and proposes a refinement plan that waits for approval. Use for /refine, \"anything odd about this code?\", \"find code smells in X\", \"what would you improve here?\"."
argument-hint: "[<target>]"
---

# Skill: `/refine` — Code Refinement & Historical Alignment

Systematic workflow for auditing working code, finding odd behaviors or design/performance improvements, and checking every finding against past conversations and project skills before proposing a refinement plan.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-implementation_plan-<suffix>.md` (suffix from the target feature, file, or topic)
- `../_modules/git-worktrees.md`

---

## 1. When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Something is actually failing (build, lint, test, runtime) | [`/problem`](../problem/SKILL.md) |
| Single-file dead-code pruning | [`/clean`](../clean/SKILL.md) |
| Declarative rewrite of imperative code | [`/expressive`](../expressive/SKILL.md) |
| Moving files, splitting modules, reshaping folders | [`/organize`](../organize/SKILL.md) |
| Reviewing a branch diff against acceptance criteria | [`/code-review`](../code-review/SKILL.md) |
| Backend duplication across endpoints / validators / queries | `priis-backend-dry` |

---

## 2. Phase 1: Context & Conversation History Lookup

Before proposing a refinement, check commit history, claude-mem, and past conversation transcripts for the target files, symbols, or patterns per `core` › *Codebase investigation* › *Historical decisions* so the proposal does not undo a choice the user already made (e.g. a deliberate workaround, naming convention, or rejected package).

## 3. Phase 2: Delegating to Existing Skills (Guideline Reuse)

Take audit criteria from the project's rulebooks, Profiles, and References (`core` › *Precedence*) rather than inventing standalone rules:
- **Review axes & severities**: Reuse [`/code-review`](../code-review/SKILL.md) axes (**Correctness**, **Standards**, **Spec**) and severities (🔴 Critical, 🟡 Important, 🟢 Minor), plus its smell baseline (`../code-review/references/smell-baseline.md`).
- **Project & tech References**: Load the active References for the languages, frameworks, and layers touched (from the project profile's *References per layer*, repo `.claude/skills/`, and registry skills under `../` or `../Projects/`).

## 4. Phase 3: Formulating & Presenting the Refinement Plan (`/plan` Case B)

For each finding, record: **Problem / Odd Behavior**, **Historical Context / Skill Citation**, **Why it Matters**, and **Refined Solution**. Write `<prefix>-implementation_plan-<suffix>.md` at the workspace root via [`/plan`](../plan/SKILL.md) › *Case B* (using its skeleton, `Status` values, self-review, and link block). Wait at `core` › _The `/proceed` gate_ before modifying any workspace files.
