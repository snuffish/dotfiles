---
name: pr-polish
description: 'Finishes a PR branch against its real base: four parallel read-only reviewers (Correctness, Data safety, Simplifier, Conventions) return JSON findings; it verifies, deduplicates and ranks them, applies high-confidence fixes in batches that are built, scoped-tested and reverted from a snapshot on failure, gates medium/low fixes behind /proceed, then drafts the PR description and a reply per open thread quoting the addressing commit. Commits each green batch (`--commit=auto`, default) or asks first (`--commit=ask`); never pushes or posts unasked. Use for /pr-polish, "finish this PR". Not for a review-only report (use /code-review) or thread triage alone (use /pr-feedback-review).'
argument-hint: "[PR id | URL] [--base <branch>] [--commit=ask|auto]"
disable-model-invocation: true
---

# Skill: `/pr-polish` — PR-Finishing Orchestrator

Takes the current branch from "reviewed" to "ready to merge": reviews it along four axes in parallel, applies only the fixes it is sure of, gates the rest, and drafts the PR description and thread replies. Edits land in the user's checkout. Each green batch becomes one local commit, so thread replies can quote it; nothing is pushed or posted without an explicit request.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: edits in place only for high-confidence fixes (Step 4); everything else is read-only until `/proceed`; commits only green batches (*Commit mode*), never pushes
- `../_modules/artifact-protocol.md`: writes `<prefix>-pr_polish-<suffix>.md`
- `../_modules/project-profile.md`: build/test commands, PR tooling and _Report language_ come from the project's profiles
- `../_modules/pr-host.md`
- `../_modules/fan-out.md`
- `../_modules/outward-writes.md`

On-demand references (`references/`):

- [`references/reviewer-briefs.md`](references/reviewer-briefs.md) — the four briefs and the JSON finding schema; load at Step 2

- **Two gates, never merged.** Gate 1 (`/proceed`) covers applying medium/low rows. Posting the description or replies is a separate explicit request (`outward-writes`), never implied by gate 1.
- **Commit mode.** `--commit=auto` (default) commits each green batch and carries on; `--commit=ask` shows the files and message and waits for a yes per batch. Invoking `/pr-polish` is the explicit request for these local commits only (`outward-writes` › *Explicit request & draft mode*); push, PR description and replies still need their own request. Commit through [`/commit`](../commit/SKILL.md) `no-push` with the batch's paths, following its *Step 3: Choose what goes into the commit* to *Step 5: Write the message and commit* (repo message convention, pre-commit gates such as the formatter). Stage only the batch's files. **Mixed files always ask:** if a batch file was already dirty in the baseline, the commit would sweep in the user's own edits, so ask even in `auto`; on a no, leave the batch uncommitted.
- **Restore points, not git.** Revert a batch only from its scratchpad snapshot; never `git checkout`, `restore`, `stash` or `reset`, which would destroy the user's pre-existing uncommitted work.
- **Scoped tests only.** Each batch runs the build plus the tests that cover its files. Ask before any full or integration suite, and accept a no.
- **Agent cap.** Exactly four reviewers in one message (`fan-out` › _Brief contract_); no further sub-agents.

---

## 1. When _not_ to use

| Situation                                              | Use instead                                             |
| ------------------------------------------------------ | ------------------------------------------------------- |
| Only want a review report, no edits                    | [`/code-review`](../code-review/SKILL.md)               |
| Only want duplication and dead-code cleanup            | [`/simplify-branch`](../simplify-branch/SKILL.md)       |
| Only want reviewer threads triaged and replies drafted | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| A failing pipeline                                     | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md)       |

---

## 2. Workflow

### Step 1: Resolve scope and baseline

1. Run `python3 -I <registry>/simplify-branch/scripts/branch_scope.py [--base <branch>]` from the repo root and handle its exit codes as [`/simplify-branch`](../simplify-branch/SKILL.md) › _Step 1: Resolve the scope_ does. Keep `base`, `merge_base`, `files` and `namespaces`.
2. Resolve the PR (`pr-host` › _Resolve the PR from a branch_) and load the base and Command profiles (`project-profile` › _Resolution order_). Restate the fields you use: build and test commands per half, PR template path, PR tooling, _Report language_.
3. Save the baseline: `git rev-parse HEAD`, `git status --porcelain`. Files already dirty are the user's work: list them in the artifact, and keep every edit to them minimal.
4. Note `migrations`: the changed files under any `Migrations/` folder (`branch_scope.py` skips them from `files`, so take them from `git diff --name-only <merge-base>...HEAD`).

### Step 2: Fan out four reviewers

Spawn the four briefs in [`references/reviewer-briefs.md`](references/reviewer-briefs.md) in one message, each given the base, merge base, file list (plus `migrations` for B) and the loaded profiles. Reviewers read the user's checkout (they need the uncommitted work) and are read-only (`fan-out` › _Brief contract_).

### Step 3: Verify, deduplicate, rank

1. Parse each reviewer's JSON. A reviewer that returns invalid JSON gets one retry via SendMessage; then record it as failed in the artifact and go on.
2. Re-open every `file:line` yourself (`fan-out` › _Aggregation_). Drop findings that do not hold; merge findings on the same code into the strongest entry and list every reviewer it came from.
3. **Confidence is yours to set, not the reviewer's.** Keep `high` only when the fix is local and mechanical, its correctness is visible at the cited line, and it changes no public contract, migration, persisted data or PR claim. Downgrade everything else to `medium` or `low`, and always downgrade migration edits and anything the project profile lists under _Contract touchpoints_.
4. **Claim conflicts block.** A finding showing that the PR description, a rulebook or a doc states something the code does not do is marked `blocks-description`; Step 6 does not start until the user resolves it.
5. Rank by severity (`critical` > `important` > `minor`), then confidence, then reviewer count.

### Step 4: Apply high-confidence batches

1. Group the `high` findings into batches by namespace (`namespaces` keys; never across halves), at most ~5 findings per batch.
2. Per batch: copy its files into `<scratchpad>/pr-polish/batch-<n>/` (note which did not exist), apply the fixes, then run the build of the touched half and the tests covering the batch (the mirrored tests in `namespaces[key].tests`, plus any test file the batch edits).
3. **Green** → commit it (*Commit mode*) and record `applied (<short-sha>)`, or `applied, uncommitted` when the commit was declined or failed its gates. **Red** → restore the batch from its snapshot, rerun the build to confirm it is back to green, record `reverted` with the failing check, and move its findings to the Step 5 table as `medium`.
4. After each batch, compare `git status --porcelain` with the baseline; a changed path outside the batch is reported, never reverted on your own.
5. A batch with no covering tests is `behaviour unverified`.

### Step 5: Present medium and low findings — Gate 1

Write the artifact (§3), then print the table and stop:

| #   | Sev | Conf | From | `file:line` | Issue | Proposed change |
| --- | --- | ---- | ---- | ----------- | ----- | --------------- |

> **Next Step Gate:** Reply `/proceed` to apply all rows, `/proceed 2,5` for specific rows, or specify changes. Posting is not part of this gate.

After `/proceed`, apply the picked rows with the Step 4 batch procedure (commits included) and update the artifact.

### Step 6: PR description and thread replies (drafts only)

1. Stop if any `blocks-description` finding is open.
2. **Description**: run [`/pr-summary`](../pr-summary/SKILL.md) in preview mode against the base. It uses the repo PR template (`docs/pull_request_template.md` or the profile's path). Save the body in the artifact.
3. **Threads**: fetch the active threads (`pr-host` › _Fetch discussion threads_, `az repos pr` / `az devops invoke` on Azure DevOps). For each thread, check the code at HEAD (verify in code, not commit messages, as in [`/pr-feedback-review`](../pr-feedback-review/SKILL.md)), find the commit that addresses it (`git log --oneline <merge-base>..HEAD -- <path>`, `git log -L` for the lines) and draft a reply quoting `<short-sha> <subject>`.
4. **Uncommitted fixes have no commit to quote.** Check the working tree first: if `git diff HEAD -- <path>` touches the thread's lines, the fix is uncommitted (a batch left `applied, uncommitted`, or the user's own uncommitted work). Mark that draft `needs commit`, with no SHA, and never fall back to an older commit that merely touched the same path. Quote a SHA only after `git show <sha> -- <path>` shows the change the thread asked for. A batch committed in Step 4/5 is quoted by its SHA. List the `needs commit` threads and suggest `/commit`. After the user commits, rerun this step for those threads only, so the drafts quote the new SHAs.

### Step 7: Post on explicit request

Only when the user asks: apply the description with `/pr-summary update` and post the replies with [`/pr-post-comments`](../pr-post-comments/SKILL.md) from the artifact. Never post a `needs commit` draft: leave those threads out, name them, and post them only after Step 6.4 has re-drafted them with a SHA. A declined write is final (`outward-writes` › _Denied write is final_).

---

## 3. Output

Artifact `<prefix>-pr_polish-<PR id>-<slug>.md` in the artifact dir (`artifact-protocol`), with these sections:

- **Context**: branch, base, merge base, PR, loaded profiles, baseline dirty files, reviewers that failed
- **Findings**: every verified finding (`#`, severity, confidence, reviewers, `file:line`, issue, proposed fix, `Status`: `applied (batch n)` · `reverted (batch n: <check>)` · `pending gate` · `dropped (<reason>)` · `blocks-description`)
- **Batches**: files, findings, build and test commands with their results, commit SHA or `uncommitted`, `behaviour unverified` flags
- **PR description draft** and **Thread replies** (thread ID, file, reply, quoted commit or `needs commit`)

Chat: a short summary (applied / reverted / pending counts), the gate table, and the artifact link. End with the commits made (`<short-sha> <subject>` per batch) and a line that nothing was pushed or posted.

---

## 4. Verification & Validation

- Every applied batch has a green build and its scoped tests listed in **Batches**; every revert is confirmed by a re-run build.
- Before reporting Step 6, `grep` the artifact for `pending gate` and `needs commit` and mention any hits.
- Never report the branch as ready while a `blocks-description` row, a reverted batch or a `needs commit` reply is open.
