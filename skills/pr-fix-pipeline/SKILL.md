---
name: pr-fix-pipeline
description: "Diagnoses failing CI/CD pull request validation pipelines across Azure DevOps Pipelines and GitHub Actions. Correlates failed build/test step logs with git diffs, categorizes root causes (code regressions, flaky tests, pipeline configuration drift), and drafts a targeted fix plan."
---

# Skill: `/pr-fix-pipeline` — PR Pipeline Failure Diagnosis & Fix Plan

Finds out **why** a pull request's pipeline is failing, separates real regressions from noise, and hands over an evidence-backed fix plan. It chains the [`/investigate`](../investigate/SKILL.md) protocol (ground truth from the run logs and code) into [`/plan`](../plan/SKILL.md) (the fix), with a review pass in between.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-investigation-<suffix>.md` (the diagnosis, format owned by `/investigate`) and `<prefix>-implementation_plan-<suffix>.md` (the fix, format owned by `/plan`); suffix `<prId>-pipeline-<slug>` (e.g. `-18542-pipeline-statistics-granularity`) — for a multi-repo fix, use the lead PR id and list every PR in the artifact header
- `../_modules/git-worktrees.md`
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`

> [!CAUTION]
> **Golden invariants**
> 1. **Read-only until `/proceed`.** No source edits, commits, pushes or branch switches. Local reproduction (build/lint/test of the failing step) is allowed — it does not change source.
> 2. **No outward-facing actions.** Never re-queue/retry a run, cancel a run, post PR comments, change policies, or edit pipeline definitions in the service. Recommend them in the plan; the user triggers them.
> 3. **Cite the log.** Every failure claim carries the run id, step name and the exact error line(s) — plus `path:line` once traced into code.
> 4. **Flake is a conclusion, not a default.** Mark a failure as a flake only with evidence (passes on re-run history, passes locally on the same commit, failure unrelated to the diff).

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

1. **Find every repo in scope.** If the workspace root is not itself a git repo, enumerate child repos (`find . -maxdepth 2 -name .git`). Run the rest of this skill **per repo** — a frontend PR can be red because of the backend (and vice versa).
2. **Detect the CI host** from `git remote get-url origin`: `dev.azure.com` / `visualstudio.com` → Azure DevOps; `github.com` → GitHub Actions.
3. **Resolve the PR**: use the argument if given; otherwise resolve it from the current branch per **`pr-host`** › *Resolve the PR from a branch*. On GitHub, add `statusCheckRollup` to the `gh pr view --json` fields for the check states.
   Report repos with no PR — that is a finding, not a skip.
   **Then the counterpart:** run the lookup in `pr-counterpart` › *Counterpart discovery* for every resolved PR, even when only one PR was given. Pull the counterpart's pipeline status too. A paired change merges only when both halves are green, and a red half often comes from a contract the other half changed (classify it as cross-repo contract drift). A counterpart whose pipeline is green is listed as such, not skipped silently.
4. **Read the PR description and linked work items** so the plan knows the change's intent (`pr-host` › *Fetch the PR, its work items and acceptance criteria*).

### Step 2: Collect the Evidence

**Azure DevOps**
```bash
# Required checks on the PR — which policy is red, and which build it points at
az repos pr policy list --id <prId> --detect true \
  --query "[].{policy:configuration.type.displayName,status:status,build:context.buildId,blocking:configuration.isBlocking}" -o table

# PR runs (PR builds run on the merge ref)
az pipelines runs list --branch "refs/pull/<prId>/merge" --top 10 --detect true \
  --query "[].{id:id,def:definition.name,result:result,commit:sourceVersion,finished:finishTime}" -o json

# Failed records in the run's timeline → step names, log ids, issue messages
az devops invoke --area build --resource timeline \
  --route-parameters project=<project> buildId=<runId> --org <orgUrl> --api-version 7.1 \
  --query "records[?result=='failed'].{type:type,name:name,log:log.id,issues:issues[].message}" -o json

# One step's log as plain lines (the API returns {value:[...]} — `-o tsv` unwraps it)
az devops invoke --area build --resource logs \
  --route-parameters project=<project> buildId=<runId> logId=<logId> --org <orgUrl> --api-version 7.1 \
  --query "value" -o tsv | grep -nE '##\[error\]|error [A-Z]+[0-9]+|\[Test Failure\]|failed|FAIL'
```
Gotchas: `--org` without `--project` errors on `az repos`/`az pipelines` — pass both, or use `--detect true` from inside the repo. Use the organization URL form the workspace already uses (`pr-host` › *Organization URL*); both forms work. In zsh, don't stash flags in one variable (`$FLAGS` is not word-split) — inline them.

**GitHub Actions**
```bash
gh pr checks <n>
gh run list --branch <headRef> --limit 10 --json databaseId,name,conclusion,headSha
gh run view <runId> --log-failed
```

**Always also gather:**
- **History of the same check**: recent runs of that definition on the target branch (`--branch refs/heads/main`) and on other PRs. Red everywhere → base/infra problem; red only here → this diff.
- **Whether the run is stale — on both sides**: the PR merge commit's parents are `<target> <source>` (`git log -1 --format=%p <mergeCommit>`). Source parent ≠ PR head → the branch has moved since. Target parent behind `origin/<target>` → check whether `main` already fixed it (`git log <targetParent>..origin/<target>`, then `git merge-base --is-ancestor <fix> <mergeCommit>`); if so, the fix is a re-queue, not a code change — **but** ADO recomputes the merge commit lazily, so first confirm the live ref includes the fix (`git ls-remote origin refs/pull/<id>/merge`). If it is still the old merge, a re-queue rebuilds the same failing commit: tell the user to open the PR in the web UI to refresh it, or merge `<target>` into the branch. The Build policy `context` shows the same thing (`isExpired`, `buildIsNotCurrent`, `lastMergeTargetCommitId`). A green run whose policy is still `queued` has usually just expired.
- **The pipeline YAML** the run executed (path from the definition; read it at the PR's commit with `git show <sha>:<path>`), plus any templates it includes.
- **Warnings that are about to become errors** (deprecated tasks, agent image migrations, runtime EOL) — note them separately; they are not the cause unless proven.

### Step 3: Classify Each Failure

| Class | Signature | Typical fix owner |
|---|---|---|
| **Code regression** | Compile/type/lint error or assertion in code the PR touched | This PR |
| **Test defect** | Test asserts the wrong thing, or depends on wall-clock, ordering, culture/time zone, random data | This PR or test owner |
| **Time/data-dependent** | Fails only on certain dates/times (period boundaries, DST, month/quarter start), passes otherwise | Test/code — make the clock injectable |
| **Flake** | Intermittent, unrelated to the diff, passes on re-run history (timeouts, container startup, port races) | Re-run now; stabilize separately |
| **Environment / agent** | Missing SDK/tool, image change, feed/auth failure, disk/timeout, service outage | Pipeline YAML or infra |
| **Pipeline config** | YAML error, wrong path/working dir, missing variable/secret, condition logic, policy misconfig | Pipeline YAML |
| **Generated-artifact drift** | "uncommitted changes", snapshot/codegen/format verify steps | This PR — regenerate and commit |
| **Cross-repo contract drift** | One repo's PR depends on an unmerged change in another (API shape, shared enum, OpenAPI snapshot, container image) | Coordinate both PRs / merge order |

For each failure: identify the **first** error (later errors often cascade), trace it to `path:line` in the PR's code or YAML, and check whether the PR's diff (`git diff <target>...<source>`) touches it.

### Step 4: Reproduce (when cheap)

Reproduce the failing step locally **on the run's commit** using the repo's documented commands (its `CLAUDE.md`/README/CI YAML), scoped to the failing project/test. Check which code you are about to run first. The main checkout is often on another branch or carries local edits, and a reproduction on the wrong tree proves nothing:

```bash
git -C <repo> rev-parse HEAD                       # must equal the run's source commit
git -C <repo> status --porcelain --untracked-files=no   # must be empty
```

If either check fails, never switch the main checkout (invariant 1). Reproduce in a `git-worktrees` snapshot of the run's commit instead (*Snapshot Lifecycle*). Restoring dependencies there (`npm ci`, `dotnet restore`) takes time and disk, so **ask first**. Record the command, the commit it ran on and the outcome. If reproduction needs Docker, secrets or a long full-suite run, **ask first** too, and otherwise record "not reproduced". A local pass + CI fail points at environment, ordering or time-dependence.

### Step 5: Review & Write the Investigation

Write `<prefix>-investigation-<suffix>.md` following the `/investigate` template, with these additions:
- **Run table** in *Current-State*: repo · PR · pipeline · run id · commit · stale? · result · failing step.
- **One entry per failure**: class, first error line (quoted), trace `path:line`, related to diff? (yes/no + evidence), reproduced? (command + result).
- **Review section**: problems in the pipeline itself found along the way (missing caching, no test-result publishing on failure, deprecated tasks, agent image warnings) — clearly separated from the blocking failures.
- *Confidence Ledger* marks each root cause ✅ Verified / ⚠️ Inferred / ❓ Unknown.

### Step 6: Plan the Fix

Then follow `/plan` Case B, building on the investigation, to write `<prefix>-implementation_plan-<suffix>.md`:
- Order phases **unblock-first**: the fix that turns the required check green comes before hardening.
- Per fix: repo, file(s), change, and the **local command that proves it** before pushing.
- Multi-repo fixes: one phase per repo with explicit merge order.
- Flakes: "re-queue run `<id>` (user action)" plus an optional stabilization task — never just "retry".
- List the user-owned actions (re-queue, policy changes, infra tickets) in a **Handover** section.

Stop. Do not implement until the user types `/proceed`.

---

## 3. Output Format & Deliverables

Chat response, short. It opens with the two artifacts, each as its full file name (`.md` included) followed by anchors to its main sections, the way every other Command links its artifact:

```markdown
📄 [<prefix>-investigation-<suffix>.md](<link>)
· [TL;DR](<link>#L<n>) · [Run table](<link>#L<n>) · [Confidence Ledger](<link>#L<n>)

📄 [<prefix>-implementation_plan-<suffix>.md](<link>)
· [Proposed Changes](<link>#L<n>) · [Verification Plan](<link>#L<n>) · [Handover](<link>#L<n>)

**<repo> PR !<id>** — <pipeline> run <runId> ❌ <failing step>
- Cause: <one line> · class: <class> · ✅/⚠️/❓
**<repo> PR !<id>** — ✅ green / no PR

Next: <the single unblocking action>. Type `/proceed` to implement.
```

Links follow the host link format in the **`artifact-protocol`** protocol. Read the anchor line numbers from the written files (`grep -n '^#\{1,3\} '`), never from the drafts.

---

## 4. Verification & Validation

Before handing over:
- [ ] Every repo in scope was checked, including ones with green or no PRs.
- [ ] Every failing required check has a classified root cause with the run id and quoted log line.
- [ ] Stale-run check done (run commit vs PR head).
- [ ] Each "flake" verdict has evidence; each "regression" verdict is tied to the diff.
- [ ] Each plan step names the local command that verifies it.
- [ ] No outward-facing action was taken; no source was modified.

After `/proceed` and the fix: run the plan's local verification commands, then tell the user which run to re-queue (or that pushing will trigger it) — the green pipeline is the final check.
