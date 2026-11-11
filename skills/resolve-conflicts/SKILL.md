---
name: resolve-conflicts
description: "Resolves git merge, rebase, cherry-pick, and stash conflicts. Reconstructs intent from the merge base and both commit branches, preserves non-conflicting logic, regenerates lockfiles, runs verification builds/tests, and stages cleanly resolved hunks. Refuses destructive overwrites. `main` mode merges the branch's base in, runs the drift and formatter gates, commits the merge and pushes after your go (\"merge main in\", \"update my branch with main\")."
argument-hint: "[commit | stage-only | main [<base>]] [<paths…>]"
model: sonnet
---

# Skill: `/resolve-conflicts` — Git Conflict Resolution

Resolves in-progress git merges, rebases, cherry-picks, reverts, or stash pops by reconstructing both sides' intent from the merge base, combining non-conflicting changes, regenerating lockfiles/codegen, verifying build and tests, and concluding the operation.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: only when the artifact threshold is met (at least one conflict needed a user decision, or the operation spans >10 conflicted files or multiple rebase stops), then writes `<prefix>-conflict_resolution-<suffix>.md`
- `../_modules/git-worktrees.md`: only with `/wt` or an incoming `[worktree-context]` block
- `../_modules/pr-host.md`: only in `main` mode, read-only, to find the base and the PR

- **Authorization**: invoking `/resolve-conflicts` authorizes editing conflicted files, regenerating lockfiles/codegen and staging resolved paths. It stops there (`stage-only`) by default; the `commit` argument, or a `/commit` that finds the merge resolved, concludes the operation once Step 6's gates hold. Never push or `stash drop`, except the confirmed push in `main` mode (*Step 0c — `main` Mode*).
- **Isolation**: resolve in the tree where the conflict lives (`repo-root`). If a skill worktree is active for the repo and the conflict is in the main checkout, ask first (`git-worktrees` › *Golden Invariants*). If `/wt` is passed to *start* a merge/rebase, run in a workspace worktree (`git-worktrees` › *Workspace Lifecycle*).

---

## Golden Invariants

1. **Never abort or discard** (`merge --abort`, `rebase --abort`, `reset --hard`, `checkout -- .`, `restore .`, `clean`, `stash drop`, `rebase --skip`) unless explicitly instructed.
2. **No blanket side-picking** (`-X ours`/`-X theirs`, `checkout --ours/--theirs .`). Pick a side only per file/hunk with a stated reason.
3. **Resolve, don't rewrite**: combine only what the two sides had; preserve both sides' comments and do not refactor unrelated code.
4. **Stage only resolved paths** (`git -C "$R" add <path>` per file; never `git add -A` or `git add .`).
5. **Ask when sides truly compete** on values/behavior that code, tests, and commit messages do not settle.
6. **Non-interactive git only**: use `GIT_EDITOR=true` for `--continue`.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Clean merge whose build/tests fail afterwards with no conflict left | [`/problem`](../problem/SKILL.md) |
| Squashing or rewriting EF Core migrations that conflict across branches | [`/squash-ef-core-migrations`](../squash-ef-core-migrations/SKILL.md) |
| Reviewing a resolved merge someone else made | [`/code-review`](../code-review/SKILL.md) (`git show --remerge-diff <sha>`) |

---

## 2. Core Protocol & Workflow

### Step 0 — Detect the Operation, the Sides and the Repo

Use `git rev-parse --git-path` so detection works inside linked worktrees (a lone `REBASE_HEAD` without `rebase-merge` / `rebase-apply` is ignored as a leftover):

Run each as its own Bash call. `command ls -d` prints the paths that exist and errors on the rest; each existing path names the operation in progress:

```bash
git -C <repo-root> rev-parse --path-format=absolute --git-path MERGE_HEAD --git-path CHERRY_PICK_HEAD --git-path REVERT_HEAD --git-path rebase-merge --git-path rebase-apply
command ls -d <the five printed paths>
git -C <repo-root> status --porcelain=v2 --branch
git -C <repo-root> diff --name-only --diff-filter=U
```

Unmerged paths with no head file and a stash in `git stash list` indicate a conflicted **stash pop/apply**.

Always name sides by **branch name**, never `"ours"`/`"theirs"` (in a rebase, `--ours` / `:2:` is the upstream branch being rebased **onto** and `--theirs` / `:3:` is **your commit being replayed**):

| Operation | `--ours` / `:2:` | `--theirs` / `:3:` | Where to read intent |
|---|---|---|---|
| `merge X` | current branch (`HEAD`) | `X` (`MERGE_HEAD`) | `git log --oneline --merge`, `git name-rev MERGE_HEAD` |
| `rebase onto U` | `U` + already-replayed commits | commit being replayed (`REBASE_HEAD`) | `git show REBASE_HEAD`; `rebase-merge/head-name`, `onto`, `done` |
| `cherry-pick C` / `revert C` | current branch | `C` | `git show CHERRY_PICK_HEAD` / `REVERT_HEAD` |
| `stash pop/apply` | current branch | the stash | `git stash show -p stash@{0}` |

Also check `git -C "$R" rerere status` and `rerere diff` to verify any auto-replayed resolution.

#### Step 0b — No Operation in Progress

Preview conflicts without touching the tree (`git -C "$R" merge-tree --write-tree --name-only HEAD origin/<target>`). If the user asked to update the branch and the working tree is clean of tracked edits, start the repo's standard operation (merge by default; rebase only when requested or required by repo rules).

#### Step 0c — `main` Mode

`/resolve-conflicts main [<base>]` brings the current branch up to date in one merge commit:

1. **Preflight:** refuse on the default branch, a detached HEAD or tracked working-tree edits (never stash). **Base:** the argument, else the open PR's target branch (`pr-host` › *Resolve the PR from a branch*), else `origin/HEAD`; never assume `main`.
2. **Merge:** `git -C "$R" fetch origin`, then `git -C "$R" merge --no-commit --no-ff <base>` (`--no-commit` keeps gate output in the merge commit). Already up to date → say so and stop.
3. **Resolve** per Steps 1–5. Keep this branch's structure and fold the base's additions in; when the base already holds this branch's own work (a squash-merged PR it stacked on), prefer this branch's hunks and say so per file. Mark each conflict trivial or non-trivial (competing values, shape vs. content, modify/delete, or a user decision).
4. **Gates:** run [`/commit`](../commit/SKILL.md) › *Step 2: Skill-drift gate (before grouping)* and the repo's formatters and import sorters (`commit` › *Step 4: Run the repo's pre-commit gates*) on the merged files. Stage every file they modify; `git -C "$R" status --short` must show no unstaged tracked edits.
5. **Commit** per Step 6 (merge row), then show `git -C "$R" diff --stat HEAD^1 HEAD`.
6. **Push:** list the non-trivial conflicts with their resolutions and ask; push per `commit` › *Step 6: Push* only on the user's go.

### Step 1 — Inventory and Classify Every Conflicted Path

| Kind | Signal | Resolution route |
|---|---|---|
| **Content** (`UU`) | Conflict markers in text file | Hunk-by-hunk (Step 3) |
| **Add/add** (`AA`) | Both sides created the path | Combine if same purpose; ask if unrelated |
| **Modify/delete** (`UD`/`DU`) | Deleted/moved on one side, edited on the other | Trace move (`git log --follow --diff-filter=R`, `git log -S'<symbol>'`), port edit and `git rm` old path, or ask |
| **Lockfile** | `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Cargo.lock`, `uv.lock`, `poetry.lock`, `packages.lock.json`, `go.sum` | Never hand-merge; resolve manifest first, then regenerate (Step 3c) |
| **Generated** | `*.gen.*`, ORM/OpenAPI/test snapshots, `dist/` | Regenerate from merged sources |
| **Binary / Submodule** | Binary diff or mode `160000` | Ask the user which side/commit to take |

Also record files git **merged cleanly** that both sides touched (`git diff --name-only <merge-base> HEAD` ∩ other side) for Step 4.

### Step 2 — Extract Both Sides' Intent

**Step 2 Exit Bound:** Before editing a path, run `git -C "$R" checkout --conflict=zdiff3 -- <path>` (base inside the markers, so one read replaces `:1:`/`:2:`/`:3:`) and `git -C "$R" log --oneline --left-right --merge -- <path>`, then state each side's intent in one sentence. Trivial hunks (identical change, independent additions such as imports or list entries) need no intent sentence; quote commit messages only for non-trivial ones. Read `:1:`/`:2:`/`:3:` in full only when the markers don't settle a hunk.

### Step 3 — Resolve Hunk by Hunk

1. **Pick the pattern per hunk**: **Independent additions** (keep both, ordered by file convention), **Identical change** (keep one), **Shape vs. content change** (apply content edit to new shape), **Composing edits** (apply both), **Competing values** (ask the user if tests/commits/ticket don't settle it), **Formatting vs. logic** (keep logic, run formatter).
2. **Edit precisely** and re-read the edited hunks (not the whole file) to confirm valid syntax, balanced braces/JSX, and used imports.
3. **Lockfiles & generated files**: reset lockfile to the base tree (`--theirs` on merge, `--ours` on rebase) and regenerate in lockfile-only mode (`npm install --package-lock-only`, `pnpm install --lockfile-only`, `yarn install --mode update-lockfile`, `cargo update -w`, `uv lock`, `dotnet restore --force-evaluate`); rerun code/snapshot generators.
4. **Stage per path**: `git -C "$R" add <path>` (or `git -C "$R" rm <path>`).

### Step 4 — Hunt for Semantic Conflicts

Across both conflicted and cleanly-merged files, check for: symbols removed/renamed on one side that the other side added callers for, function signature changes vs. new call sites, duplicate helpers/routes/migration numbers/keys, and ordered registrations.

### Step 5 — Verify the Merged Tree

```bash
git -C "$R" diff --check                       # leftover conflict markers and whitespace errors
git -C "$R" diff --name-only --diff-filter=U   # must be empty
git -C "$R" status --short                     # only intended paths staged; untracked files untouched
```

Run once per operation: the repo's build/type-check and fast lint gates, only the tests for projects or folders the merge touched (the full suite only when the repo has no scoped runner), and the project's *Post-merge checks* (`project-profile` › *Discovery*) when the base profile lists them. Fix any failure introduced by the merge; report pre-existing single-side failures.

### Step 6 — Conclude

When `commit` was passed (or `/commit` is concluding a resolved merge), `diff --check` and `--diff-filter=U` are clean, Step 5 gates pass, and no question is open:

| Operation | Conclude with | Then |
|---|---|---|
| `merge` | `git -C "$R" commit --no-edit --cleanup=strip` (plus trailer per [`/commit`](../commit/SKILL.md) › *Step 4: Write the message and commit*; `--cleanup=strip` drops `# Conflicts:` comment lines) | `git -C "$R" show --remerge-diff HEAD` |
| `rebase` | `GIT_EDITOR=true git -C "$R" -c core.commentChar=';' rebase --continue` (keep user's commit message, add no trailer) | Repeat Steps 0–4 and Step 5's three git checks per stop; build and tests once at the end; then compare `git log --format=%s` with the original subjects |
| `cherry-pick` / `revert` | `GIT_EDITOR=true git -C "$R" -c core.commentChar=';' cherry-pick --continue` / `revert --continue` | Repeat per stop |
| `stash pop/apply` | Leave resolved changes in tree; never `stash drop` | Report that stash entry is kept |

Confirm the operation state files from Step 0 are gone and report the new short SHA. Never push (`main` mode: Step 0c.6).

---

## 3. Output Format & Deliverables

In chat, report: (1) **Operation & sides by branch name**, (2) **Per-file resolution summary**, (3) **Decisions**, (4) **Semantic checks**, (5) **Verification gates run/skipped**, and (6) **Concluded SHA** (or blocking condition + exact concluding command). When the artifact threshold is met, publish `<prefix>-conflict_resolution-<suffix>.md` with the same 6 sections and emit the `artifact-protocol` › *Chat link block*.

---

## 4. Verification & Validation

- `git diff --name-only --diff-filter=U` is empty, `git diff --check` is clean, and build/test gates pass.
- Only resolved paths and regenerated lockfiles/codegen were staged; after a merge commit, `git show --remerge-diff HEAD` matches the reported resolutions and has no `# Conflicts:` lines; nothing was pushed outside a confirmed `main`-mode push.

---

## Pitfalls

| Pitfall | Guard |
|---|---|
| Swapping ours/theirs during a rebase | Name sides by branch (Step 0 table) and read `REBASE_HEAD` for the replayed commit |
| `checkout --conflict=zdiff3` after editing | Run only before editing; it overwrites working-tree edits on that file |
| `git commit --no-edit` leaving `# Conflicts:` in commit message | Always pass `--cleanup=strip` |
| A commit subject starting with `#` (e.g. `#31471: …`) is stripped as a comment on `rebase --continue`, so the commit is dropped | Pass `-c core.commentChar=';'` on `--continue` (simulated 2026-11-06: default loses the commit, `;` keeps the subject) |
| `.git` treated as a directory inside a linked worktree | Always use `git rev-parse --git-path <name>` |
