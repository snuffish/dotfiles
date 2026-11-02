---
name: pr-fix-pipeline
description: "Diagnoses failing CI/CD pull request validation pipelines across Azure DevOps Pipelines and GitHub Actions. Correlates failed build/test step logs with git diffs, categorizes root causes (code regressions, flaky tests, pipeline configuration drift), drafts a targeted fix plan, and iterates through post-fix validation until the pipeline is verified passed by the agent."
argument-hint: "[<PR url | PR id | branch>]"
---

# Skill: `/pr-fix-pipeline` — PR Pipeline Failure Diagnosis & Fix Plan

Diagnoses why a pull request's validation pipeline is failing, separates regressions from noise in `<prefix>-investigation-<suffix>.md`, drafts a targeted fix plan in `<prefix>-implementation_plan-<suffix>.md`, and — once approved — iterates through local verification, push/re-queue, and run monitoring until every required check passes.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-investigation-<suffix>.md` and `<prefix>-implementation_plan-<suffix>.md` (suffix `<prId>-pipeline-<slug>`)
- `../_modules/git-worktrees.md`
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`

> [!CAUTION]
> **Golden invariants**
> 1. **Read-only until `/proceed`**: no source edits, commits, pushes, or branch switches before the gate opens. Local read-only reproduction (build/lint/test of the failing step) is allowed.
> 2. **Gate-authorized outward actions**: once the user opens the gate (`core` › *The `/proceed` gate*), this skill is authorized to commit and push the approved fix ([`/commit`](../commit/SKILL.md)) and re-queue the red Build policy evaluation (`az repos pr policy queue --id <prId> --evaluation-id <evaluationId> --org <org-url>`). Never cancel runs, post PR comments, change branch policies, or edit service-side pipeline definitions.
> 3. **Cite the log**: every failure claim cites the run ID, step name, exact error line(s), and `path:line` in code/YAML.
> 4. **Flake requires proof**: classify a failure as a flake only with evidence (re-run history, local pass on the same commit, unrelated to the diff).
> 5. **Never complete until verified passed by the agent**: after `/proceed`, keep monitoring and looping until every required PR check succeeds (`succeeded` / `approved`), pausing only on an external human-owned blocker.

---

## 1. When to Use

| Situation | Use instead |
|---|---|
| A local build/test/lint error with no pipeline involved | [`/problem`](../problem/SKILL.md) |
| Reviewing the PR's code, not its pipeline | [`/code-review`](../code-review/SKILL.md) |
| Reviewer comments, not build failures | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the Targets (PRs × Repos)

1. **Find every repo in scope** (`git-worktrees` › *Repo Resolution*) and detect the CI host from `git remote get-url origin`.
2. **Resolve the PR** from the argument or current branch per `pr-host` › *Resolve the PR from a branch* (on GitHub include `statusCheckRollup`). Report repos with no PR.
3. **Counterpart lookup**: run `pr-counterpart` › *Counterpart discovery* for every resolved PR and check the counterpart's pipeline status too (a red half is often caused by cross-repo contract drift).
4. **Read the PR description and linked work items** (`pr-host` › *Fetch the PR, its work items and acceptance criteria*).

### Step 2: Collect the Evidence

Read [evidence-commands.md](references/evidence-commands.md) and collect the failing policy evaluation, build timeline, failing step logs, target-branch run history, merge-commit staleness check, and pipeline YAML.

### Step 3: Classify Each Failure

| Class | Signature | Typical fix owner |
|---|---|---|
| **Code regression** | Compile/type/lint error or assertion in code the PR touched | This PR |
| **Test defect** | Test asserts the wrong thing, or depends on wall-clock, ordering, locale/time zone, random data | This PR or test owner |
| **Time/data-dependent** | Fails only on boundary dates/times (DST, month/quarter start) | Test/code — make clock injectable |
| **Flake** | Intermittent, unrelated to the diff, passes on re-run history | Re-queue now; stabilize separately |
| **Environment / agent** | Missing SDK/tool, image change, feed/auth failure, disk/timeout, outage | Pipeline YAML or infra |
| **Pipeline config** | YAML error, wrong path/working dir, missing variable/secret, policy misconfig | Pipeline YAML |
| **Generated-artifact drift** | Uncommitted codegen/snapshot/format verify failure | This PR — regenerate and commit |
| **Cross-repo contract drift** | Depends on an unmerged change in a sibling repo | Coordinate both PRs / merge order |

Identify the **first** error in each failing step, trace it to `path:line`, and check whether `git diff <target>...<source>` touches it.

### Step 4: Reproduce (when cheap)

Reproduce the failing step locally **on the run's commit** when cheap. First confirm `git -C <repo> rev-parse HEAD` equals the run's source commit and `git -C <repo> status --porcelain --untracked-files=no` is empty; if not, reproduce inside a `git-worktrees` snapshot (*Snapshot Lifecycle*) — never switch the main checkout. Ask before restoring dependencies (`npm ci`, `dotnet restore`), starting Docker, or running a slow full suite.

### Step 5: Write the Investigation (`<prefix>-investigation-<suffix>.md`)

Follow [`/investigate`](../investigate/SKILL.md) to publish the diagnosis artifact, adding:
- **Run table** in *Current-State*: `repo · PR · pipeline · run id · commit · stale? · result · failing step`.
- **One entry per failure**: class, quoted first error line, `path:line`, related to diff?, local reproduction command + result.
- **Pipeline review notes**: non-blocking pipeline smells (missing cache, deprecated tasks, image warnings) separated from blocking failures.

### Step 6: Plan the Fix (`<prefix>-implementation_plan-<suffix>.md`)

Follow [`/plan`](../plan/SKILL.md) Case B to publish the fix plan:
- Order phases **unblock-first**; name per fix the repo, files, change, and **local verification command**.
- For flakes, specify `re-queue policy evaluation <evaluationId> after /proceed` plus any stabilization task.
- Put user-owned actions (policy edits, infra tickets) under **Handover**.
- Stop and wait for the `/proceed` gate (`core` › *The `/proceed` gate*).

### Step 7: Post-Fix Execution & Autonomous Remediation Loop (after `/proceed`)

Once the gate opens, follow [remediation-loop.md](references/remediation-loop.md) to implement, verify locally, commit/push via [`/commit`](../commit/SKILL.md) (or re-queue), monitor the triggered run with non-blocking timers, and loop until every required check is verified green.

---

## 3. Output Format & Deliverables

- **Before `/proceed`**: emit the `artifact-protocol` › *Chat link block* for both `<prefix>-investigation-<suffix>.md` and `<prefix>-implementation_plan-<suffix>.md`, followed by one status line per repo/PR (`❌ <failing step>` with root cause class + evidence grade, or `✅ green`), and the closing gate line (`core` › *The `/proceed` gate*).
- **After `/proceed`**: emit the completion or external-blocker block from [remediation-loop.md](references/remediation-loop.md).

---

## 4. Verification & Validation

- **Before `/proceed`**: every repo in scope checked; every failing check classified with run ID, quoted log line, and staleness check; every plan step has a local verify command; no source modified or outward action taken.
- **After `/proceed`**: local verification passed before push; new `buildId`/check run confirmed and monitored to completion; skill marked complete only after all required PR checks succeeded.
