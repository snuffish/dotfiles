---
name: pr-fix-pipeline
description: 'Takes ownership of a PR''s failing CI until every build is green: fetches the failing run''s logs (Azure DevOps or GitHub Actions), classifies each failure as REAL_BUG, FLAKY_TEST or INFRA_FLAKE, fixes bugs and flaky tests at the root, re-runs infra flakes at most twice and logs them in a flake ledger, polls CI, and stops when green or after 5 fix iterations. Runs unattended: invoking it authorizes its commits, pushes, re-runs and a ''## CI fixes'' section in the PR description. Use for /pr-fix-pipeline, "fix the pipeline", "make the PR green". Not for a local build error (use /problem) or reviewer comments (use /pr-feedback-review).'
argument-hint: "[<PR url | PR id | branch>]"
disable-model-invocation: true
---

# Skill: `/pr-fix-pipeline` — Own a PR's CI Until Green

Takes ownership of one pull request's validation pipeline and loops (fetch → classify → fix or re-run → poll) until every required build passes, or until the iteration cap is reached. Writes no artifact: the deliverables are the fix commits, the flake ledger, the PR description's `## CI fixes` section and the closing summary table.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: **not** read-only — invoking this skill opens the gate for the whole loop (invariant 1)
- `../_modules/outward-writes.md`
- `../_modules/git-worktrees.md`
- `../_modules/pr-host.md`

On-demand references (`references/`):

- [`references/evidence-commands.md`](references/evidence-commands.md) — az/gh commands for the red build, its timeline, failed-step logs, run history and staleness
- [`references/remediation-loop.md`](references/remediation-loop.md) — narrow reproduction, re-run and polling commands, the flake ledger, the `## CI fixes` section and the summary table

> [!CAUTION]
> **Golden invariants**
>
> 1. **Invocation is the explicit request.** Invoking `/pr-fix-pipeline` satisfies `outward-writes` › _Explicit request & draft mode_ for, and only for: commits and pushes of fixes to the PR's source branch (via [`/commit`](../commit/SKILL.md)), re-queuing the PR's red build, writing the flake ledger, and adding or replacing the `## CI fixes` section of the PR description. Never force-push, rebase, cancel runs, post PR comments, change branch policies, edit pipeline definitions on the server, or touch another PR.
> 2. **Fix the root cause, never paper over it.** Never add retry attributes or retry loops, widen timeouts, add sleeps, or skip, ignore or delete a failing test. Time-dependent code takes an injected clock (`TimeProvider` in .NET, a fake timer or fixed date in JS) instead of `DateTime.Now` / `Date.now()`; order-dependent tests own their data; random inputs get a fixed seed or fixed values.
> 3. **Cite the log.** Every classification cites the run ID, job/step name, the quoted first error line and the `path:line` it traces to.
> 4. **INFRA_FLAKE requires proof.** Classify a failure as infrastructure only when the log shows it (container died, agent lost, network/feed/timeout error) and the failing code is unrelated to the diff. Otherwise it is REAL_BUG or FLAKY_TEST.
> 5. **Hard caps.** At most **5 fix iterations** (pushed fix commits) per invocation, and at most **2 re-runs** per INFRA_FLAKE job. Reaching a cap stops the loop. It never loops past it.
> 6. **Never rewrite the PR description.** Only add the `## CI fixes` section at the end, or replace that one section if an earlier run of this skill added it.

---

## 1. When to Use

| Situation                                               | Use instead                                             |
| ------------------------------------------------------- | ------------------------------------------------------- |
| A local build/test/lint error with no pipeline involved | [`/problem`](../problem/SKILL.md)                       |
| Reviewing the PR's code, not its pipeline               | [`/code-review`](../code-review/SKILL.md)               |
| Reviewer comments, not build failures                   | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |

---

## 2. Workflow

### Step 1: Resolve the PR and the working copy

1. Detect the CI host from `git remote get-url origin` and resolve the PR from the argument or the current branch (`pr-host` › _Resolve the PR from a branch_). One PR per invocation; with none, stop and say so.
2. Read the PR (title, description, `isDraft`, source and target branch, head commit) per `pr-host` › _Fetch the PR, its work items and acceptance criteria_. Keep the description verbatim; Step 6 edits only its end.
3. **Pick where fixes are made.** If the current checkout is on the PR's source branch, clean, and level with `origin/<source>`, work there. Otherwise open a feature worktree on the source branch (`git-worktrees` › _Workspace Lifecycle_). Never switch the main checkout's branch.

### Step 2: Fetch the failing run

Run the commands in [`references/evidence-commands.md`](references/evidence-commands.md): the PR's required builds and their status, the failing run's timeline, the failed jobs' logs, the run history on the target branch, and the staleness check. If nothing is red and nothing is running, skip to Step 6 with an empty failure list.

If the run is stale (the source branch moved, or the target branch already fixed the failure), re-queue the build once (no fix, no iteration counted) and go to Step 5.

### Step 3: Classify each failure

Take the **first** error in each failed job and put it in exactly one class:

| Class           | Signature                                                                                                                             | Action                                             |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| **REAL_BUG**    | Compile, lint, type or assertion failure caused by code or tests in the diff, reproducible locally                                    | Fix (Step 4)                                       |
| **FLAKY_TEST**  | Test passes and fails on the same code: depends on time of day, date, time zone, culture, test ordering, shared data, or randomness   | Fix the root cause (Step 4)                        |
| **INFRA_FLAKE** | Testcontainers or the SQL container died or never started, agent lost, feed/network error, job or step timeout with no test assertion | Re-run (Step 5), record in the ledger              |
| **BLOCKED**     | Pipeline YAML or config error, missing secret or permission, service outage, an unmerged change in another repo                       | Stop the loop and report it as an external blocker |

### Step 4: Fix REAL_BUG and FLAKY_TEST failures

For each one, in the order the jobs fail:

1. **Reproduce** with the narrowest filter the half's test runner supports (examples in [`references/remediation-loop.md`](references/remediation-loop.md) › _Narrow reproduction_). A FLAKY_TEST that will not fail locally is reproduced by forcing its condition (fixed clock at the failing time, reversed order, the seed from the log).
2. **Fix the root cause** under invariant 2. Fix the code when the code is wrong and the test when the test is wrong; say which in the commit body.
3. **Verify locally:** run every test class the fix touched, plus that half's documented lint/build gate. Never run the full suite.
4. **Commit and push** through [`/commit`](../commit/SKILL.md) Steps 2–5. It uses the repo's message convention, which may be Conventional Commits or a work-item prefix. Include any pending flake-ledger lines in the same commit. Each pushed commit is one fix iteration.

Batch all fixes found in one run into one push when they are independent; that push counts as one iteration.

### Step 5: Re-run INFRA_FLAKE jobs and poll

Follow [`references/remediation-loop.md`](references/remediation-loop.md): append the ledger line, re-queue (at most twice per job), then poll the new run every few minutes with non-blocking timers until it finishes. Then go back to Step 2.

Leave the loop when one of these holds:

- **Green:** all required builds succeeded.
- **Fix cap:** 5 fix iterations pushed and a build is still red.
- **Re-run cap:** a job failed as INFRA_FLAKE after 2 re-runs.
- **BLOCKED:** a failure was classified BLOCKED.

### Step 6: Update the PR description and report

1. Add or replace the `## CI fixes` section ([`references/remediation-loop.md`](references/remediation-loop.md) › _PR description section_), then read it back (`outward-writes` › _Read back_).
2. If ledger lines are still uncommitted (only re-runs followed them), leave them uncommitted in the working copy and say so: one more push would trigger CI again.
3. End with the summary table (see Output).

---

## 3. Output

End with the closing block from [`references/remediation-loop.md`](references/remediation-loop.md) › _Summary_: the stop reason (green, fix cap, re-run cap or blocker), then the summary table with one row per failure, and the links to the PR and the final run.

---

## 4. Verification

- Every failure has a class, a run ID and a quoted error line.
- Every fix passed its touched test classes locally before it was pushed.
- No retry, timeout, sleep or skip was added (`git diff <first-head>..HEAD` checked before each push).
- Both caps were respected. The PR description above `## CI fixes` is byte-for-byte unchanged (compare it with the copy from Step 1).
