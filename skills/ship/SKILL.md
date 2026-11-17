---
name: ship
description: "Ships the current branch in one run: commits pending work through /commit, scans the whole branch for secrets when the repo is public, merges the base branch in through /resolve-conflicts main mode, checks every JSON file the merge touched, runs the tests for the branch's changes, then pushes and regenerates the open PR's description (4000-character cap) through /commit. Use for /ship, \"ship it\", \"merge main, test and push\"."
argument-hint: "[no-tests] [base] [message or intent]"
disable-model-invocation: true
model: sonnet
---

# Skill: `/ship` — Merge the Base, Test, Commit and Push

Chains [`/commit`](../commit/SKILL.md) and [`/resolve-conflicts`](../resolve-conflicts/SKILL.md) `main` mode, and adds a JSON check and a test run between them. The commit, merge, push and PR rules live once, in those two skills; this skill points at their steps and never copies them.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module or linked skill cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../commit/SKILL.md` and the Modules it lists
- `../resolve-conflicts/SKILL.md` (Step 0c and Steps 1–6)

- Invoking `/ship` authorizes everything `/commit` authorizes (its *Modules* bullet on `outward-writes`) plus the merge commit of Step 3. It does not lift `resolve-conflicts` › *Step 0c* item 6: non-trivial conflicts are listed and the push waits for the user's go.
- `<base>` is the argument, else the open PR's target branch, else `origin/HEAD` (`resolve-conflicts` › *Step 0c* item 1); never assume `main`.
- `no-tests` skips Step 5 only; the output then lists the test commands for the user to run.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Commit and push without merging the base or running the tests | [`/commit`](../commit/SKILL.md) |
| Branch from a work item, commit, push and open a PR | the project's ship skill (e.g. `priis-ship`), when the workspace has one |
| Only bring the branch up to date with its base | [`/resolve-conflicts`](../resolve-conflicts/SKILL.md) `main` |
| A merge, rebase or cherry-pick is already in progress | [`/resolve-conflicts`](../resolve-conflicts/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Commit the pending work

Run `commit` Steps 1–5 (stops, drift gate, staging and its secret check, pre-commit gates, message), with the user's message or paths from the arguments. Skip its Steps 6–8: the push comes in Step 6 here. Nothing to commit → go on; nothing to commit and the branch already contains `<base>` and has nothing to push → say so in one line and stop.

`resolve-conflicts` › *Step 0c* refuses tracked working-tree edits, so anything `/commit` left out on purpose must be untracked or ignored. A tracked file left out → stop, name it and ask.

### Step 2: Scan the whole branch when the repo is public

`commit` Step 3 scans only the new commit. A public repo also gets the branch's earlier commits scanned, before anything new reaches the remote.

1. **Visibility** of `git -C <repo-root> remote get-url origin`:
   - GitHub: `gh repo view <owner>/<repo> --json visibility -q .visibility` → `PUBLIC`.
   - Azure DevOps: `az devops project show --project <project> --org <org-url> --query visibility -o tsv` → `public`.
   - Another host, or the command fails → treat it as public.
2. **Private** → state `"private repo: commit scan only"` and go to Step 3.
3. **Public** → run the `commit` Step 3 secret regex on `git -C <repo-root> diff -U0 <base>...HEAD`. A hit stops the run before any push: mask the value, name the file and commit (`git -C <repo-root> log -S'<masked prefix>' --oneline <base>..HEAD`) and ask. A secret already in a pushed commit needs rotating, not only removing; say so.

### Step 3: Merge the base

Run `resolve-conflicts` › *Step 0c* items 1–4 with `<base>`. Already up to date → state it and go to Step 5.

### Step 4: Check the JSON the merge touched

Before the merge commit (`resolve-conflicts` › *Step 0c* item 5), parse every JSON file the merge brings in or resolved:

```bash
git -C <repo-root> diff --cached --name-only --diff-filter=AM HEAD -- '*.json'
python3 -I <this skill's real folder>/scripts/check_json.py <file> …   # absolute paths under <repo-root>
```

The script parses each file, fails on duplicate keys (which `json.load` accepts silently, so a resolution that kept both sides' copy of a key passes a plain parse), and skips files that allow comments by convention (`tsconfig*.json`, `*.jsonc`, `devcontainer.json`, `.vscode/`).

- **`FAIL` line** → fix it within the merge (a leftover marker, a missing comma between two sides' entries, a duplicated key), re-stage, re-run. Not fixable from both sides' intent → stop with the file and the error.
- **`skip` line** → name the file in the output; check its hunks by eye.
- A lockfile is regenerated, not checked here (`resolve-conflicts` › *Step 3 — Resolve Hunk by Hunk* item 3).

Then commit the merge per `resolve-conflicts` › *Step 0c* item 5.

### Step 5: Run the tests

Skip under `no-tests`. Otherwise run the test commands the repo's rulebook documents (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, the project's verify skill), scoped to the projects or folders in `git -C <repo-root> diff --name-only <base>...HEAD` when the runner supports it; the full suite only when it has no scoped runner. Tests `resolve-conflicts` › *Step 5* already ran on the merge are not run again.

- **No test command documented** → state `"no tests documented"` and go on.
- **A failure** → fix it when this branch caused it (as its own commit per `commit` Step 5) and re-run that test once. A failure that also fails on `<base>`, or one not fixable → stop before pushing and report the output.

### Step 6: Push and update the PR

Before pushing, when Step 3 had non-trivial conflicts, list them with their resolutions and wait for the user's go (`resolve-conflicts` › *Step 0c* item 6).

Then run `commit` Steps 6–8: push, regenerate the open PR's description within the 4000-character budget, remove the worktree. No open PR → `commit` Step 7 reports it; `/ship` never creates one.

---

## 3. Output Format & Deliverables

`commit`'s output block, with these lines added after its `Files` line:

```markdown
- Secrets: public repo, branch scanned (<n> commits) ✅ (or: private repo, commit scan only)
- Merged: `<base>` @ `<short-sha>` (<n> conflicts: <trivial / non-trivial files> | clean | already up to date)
- JSON: <n> files parsed ✅ (skipped as JSON with comments: <files>)
- Tests: <commands> ✅ (or: no tests documented · skipped (no-tests): run <commands>)
```

---

## 4. Verification & Validation

- `git -C <repo-root> merge-base --is-ancestor <base> HEAD` succeeds.
- `commit` › *4. Verification & Validation* holds.
- Under a public repo, no push ran before the Step 2 scan was clean.
- No push ran with a failing test or an unparsed JSON file the merge touched.
