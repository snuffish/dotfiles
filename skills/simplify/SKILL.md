---
name: simplify
description: "Review the changed code for reuse, simplification, efficiency, and altitude cleanups, then apply the fixes. Quality only — it does not hunt for bugs; use /code-review for that."
argument-hint: "[<target>]"
user-invocable: true
compatibility: antigravity
---

# Skill: `/simplify` — Quality Cleanup & Simplification

Reviews changed code for reuse, simplification, efficiency, and altitude issues, then fixes what it finds. Quality only — it does not hunt for correctness bugs (that is what [`/code-review`](../code-review/SKILL.md) is for).

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/fan-out.md`
- `../_modules/git-worktrees.md`

- **Direct fix authorization**: invoking `/simplify` authorizes editing the target changed code directly to apply the deduplicated cleanup fixes within the reviewed diff (no planning gate or `/proceed` required).
- **Blast radius**: edits stay strictly inside the reviewed diff and its immediate call sites. Any cleanup requiring changes well outside the reviewed diff is skipped and recorded in the summary.

---

## Invariants

1. **Quality only — no bug hunting**: Review strictly for code quality, reuse, simplification, efficiency, and altitude. Do not look for correctness bugs, regressions, or security vulnerabilities — route those to [`/code-review`](../code-review/SKILL.md).
2. **Zero behavior drift**: Fixes must strictly preserve existing runtime behavior, public API contracts, serialized schemas, and framework conventions. If a proposed cleanup risks changing behavior, skip it.
3. **Strict diff boundary**: Edits must stay within the reviewed diff and its immediate call sites. Never refactor untouched files or architectural layers outside the diff.
4. **Transparent skips**: Skip any finding whose fix would alter intended behavior, require changes well outside the reviewed diff, or is judged to be a false positive. Record every skip in the final summary rather than arguing.
5. **Mandatory post-edit verification**: Always run repository build, lint, type-check, and relevant test gates after applying edits (`core` › *Post-edit verification*). Fix any regressions immediately.
6. **Execution fidelity**: When subagents (the Agent tool) are available, launch all 4 review agents concurrently in a single message. When unavailable, execute single-pass inline cleanup covering all 4 angles in turn and state that explicitly in the summary.

---

## When not to use — pick the right neighbor

| Situation | Correct skill |
| --- | --- |
| Hunting for bugs, regressions, security flaws, or spec compliance | [`/code-review`](../code-review/SKILL.md) |
| Pruning dead code, unused exports, dead locals, or debug remnants in a file | [`/clean`](../clean/SKILL.md) |
| Declarative rewrites (lookup tables, guard clauses, domain predicates) | [`/expressive`](../expressive/SKILL.md) |
| Reorganizing directories, splitting files, or realigning namespaces | [`/organize`](../organize/SKILL.md) |
| Auditing existing working code against historical decisions and team skills | [`/refine`](../refine/SKILL.md) |
| Eliminating duplicated queries, validators, or endpoints in PRIIS backend | `priis-backend-dry` |

---

## Phase 0 — Gather the Diff

1. **Target resolution**:
   - If an argument is provided (`Review target: <target>`), resolve `<target>` (a branch name, PR number/URL, commit range, or specific file path) and diff against its base.
   - Otherwise, run:
     ```bash
     git diff @{upstream}...HEAD
     ```
     (or `git diff main...HEAD` / `git diff HEAD~1` if there is no upstream) to get the unified diff under review.
2. **Include working-tree changes**:
   - If there are uncommitted changes, or the range diff is empty, also run:
     ```bash
     git diff HEAD
     ```
     and include working-tree changes in scope — the review often runs before committing.
3. Treat this combined diff as the review scope.

---

## Phase 1 — Review (4 Cleanup Angles)

Review the diff across the four cleanup angles defined below. Choose Branch A or Branch B based on tool availability.

### Branch A: When the Agent tool is available
`/simplify → 4 cleanup agents in parallel → apply the fixes`

Launch **4 independent review agents** via the Agent tool (`invoke_subagent` / `Agent`), all in a single message so they run concurrently:
- Agent 1: **Reuse**
- Agent 2: **Simplification**
- Agent 3: **Efficiency**
- Agent 4: **Altitude**

Pass each agent the diff and its assigned angle below. Each agent returns its findings with:
- `file`
- `line`
- a one-line `summary`
- the `concrete cost` (what is duplicated, wasted, or harder to maintain)

### Branch B: When the Agent tool is not available
`/simplify → Agent tool unavailable → single-pass inline cleanup → apply the fixes`

The Agent tool isn't available in this context, so the usual 4-agent fan-out can't run. Work through all four angles below yourself, in this same context, in one pass — do not skip an angle for lack of fan-out.

Review the diff against each angle below in turn. For each, note findings with `file`, `line`, a one-line `summary`, and the `concrete cost` (what is duplicated, wasted, or harder to maintain).

---

### The Four Cleanup Angles

#### Angle 1: Reuse
Flag new code that re-implements something the codebase already has — Grep shared/utility modules and files adjacent to the change, and name the existing helper to call instead.

#### Angle 2: Simplification
Flag unnecessary complexity the diff adds: redundant or derivable state, copy-paste with slight variation, deep nesting, dead code left behind. Name the simpler form that does the same job.

#### Angle 3: Efficiency
Flag wasted work the diff introduces: redundant computation or repeated I/O, independent operations run sequentially, blocking work added to startup or hot paths. Also flag long-lived objects built from closures or captured environments — they keep the entire enclosing scope alive for the object's lifetime (a memory leak when that scope holds large values); prefer a class/struct that copies only the fields it needs. Name the cheaper alternative.

#### Angle 4: Altitude
Check that each change fixes the root cause at the right depth rather than patching a symptom with a fragile bandaid. Special cases layered on shared infrastructure are a sign the fix isn't deep enough — prefer the simpler, more general change to the underlying mechanism over adding special cases, and name that change.

---

## Phase 2 — Apply the Fixes

1. **Deduplicate**:
   Wait for all four agents to complete (or finish the inline pass). Deduplicate findings that point at the same line or mechanism, preserving the clearest summary and concrete cost.
2. **Filter & Triage**:
   Examine each candidate finding and determine whether to fix or skip:
   - **Skip if behavior changes**: Skip any finding whose fix would alter intended runtime behavior, breaking edge cases, or public contracts.
   - **Skip if out of scope**: Skip any finding requiring changes well outside the reviewed diff.
   - **Skip if false positive**: Skip any finding based on invalid assumptions or misreading existing guards.
   - Note the skip rather than arguing with it.
3. **Apply the fixes**:
   Fix each remaining deduplicated finding directly in the code using surgical, precise edits.
4. **Post-edit verification**:
   Run the repository's build, linter, type-check, and relevant test suite (`core` › *Post-edit verification*). Resolve any regressions before finishing.
5. **Summary report**:
   Finish with a brief summary in chat:
   - State clearly whether this was executed via **4-agent parallel fan-out** or a **single-pass review done without the Agent tool** (so whoever reads it isn't misled about what actually ran).
   - **Applied fixes**: list of `file:line — <summary>` and the concrete cost resolved.
   - **Skipped findings**: list of `file:line — <summary>` and the reason for skipping (`behavior change`, `outside diff`, or `false positive`).
   - (Or confirm the code was already clean).
