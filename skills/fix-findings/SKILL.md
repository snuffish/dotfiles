---
name: fix-findings
description: 'Fixes a review findings document in parallel: graphs dependencies between findings, proposes batches and waits for /proceed, then runs one worktree and sub-agent per independent finding that implements only it, builds, runs covering tests and writes RESULT.json (GREEN, RED, BLOCKED_ENV). Cherry-picks only GREEN fixes onto the PR branch in dependency order, runs the full suite once, pushes, and hands off the rest. Invoking it authorizes those commits and the push. Use for /fix-findings, "fix the review findings in parallel". Not for reviewing (use /code-review), serial review-then-fix (use /pr-polish) or CI failures (use /pr-fix-pipeline).'
argument-hint: "<findings doc> [--pr <id | branch>] [--only <ids>]"
disable-model-invocation: true
---

# Skill: `/fix-findings` — Parallel Fixes from a Findings Document

Turns a review findings document into landed fixes: one isolated worktree and sub-agent per independent finding, merged back only when green. The deliverables are the cherry-picked commits on the PR branch, the push, and a handoff artifact for every finding that did not land.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed` for Steps 1–2; the gate opens one batch at a time
- `../_modules/artifact-protocol.md`: writes `<prefix>-handoff-<suffix>.md` only when a finding did not land
- `../_modules/git-worktrees.md`: workspace mode, one worktree **per finding** (exception to _Golden Invariants_ 4, see invariant 3 below)
- `../_modules/project-profile.md`: build, test, include-list and hydration fields come from the base profile
- `../_modules/pr-host.md`: only to resolve the PR from a branch
- `../_modules/outward-writes.md`

On-demand references (`references/`):

- [`references/agent-brief.md`](references/agent-brief.md) — the sub-agent brief and the `RESULT.json` schema
- [`references/landing-and-handoff.md`](references/landing-and-handoff.md) — cherry-pick order, conflict handling, full-suite gate, worktree removal and the handoff template

> [!CAUTION]
> **Golden invariants**
>
> 1. **Never land a finding that did not report GREEN.** Only a `RESULT.json` with `"status": "GREEN"`, `tests_run > 0` and `tests_failed == 0` qualifies. A missing, unparsable or contradictory `RESULT.json` counts as RED.
> 2. **Invocation is the explicit request** (`outward-writes` › _Explicit request & draft mode_) for: commits on `fix/finding-<id>` branches, cherry-picks onto the PR's source branch, and one `git push` of that branch per batch. Never force-push, rebase the PR branch, post PR comments or touch another PR.
> 3. **One worktree per finding, created and removed by the lead only.** Sub-agents never create, remove, lock or unlock worktrees, and each works only inside its own `repo-root`.
> 4. **Never delete a `fix/finding-<id>` branch** (`git-worktrees` › _Golden Invariants_ 6). RED and BLOCKED branches are the handoff's repro starting point.
> 5. **At most 5 sub-agents per batch.** A larger independent set is split into several batches.
> 6. **Shared local services are serialized.** Worktrees isolate files, not the base profile's **Shared local services** (local database, local API, dev-server ports). Test runs that use one take turns behind a lock (agent brief rule 4), so a collision never turns a good fix RED or BLOCKED_ENV.

---

## 1. When _not_ to use

| Situation                                    | Use instead                                                                                  |
| -------------------------------------------- | -------------------------------------------------------------------------------------------- |
| No findings document yet                     | [`/code-review`](../code-review/SKILL.md)                                                    |
| Several review documents for the same change | [`/squash-code-review`](../squash-code-review/SKILL.md) first, then this skill on its output |
| Review and fix in one serial pass            | [`/pr-polish`](../pr-polish/SKILL.md)                                                        |
| Red CI on the PR                             | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md)                                            |
| Reviewer threads, not a findings document    | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md)                                      |

---

## 2. Workflow

### Step 1: Resolve the findings and the PR branch

1. Read the findings document in full. Accept any artifact with identifiable findings (`code_review`, `squashed_code_review`, `pr_polish`, or a hand-written list). Keep each finding's own ID (`F3`, `C-2`, `#4`); lower-case it for `<id>` in branch and directory names (`fix/finding-f3`). Skip findings the document marks resolved, rejected or won't-fix, and list them as skipped. `--only <ids>` narrows the set.
2. Resolve the PR's source branch from `--pr`, the document's header, or the current branch (`pr-host` › _Resolve the PR from a branch_ when a PR is needed). `git fetch origin` and stop if the local branch and `origin/<branch>` differ; ask the user to reconcile them first.
3. Pick the **landing tree**: the main checkout when it is on the source branch and clean; otherwise a workspace worktree on the source branch (`git-worktrees` › _Workspace Lifecycle_). Never switch the main checkout's branch.
4. Load the base profile (`project-profile` › _Resolution order_) for build and test commands, **Worktree include list**, **Dependency hydration** and **Shared local services**.

### Step 2: Dependency graph and batches — Gate

1. For each finding, list the files it will touch (cite the `path:line` the finding names; open the code to confirm) and its semantic dependencies:
   - a migration and the entity or configuration it alters;
   - a contract change and every consumer (DTO → OpenAPI snapshot → client types → mocks);
   - a shared helper and its callers changed by another finding;
   - a test fix and the production change it asserts.
2. Two findings conflict when their file sets intersect, and one depends on another when the dependency is semantic. Build the graph and a topological order.
3. Batch 1 is every finding with no unmet dependency, minus any that share files with an earlier member of the batch (it moves to the next batch), capped at 5. Later batches follow the same rule against the findings already landed.
4. Show the graph (Mermaid `graph LR`, edges labelled `shares <file>` or `depends: <reason>`), then a batch table (`Batch | Finding | Files | Depends on`), then stop:

> **Next Step Gate:** Reply `/proceed` to run batch 1 (<ids>), or adjust the batches.

### Step 3: Run one batch

1. Record `BASE=$(git -C <landing-tree> rev-parse HEAD)`: the PR branch head that every worktree in this batch starts from.
2. For each finding, create its worktree with `git-worktrees` › _Workspace Lifecycle_ › _Create_ (`DIR=<repo>/.claude/worktrees/finding-<id>`, branch `fix/finding-<id>`, base `$BASE`), then _Hydrate_. If the branch already exists from an earlier run, stop and ask: reuse it or name the new one `fix/finding-<id>-2`.
3. Set `LOCK=$(git -C <repo> rev-parse --path-format=absolute --git-common-dir)/fix-findings-services.lock` and pass it in every brief. If `command -v flock` fails (macOS ships without it), allow at most one finding per batch whose tests use a shared local service, and move the others to later batches.
4. Spawn all sub-agents of the batch **in one message**, each with the brief from [`references/agent-brief.md`](references/agent-brief.md), filled with the finding's full text, its file set, its `[worktree-context]` block and the profile's targeted test commands.
5. Wait for every sub-agent. Do not poll its worktree while it runs.

### Step 4: Collect, land and verify

1. Read every `<DIR>/RESULT.json`. Classify per invariant 1, and check `files_changed` against `git -C <DIR> diff --name-only $BASE..HEAD`. A file outside the finding's file set downgrades it to RED with the reason "scope drift".
2. Land the GREEN findings in dependency order following [`references/landing-and-handoff.md`](references/landing-and-handoff.md) › _Cherry-pick_. A conflict aborts that pick, marks the finding `CONFLICT` and skips its dependents.
3. Run the full build and test suite **once** in the landing tree (_Full-suite gate_ in the same reference). If it fails, do not push: stop, report the failing tests and which landed commits touch them, and ask.
4. Run the formatter the repo rulebook requires before a commit. If it changed files, commit them through [`/commit`](../commit/SKILL.md). Then `git -C <landing-tree> push` (no force) and read back `git rev-parse HEAD` against `origin/<branch>`.
5. Remove this batch's worktrees (_Worktree removal_), keeping every branch.
6. If another batch remains, show the updated batch table with this batch's outcomes and stop at the gate again. The next batch's `BASE` is the new pushed head.

### Step 5: Handoff and report

If any finding ended RED, BLOCKED_ENV or CONFLICT, write `<prefix>-handoff-<suffix>.md` from [`references/landing-and-handoff.md`](references/landing-and-handoff.md) › _Handoff template_, with exact repro commands per finding. Then end with the Output block.

---

## 3. Output

```markdown
**Findings:** <n> total · <g> landed · <r> RED · <b> BLOCKED_ENV · <c> CONFLICT · <s> skipped
**PR branch:** <branch> @ <short-sha> (pushed) · full suite: <passed>/<total>

| Finding | Batch | Status | Tests (run/failed) | Commit on PR branch | Note |
| ------- | ----- | ------ | ------------------ | ------------------- | ---- |

**Handoff:** <absolute path> (only when something did not land)
**Kept branches:** fix/finding-<id>, …
```

---

## 4. Verification

- Every landed commit maps to a GREEN `RESULT.json` with `tests_run > 0` (invariant 1).
- `git log $FIRST_BASE..HEAD` on the PR branch contains only cherry-picked finding commits and, at most, one formatting commit per batch.
- The full suite ran once per batch, after landing and before the push, and its counts appear in the Output block.
- `git worktree list` shows no `finding-*` worktree. `git branch --list 'fix/finding-*'` still lists every branch.
