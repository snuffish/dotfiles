---
name: pr-fix-pipeline
description: Diagnoses a failing pull-request pipeline (CI/CD build validation) and plans the fix. Resolves the PR(s) for the current branch across every repo in the workspace (e.g. frontend + backend), pulls the failing runs, timelines, step logs and test results from Azure DevOps Pipelines or GitHub Actions, classifies each failure (code regression, test, flake, time-dependent, environment/agent, pipeline config, cross-repo contract drift), traces it to the code or YAML that caused it, then writes an /investigate artifact and an /plan implementation plan. Read-only until /proceed. Trigger on /pr-fix-pipeline, "the PR build is red", "why is CI failing on my PR", "fix the pipeline", "the build validation failed", "check the devops pipeline for errors".
---

# Skill: `/pr-fix-pipeline` — PR Pipeline Failure Diagnosis & Fix Plan

Finds out **why** a pull request's pipeline is failing, separates real regressions from noise, and hands over an evidence-backed fix plan. It chains the [`/investigate`](../investigate/SKILL.md) protocol (ground truth from the run logs and code) into [`/plan`](../plan/SKILL.md) (the fix), with a review pass in between.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **Target Artifacts** (both at the **workspace root**, where `<prefix>` is `<host>-<model>-`, e.g. `antigravity-gemini-3.8-flash-` or `claude-opus-5.5-`):
  - `<prefix>-investigation-<suffix>.md` — the diagnosis (format owned by `/investigate`).
  - `<prefix>-implementation_plan-<suffix>.md` — the fix (format owned by `/plan`).
- **Suffix**: `<prId>-pipeline-<slug>` (e.g. `-18542-pipeline-statistics-granularity`). For a multi-repo fix, use the lead PR id and list every PR in the artifact header.
- **Anti-Overwrite Rule**: Always include the active AI model in `<prefix>` and append the descriptive `<suffix>`. Never write unsuffixed or un-modeled generic files.

> [!CAUTION]
> **Golden invariants**
> 1. **Read-only until `/proceed`.** No source edits, commits, pushes or branch switches. Local reproduction (build/lint/test of the failing step) is allowed — it does not change source.
> 2. **No outward-facing actions.** Never re-queue/retry a run, cancel a run, post PR comments, change policies, or edit pipeline definitions in the service. Recommend them in the plan; the user triggers them.
> 3. **Cite the log.** Every failure claim carries the run id, step name and the exact error line(s) — plus `path:line` once traced into code.
> 4. **Flake is a conclusion, not a default.** Mark a failure as a flake only with evidence (passes on re-run history, passes locally on the same commit, failure unrelated to the diff).

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/pr-fix-pipeline` (bare, or with a PR URL/id, run/build id, or repo name).
- *"The PR build is red"*, *"why is CI failing?"*, *"build validation failed"*, *"check the pipeline for errors and plan a fix"*.

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
3. **Resolve the PR**: use the argument if given; otherwise from the current branch:
   ```bash
   # Azure DevOps (run inside the repo; --detect reads org/project from the remote)
   az repos pr list --source-branch "$(git rev-parse --abbrev-ref HEAD)" --status active --detect true \
     --query "[].{id:pullRequestId,title:title,target:targetRefName}" -o json
   # GitHub
   gh pr view --json number,title,headRefName,baseRefName,statusCheckRollup
   ```
   Report repos with no PR — that is a finding, not a skip.
4. **Read the PR description and linked work items** so the plan knows the change's intent (same commands as `/code-review` § *Pull-Request References*).

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
Gotchas: `--org` without `--project` errors on `az repos`/`az pipelines` — pass both, or use `--detect true` from inside the repo. Use the `dev.azure.com/<org>` URL form; legacy `*.visualstudio.com` can fail auth. In zsh, don't stash flags in one variable (`$FLAGS` is not word-split) — inline them.

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

Reproduce the failing step locally on the PR's commit using the repo's documented commands (its `CLAUDE.md`/README/CI YAML), scoped to the failing project/test. Record the command and outcome. If reproduction needs a checkout, Docker, secrets or a long full-suite run, **ask first** and record "not reproduced" otherwise. A local pass + CI fail points at environment, ordering or time-dependence.

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

Chat response, short:

```markdown
**<repo> PR !<id>** — <pipeline> run <runId> ❌ <failing step>
- Cause: <one line> · class: <class> · ✅/⚠️/❓
**<repo> PR !<id>** — ✅ green / no PR

📄 [Investigation](<link>) · 📄 [Fix plan](<link>)

Next: <the single unblocking action>. Type `/proceed` to implement.
```

Links follow the host link format in the **[artifacts](../artifacts/SKILL.md)** protocol.

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
