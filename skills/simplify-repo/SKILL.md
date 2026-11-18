---
name: simplify-repo
description: 'Runs a first /simplify cleanup on whole files as they are at HEAD: a repo or folder with no diff to review, such as code already merged to main. Prints a read-only matrix of rows (folders × cleanup angles) with the repo''s constraints; /proceed then runs /simplify per picked row with behaviour unchanged, remaps `file:line` references in the docs, runs the documented tests and writes a review brief. With --land it also commits one commit per row, pushes, has a fresh sub-agent run /code-review on the range with the brief as its spec, fixes the findings and pushes again. Use for /simplify-repo, "simplify the whole repo", "first cleanup of main". Not for a branch''s own changes (use /simplify-branch), one file or range (use /simplify), bug hunting (use /code-review) or an existing findings document (use /fix-findings).'
argument-hint: "[<path>…] [--protect <file>…] [--no-touch <path>…] [--land [--onto-default]] [--review-model <opus|sonnet>]"
disable-model-invocation: true
---

# Skill: `/simplify-repo` — First Cleanup of Whole Files

`/simplify-branch` scopes a cleanup to what a branch changed. This Command covers the case with no diff: code that is already merged, cleaned file by file as it stands at `HEAD`. It prints a matrix and stops at a `/proceed` gate, then runs `/simplify` per row, keeps the docs' line references right, verifies and writes a review brief. With `--land` it carries on to the end state: commits pushed, an independent review with the brief as its spec, and the review's findings fixed and pushed.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`; after the gate it edits the current checkout in place
- `../_modules/artifact-protocol.md`: writes `<prefix>-simplify_review_brief-<suffix>.md`; with `--land` the reviewer writes `<prefix>-code_review-<suffix>.md`
- `../_modules/fan-out.md`: only for the one review sub-agent of Step 9 (_Brief contract_, _Aggregation_)
- `../_modules/outward-writes.md`: only with `--land`

On-demand references (`references/`):

- [`references/prompts-and-brief.md`](references/prompts-and-brief.md) — the `/simplify` target text per row, the review brief template and the reviewer's prompt

- **Behaviour stays the same.** No change to what the code returns or writes, its contracts (HTTP, CLI, file formats), thresholds, pinned versions or lock files, nor to how each file is started (as a script, a module, a CI step). A change that would alter one of them is dropped and listed, never applied: a reuse that needs an import the entry point cannot resolve is such a change.
- **No-touch paths.** `--no-touch` paths, and whatever the repo rulebook forbids editing or reading (data, sealed test sets, fixtures, snapshots), are never edited, opened or searched. The same holds for commands the rulebook forbids (scoring a sealed set, training, deploys): verification is the documented test gate and nothing more.
- **Protected files.** `--protect` names files someone else has open edits to. Reading one, or calling its helpers from another row, is fine. A change to one stays in a single small hunk and is listed on its own in the brief and the final report, so that person can merge without surprises; with nothing clear to gain, leave the file untouched.
- **One editor.** The session model edits single-pass; no sub-agent edits. The only sub-agent is the reviewer in Step 9.
- **`--land` is the explicit request** (`outward-writes` › _Explicit request & draft mode_) for the commits of Steps 8 and 10 and one push after each. Without it nothing is committed. Never amend, rebase, reset, stash or force-push. `--onto-default` has a meaning only with `--land`.

---

## 1. When _not_ to use

| Situation | Use instead |
|---|---|
| The files a branch or PR changed | [`/simplify-branch`](../simplify-branch/SKILL.md) |
| One file, a commit range or a PR you name | [`/simplify`](../simplify/SKILL.md) with that target |
| Hunting bugs, regressions or security flaws | [`/code-review`](../code-review/SKILL.md) |
| A findings document already exists and only needs fixes | [`/fix-findings`](../fix-findings/SKILL.md) |
| Dead code, unused exports, debug remnants | [`/clean`](../clean/SKILL.md) |

---

## 2. Workflow

### Phase A — Matrix (read-only)

#### Step 1: Resolve the scope

Run (`<skill-dir>` is this skill's real folder; `--repo` defaults to the current directory; give the paths before the options):

```bash
python3 -I <skill-dir>/scripts/repo_scope.py [<path> …] [--protect <file> …] [--no-touch <path> …] [--repo <dir>]
```

It prints JSON for the tracked files under the paths (the whole repo without any), with everything under a `--no-touch` path left out of `files`, `rows` and `tests`:

- `files`: code files by extension, minus test files; `lines`: line count per file
- `rows`: one per parent folder, largest first, each with `files`, `lines`, `tests` (test files anywhere in the repo that name one of the row's files: a hint, checked per change in Step 6), `protected` and a ready `simplify` line
- `skipped_generated` and `skipped_docs` (the patterns of `/simplify-branch`'s `branch_scope.py`), and `skipped_other`: a count per extension of every other file under the paths, which the script never opens
- `dirty`: in-scope files with uncommitted changes; `on_default`: whether the current branch is `origin/HEAD`'s

Exit codes: `0` files in scope, `1` nothing in scope (say so and stop), `2` git error (show `error`).

If `dirty` is not empty, list the files and ask: the cleanup starts from `HEAD`, and edits on top of someone's uncommitted work cannot be told apart from it later.

#### Step 2: Read the constraints

From the repo rulebook (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`) and the README of each folder in scope where one exists, collect and print under the matrix:

1. **Verification gate**: the documented test and lint commands, and any check the rulebook requires after a change. Each runs with the repo root as its working directory; when the shell cannot change directory, rewrite the command with absolute paths or the tool's own directory flag. Run the gate once now, on the untouched tree: that proves the form that works here, and gives the baseline result (a check that fails before the cleanup is not the cleanup's).
2. **Forbidden here**: commands that must not run and paths that must not be read or edited. Add the paths to the no-touch paths; if one of them holds files of a row, run Step 1 again with it.
3. **Contracts**: files or values whose change is a change for a consumer (API fixtures, thresholds, pins), and how each entry point in scope is started, even where the rulebook is silent on it.
4. **What a push sets off**: a build, a deploy, a pinned image.
5. **Line references**: run `python3 -I <skill-dir>/scripts/remap_citations.py [--repo <dir>]` (a dry run). Its last line starts with how many `file:line` references to tracked files the docs hold; above 0, Step 4 item 4 has work to do.

#### Step 3: Build the matrix

1. **Baseline.** Note `git rev-parse HEAD` and `git status --porcelain` for Phase B.
2. **Rows.** Start from `rows`. Fold two rows into one only when both hold copies of the same code and neither owns it yet, so the cleanup has to see both sides. When one row already owns the helper and the other only needs to call it, keep them apart: item 3 orders them. A row of one or two small files joins the row that uses it; when none does, it stays a row and usually ends `skip`. Split a row above ~2,000 lines by file. At most ~12 rows.
3. **Order, then label.** Leaf rows first (pipelines, scripts, entry points nothing imports), shared modules last: a helper a leaf row wants to reuse is then still in its `HEAD` form, and the shared row is cleaned with its callers already settled. A row holding protected files goes last. Label the rows `A`, `B`, `C`, … in that order.
4. **Skim.** Read each row's files whole, once. Note only signals you can point at, as `file:line`.
5. **Cells.** Per angle of `/simplify` (Reuse, Simplify, Efficiency, Altitude, as in `simplify-branch` › _Step 3: Build the matrix_ item 3): `●` clear candidate with a `file:line`, `○` possible, `–` nothing seen.
6. **Priority.** `high` = at least one `●`; `low` = only `○`; `skip` = all `–`. Recommend (`✓`) the `high` rows.
7. **Proposed change.** One imperative per `●` (and per `○` worth trying), naming the symbol or file. Mark it `contract?` when it comes near a Step 2 contract or changes how a file is started; those are dropped in Phase B unless a test pins the behaviour.

Phase A ends with the scope line (`<repo>` @ `<head>`, branch, file and line count, skipped counts, protected files), the constraints, the matrix in `simplify-branch` › _Phase A ends with_ shape (columns `Folder` and `Lines` in place of `Namespace` and `+/-`), one block per row, and:

> **Next Step Gate:** Reply `/proceed` to run `/simplify` on the ✓ rows, `/proceed A,C` for specific rows, `/proceed all` for every non-skip row, or specify changes.

Stop there, with or without `--land`.

### Phase B — Apply (after `/proceed`)

#### Step 4: Edit row by row

1. **Recheck the baseline** as `simplify-branch` › _Phase B — Apply (after `/proceed`)_ item 1.
2. Per picked row, in label order: copy its files and its `tests` to `<scratchpad>/simplify-repo/<row>/` (the row's restore point), then invoke `/simplify` once with the target text from [`references/prompts-and-brief.md`](references/prompts-and-brief.md) › _Row target_. The text overrides `/simplify`'s own diff gathering and its four agents: whole files, single pass. `/simplify`'s standard instructions still arrive with it; where the two differ, the target text wins.
3. **Guard the boundary** after each row: a changed path outside the row, or under a no-touch path, is put back from the restore point or listed and asked about. Never `git checkout`, `restore` or `stash`.
4. **Line references.** When every row is edited, and before any commit, run `remap_citations.py` as a dry run, then with `--apply`. Exit code `1` means rows to read, not a failure (`0` none, `2` git error). `--apply` writes every row, `CHECK` rows included, with the nearest surviving line: open each `CHECK`, `AMBIGUOUS` and `UNRESOLVED` row, read the doc's sentence against the new lines and correct the range by hand where it no longer covers what the sentence describes. A doc that already differs from `HEAD` is never rewritten again, so a second run before the commit only reports `docs already remapped` or `EDITED`. The script does not handle `#L<n>` link anchors: find them with `git grep -n -E '#L[0-9]+' -- '*.md'`.

#### Step 5: Verify

Run the Step 2 verification gate after the last row. A failure is traced to its row and fixed, or the row is put back from its restore point. Never run a forbidden command to get more assurance; name what stayed unverified instead.

Then compare `git status --porcelain` with the baseline. Untracked files the gate left behind (caches, reports) are deleted by exact path when they are plainly the gate's own output, and otherwise named in the report; add no ignore rule for them.

#### Step 6: Name the test per change

For every applied change, name the test that runs the changed lines (`<test file>::<test>`), or mark it `no test`. Establish it by reading the test, or with a coverage tool when the repo documents one: `rows[…].tests` only says a test file mentions the file. These marks go into the brief's known risks; with `--land`, Step 10 writes the missing tests.

#### Step 7: Write the review brief

Write `<prefix>-simplify_review_brief-<suffix>.md` (`artifact-protocol` › _Claim (atomic create; counter on collision)_) from [`references/prompts-and-brief.md`](references/prompts-and-brief.md) › _Review brief_: under ~60 lines, facts only. It is the Spec source of the review that follows: the reviewer checks each changed hunk against "same behaviour" and against this list, in place of a PR description. This session owns the brief and edits it in place in Steps 8 and 11.

Without `--land`, end here with the Output block: nothing is committed; the next steps are `/commit`, then `/code-review` on the commit range with the brief as its spec.

### Phase C — Land, review, fix (`--land`)

#### Step 8: Commit and push

1. `on_default` and no `--onto-default`: stop before the first commit, propose `refactor/simplify-<slug>` and create it only on a yes. With `--onto-default` the commits go onto the default branch: the flag is the user's request for that, and `/commit`'s own refusal of default branches does not apply here.
2. If Step 2 found that a push to this branch deploys, stop and ask. A build alone is named in the report.
3. One commit per row in label order, then one for the remapped docs. Of `/commit`, only three steps apply: stage by explicit path per `commit` › _Step 3: Choose what goes into the commit_, write each message per _Step 5: Write the message and commit_ (a plain imperative subject naming the row when the repo shows no convention), and run the gates of _Step 4: Run the repo's pre-commit gates_ before the first commit. The Step 5 run counts as that gate when nothing was edited since.
4. Push the current branch, then read back: `git status --short --branch` is level with the upstream. Record the range `<first>^..<last>` and the commit table in the brief.

#### Step 9: Independent review

Spawn one fresh sub-agent (`general-purpose`, `model` from `--review-model`, default `opus`; never a fork: it must not inherit this run's reasoning) with the prompt from [`references/prompts-and-brief.md`](references/prompts-and-brief.md) › _Reviewer prompt_. It runs `/code-review --axes correctness,standards,spec` on the range, read-only, and writes the review artifact. Nothing is posted to a PR or tracker.

When it returns, re-open every cited `path:line` (`fan-out` › _Aggregation_) before acting on a finding.

#### Step 10: Fix the findings

| Finding | Action |
|---|---|
| 🔴 behaviour changed | Fix it, or put the hunk back from the row's restore point. Re-verify that finding alone. |
| 🟡 behaviour may have changed | Settle it first: read both versions, or run the smallest check that touches nothing forbidden. When it holds, handle it as 🔴 and add a test that pins the old behaviour. |
| 🟡 a changed path has no test | Write the test where the gate already looks for tests, and confirm from the gate's output that it ran. Drive the changed lines through the nearest public function; replace only what is forbidden or heavy with a stand-in. |
| 🟡 other | Fix when it lies in the run's files and keeps behaviour; otherwise leave it and list it. |
| 🟢 caused by the cleanup (a guard it weakened, a need it added) | Fix. |
| 🟢 other | List, don't fix: no second cleanup cycle. |
| Provable only elsewhere (a pipeline run, another machine) | Read the CI or build run of the pushed head and record its result; what still cannot be checked is listed as left, with the exact command for the user. |

A fix in a protected file stays one hunk and is listed. If the fixes moved lines, rerun `remap_citations.py` before committing them. Run the verification gate again after the last fix, commit new tests apart from fixes, push, and read back as in Step 8.

#### Step 11: Close out

Update the brief in place: the follow-up commits, the review artifact's path and each known risk's state now (`artifact-protocol` › _Rules_ rule 7). Update the work state when the host keeps one, and any page or document the user named as having to follow the change.

---

## 3. Output

```markdown
**Scope:** <repo> @ <head> → <new head> · <n> rows picked · <m> files changed
**Verification:** `<command>`: <result> (one line per command) · not run: <forbidden or skipped, with the reason>

| Row | Proposed change | Outcome (applied / changed / dropped: reason) | Test (`file::test` or `no test`) |
| --- | --------------- | --------------------------------------------- | -------------------------------- |

**Protected files:** <file>: <the hunk> (or: none touched)
**Docs:** <n> line references remapped, <k> corrected by hand
**Brief:** <artifact link block>
```

With `--land`, add:

```markdown
**Commits:** <first>^..<last> on `<branch>`, pushed · follow-up: <shas>
**Review:** <artifact link block> · <r> 🔴 · <y> 🟡 · <g> 🟢

| Finding | Severity | Action (fixed in <sha> / listed / left: reason) |
| ------- | -------- | ----------------------------------------------- |

**Left for you:** <what only another machine or a person can check, with the command>
```

---

## 4. Verification

- `git diff --name-only <baseline>..HEAD` (or `git status --porcelain` without `--land`) lists only files of the picked rows, their tests and the remapped docs; nothing under a no-touch path.
- Every `CHECK`, `AMBIGUOUS` and `UNRESOLVED` row of the `--apply` run was read against its doc sentence. Once the docs are committed, a dry run of `remap_citations.py` reports `0 citation(s) change, 0 to check`.
- The verification gate ran after the last edit of each phase, and its output is quoted in the Output block.
- With `--land`: `git status --short --branch` is level with the upstream and shows nothing the baseline did not already hold, every 🔴 and 🟡 of the review has a row in the findings table, and the brief names the follow-up commits and the review artifact.
