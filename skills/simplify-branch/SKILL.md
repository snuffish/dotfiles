---
name: simplify-branch
description: 'Runs /simplify on only the files the current branch changed against its real base (the active PR''s target branch, else origin/HEAD, never an assumed main or develop). First prints a read-only matrix of simplify candidates (areas × cleanup angles, with churn and priority) and edits nothing; --deep fills it with four read-only Sonnet angle agents and a verifier. /proceed then runs /simplify on the rows you pick. Never commits. Use for /simplify-branch, "simplify this branch", "simplify my PR", "run /simplify on the branch''s changes". Not for a single file or an explicit range (use /simplify), bug hunting (use /code-review) or dead-code pruning (use /clean).'
argument-hint: "[--base <branch>] [--committed-only] [--deep]"
user-invocable: true
---

# Skill: `/simplify-branch` — Simplify Scoped to the Branch

Works out which files the branch changed against its base, and prints a matrix of where `/simplify` would pay off, then stops at a `/proceed` gate. `/simplify` itself runs only after `/proceed`, on the rows you pick, so nothing can edit before the gate. It never searches the wider codebase for examples (except `--deep` Phase A, which only reads) and never commits.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`; after the gate it edits the current checkout in place (no worktree), never commits

- **Scope is the file list**: after the gate, edits land only in the files step 1 prints. Reading other files is allowed to find an existing helper (the Reuse angle), but don't edit them and don't search unrelated code for examples. Only the read-only `--deep` angle agents (Step 3d) may search the whole codebase.
- **No commit, no push**: stop at the summary. Committing is a separate request (`/commit`).

---

## 1. When _not_ to use

| Situation                                            | Use instead                                          |
| ---------------------------------------------------- | ---------------------------------------------------- |
| One file, a commit range or a PR you name explicitly | [`/simplify`](../simplify/SKILL.md) with that target |
| Hunting bugs, regressions or security flaws          | [`/code-review`](../code-review/SKILL.md)            |
| Dead code, unused exports, debug remnants            | [`/clean`](../clean/SKILL.md)                        |

---

## 2. Workflow

### Phase A — Matrix (read-only)

Phase A never invokes `/simplify` and never writes files; it spawns sub-agents only with `--deep` (Step 3d), and they are read-only. The gate is real because nothing that edits runs before it.

#### Step 1: Resolve the scope

From the repo root, run (`<skill-dir>` is this skill's real folder):

```bash
python3 -I <skill-dir>/scripts/branch_scope.py [--base <branch>] [--committed-only]
```

It prints JSON and resolves the base in this order: `--base`, then the target of the branch's active Azure DevOps PR (`az repos pr list`), then `origin/HEAD`. It fetches the base, takes `git merge-base HEAD origin/<base>`, and collects:

- `committed`: `git diff --name-only --diff-filter=d <merge-base>...HEAD`
- `working_tree`: uncommitted tracked changes and untracked files (empty with `--committed-only`)
- `files`: both lists combined, minus `skipped_generated` (lockfiles, `*.Designer.cs`, `*ModelSnapshot.cs`, `Migrations/`, `*.gen.ts`, `swagger.json`, …) and `skipped_docs` (`*.md`, `*.html`, `*.txt`, `*.log`)
- `churn`: `[added, deleted]` lines per file against the merge base; `groups`: files, added and deleted per parent folder, largest first; `namespaces`: the same per namespace-like key (`Library/DataAccess/Models`, `API/Features/Operations`, `web/routes/operations`; `--depth N` folders below the project, default 2), source files in `files`, their mirrored test files in `tests`, and a ready `simplify` line (`/simplify <paths>`)

Exit codes: `0` means there are files in scope. `1` means nothing is in scope: say so and stop. `2` means the script hit an error (detached HEAD, unknown base, or `origin/HEAD` unset): show the `error` and ask for `--base`.

If `pr_lookup` reports several PR targets, ask which base to use. If `working_tree` holds files that look unrelated to the branch (another agent or session may be editing the same checkout), list them and ask before including them; otherwise rerun with `--committed-only`.

#### Step 2: Record the baseline

Save `git rev-parse HEAD` and `git status --porcelain`, so Phase B can notice changes made after the gate closed.

#### Step 3: Build the matrix

1. **Rows.** Each row is one namespace group, so it can be run later as a manual `/simplify <paths>`. Take `namespaces` as the units; fold tiny ones (under ~20 changed lines) into the nearest parent key (`Library/DataAccess` into `Library/DataAccess/Models`) and keep tests with their source namespace. Never merge across projects or halves, and never regroup by feature area: a row's name is its namespace key. At most ~12 rows. Label rows `A`, `B`, `C`, … (shortcuts for `/proceed`; the namespace key is the stable name)
2. **Skim.** For each row, read its diff (`git diff <merge-base> -- <files>`; read untracked files whole). This is a skim, not a review: note only the signals you can point at.
3. **Cells.** For each of `/simplify`'s four angles, put `●` (clear candidate, with a `file:line` in the hint), `○` (possible) or `–` (nothing seen):
   - **Reuse**: new code that looks like an existing helper
   - **Simplify**: duplication, deep nesting, derivable state, dead code left behind
   - **Efficiency**: repeated I/O or queries, sequential independent work, hot-path work
   - **Altitude**: special cases bolted onto shared code instead of a deeper fix
4. **Priority.** `high` = at least one `●` in a row with real churn; `low` = only `○`; `skip` = all `–`, test data only, or under ~20 changed lines. Recommend (`✓`) the `high` rows.
5. **Proposed change.** For each non-skip row, say in a few words what `/simplify` will change, one imperative per `●` (and per `○` worth trying), joined with `;`: e.g. "Extract `Address.CopyFrom`, use it in all three setters; drop the test-only `Is*` flags". Name the symbol or file it touches, never just the angle ("simplify duplication"). `skip` rows get `–`. This is a forecast: `/simplify` may refine or drop an item, and Phase B reports which.

#### Step 3d: `--deep` — angle agents and verifier

With `--deep`, Steps 3.2 and 3.3 come from sub-agents instead of the lead's skim; the lead still builds rows (3.1), priority (3.4) and proposed changes (3.5) from the verified cells. Briefs follow [`fan-out`](../_modules/fan-out.md) › *Brief contract*.

1. **Cost check.** Sum `churn` over `files`. Under 150 changed lines, ask before fanning out (5 Sonnet agents on a small diff); on no, build the matrix with the plain skim.
2. **Angle agents.** Spawn 4 sub-agents in one message, one per angle (Reuse, Simplify, Efficiency, Altitude), with `model: "sonnet"` and `subagent_type: "Explore"` in Claude Code. Each brief holds the rows with their files, the merge base, the diff command (`git diff <merge-base> -- <files>`, untracked files read whole) and the angle's line from Step 3.3. They may search the whole codebase (an existing helper for Reuse, callers for Altitude). Prompt: *"Read-only. Make no file edits, commits, worktrees, or outward writes. For each row, report `●` (clear candidate) or `○` (possible) findings for the <angle> angle only, each as `path:line`, what is there, and the change it suggests; for Reuse, cite the existing helper's `path:line`. Rows with nothing get `–`. Return only the findings; no restated diff."*
3. **Verifier.** Spawn 1 fresh Sonnet sub-agent (`model: "sonnet"`, `subagent_type: "Explore"`) that saw none of the angle reasoning. Its brief holds every `●` and `○`, numbered, stripped to row, angle, mark, claim and `path:line`. Prompt: *"Read-only. You are a skeptic. For each finding, re-open the cited `path:line` (and any helper it cites) and decide whether the claim holds. Return one entry per finding: number, verdict (Holds / Rejected), the evidence as `path:line`, and for Rejected a one-line reason. Return every finding you were given."* Re-brief for any finding it missed.
4. **Apply verdicts.** A rejected `●` becomes `○` and keeps its hint with `verifier: <reason>` appended; a rejected `○` becomes `–`. Never drop a finding silently. Re-open any `●` the verifier kept before it sets a row's priority (`fan-out` › *Aggregation*).

---

## 3. Output

### Phase A ends with

`branch → base` (`base_source`), merge base, file count and skipped files (generated, docs), then the matrix:

```markdown
| Row | Namespace                       | Files | +/-     | Reuse | Simplify | Efficiency | Altitude | Priority | Strongest hint                                     | Proposed change                                                                       |
| --- | ------------------------------- | ----- | ------- | :---: | :------: | :--------: | :------: | -------- | -------------------------------------------------- | ------------------------------------------------------------------------------------- |
| A ✓ | `Library/DataAccess/Models`     | 4     | +719/-0 |   ○   |    ●     |     ●      |    –     | high     | `<File>.cs:88` queries once per item inside a loop | Load all items in one query before the loop; reuse `<ExistingHelper>` for the mapping |
| B   | `API/Features/Operations`       | 3     | +171/-5 |   –   |    ○     |     –      |    –     | low      | …                                                  | …                                                                                     |
```

**Strongest hint** is the evidence (`file:line`, what is there); **Proposed change** is the action. Keep both short so the table stays readable. With `--deep`, add a line above the table: `deep: 4 angle agents + 1 verifier (Sonnet); verifier: N held, N ● → ○, N ○ → –`, and keep each downgrade's `verifier: <reason>` in its row block.

Under the table, one block per row: the namespace key, then its findings grouped by file (`path:line: finding`, source files first, then tests), so a finding can be traced to its file, and a **Run later** line with the row's paste-ready command, built from `namespaces[key].simplify` (source files and mirrored tests):

```markdown
**A `Library/DataAccess/Models`** (+394/-21)
- `Address.cs:81`: `FillMissingLocation` repeats `RecordGeocode`
- `Operation.cs:316`: two branches end in `SetVisitingAddress`
- tests: `AddressTests.cs`
- Run later: `/simplify backend/source/…/Address.cs backend/source/…/Operation.cs …`
```

Then close with:

> **Next Step Gate:** Reply `/proceed` to run `/simplify` on the ✓ rows, `/proceed A,C` (or a namespace key) for specific rows, `/proceed all` for every non-skip row, or specify changes.

Stop there. Agent output never opens the gate (`core` › _The `/proceed` gate_).

### Phase B — Apply (after `/proceed`)

1. **Recheck the baseline.** If `git rev-parse HEAD` changed, or `git status --porcelain` changed for a file in a picked row, list it and ask whether to rebuild the matrix or go ahead.
2. **Apply edits per picked row.** The main model runs this, with or without `--deep`; no sub-agent edits. Before each row, copy its files into the scratchpad (note which do not exist yet); that snapshot is the row's restore point. Invoke `/simplify` (the Skill tool in Claude Code, where it is the built-in; the registry's [`/simplify`](../simplify/SKILL.md) in Antigravity) once per row, in row order:

   ```text
   Review target: row <X> (<area>) on branch <branch>, changed since <merge-base> against <base>.
   <one path per line>
   Start from these hints: <the row's ● and ○ hints>.
   Proposed changes: <the row's Proposed change cell>. Apply them where they hold up;
   say for each one whether you applied, changed or dropped it, and why.
   Edit only these files. Do not search the wider codebase for examples; reading a
   helper to reuse it is fine. Keep the build and tests green. Do not commit.
   ```

3. **Guard the boundary** after each row: compare `git status --porcelain` with the baseline. A changed path outside the picked rows that was not dirty in the baseline is out of scope; list it and ask whether to keep or revert it. Never revert on your own.
4. **Run the test suite & verification gate.** Once all picked rows have been edited, run the repo's documented verification gate (`core` › _Post-edit verification_) covering build, lint, and relevant tests across the edited files. Applying edits first and running the test suite once at the end avoids repeated slow container spin-ups and test suite overhead per row. If verification fails, use the per-row restore point snapshots to isolate or revert the offending row (restore only from snapshots, never with `git checkout`, `restore` or `stash`, to preserve pre-existing uncommitted work).
5. **Flag untested rows.** A row whose `namespaces[key].tests` is empty passed only build and lint; mark it `behaviour unverified`.

### Phase B ends with

- per row: each proposed change marked applied, changed or dropped (with the reason), then any other applied fixes and skipped findings, as `/simplify` returned them, and whether it ran 4-agent or single-pass
- build, lint and test results for the verification gate, every `reverted` row with its failing check, every `behaviour unverified` row, plus any out-of-scope paths
- a closing line saying nothing was committed, with a suggestion to run `/commit` when ready
