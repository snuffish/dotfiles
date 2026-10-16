---
name: resolve-conflicts
description: Resolves git conflicts from an in-progress merge, rebase, cherry-pick, revert or stash pop, and previews the conflicts a branch will have with its target. Detects the operation and which side is "ours" and "theirs" (the two swap during a rebase), works out what each side meant from the merge base and the commits on each side, and resolves every conflicted hunk by keeping both sides' intent. Additive edits are combined, lockfiles and generated files are regenerated rather than merged by hand, and conflicts that need a real choice are asked about. Also checks the files git merged cleanly for semantic breakage, runs the repo's type-check and tests, and stages only the resolved paths. It does not commit or continue unless asked, and never aborts, blanket-picks a side or discards work. Trigger on /resolve-conflicts, "resolve conflicts", "fix the merge conflicts", "rebase conflicts", "my cherry-pick conflicted", "stash pop conflict", "UU in git status", "the PR has conflicts with main", or "update my branch with main".
---

# Skill: `/resolve-conflicts` — Git Conflict Resolution

Finishes the half of a merge, rebase, cherry-pick, revert or stash pop that git could not do on its own. For every conflict it works out what each side meant, writes a resolution that keeps both, checks that the merged result still builds and passes its tests, and leaves the operation staged and ready for the user to conclude.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **Target Artifact**: none by default — the deliverable is the resolved, staged tree and a per-file summary in chat. When at least one conflict needed a user decision, or the operation spans more than ~10 conflicted files or several rebase stops, also write `<prefix>-conflict_resolution-<suffix>.md` at the **workspace root** (where `<prefix>` is `<host>-<model>-`, e.g. `claude-opus-5.5-`). The suffix is the branch pair, for example `-settings-screen-into-main` or `-rebase-onto-main`.
- **Anti-Overwrite Rule**: Always include the active AI model in `<prefix>` and append the descriptive kebab-case `<suffix>`. Never write unsuffixed or un-modeled generic files.
- **Authorization**: invoking the skill authorizes editing the conflicted files, regenerating lockfiles and generated files, and staging the resolved paths. It does **not** authorize `commit`, `merge --continue`, `rebase --continue`, `cherry-pick --continue`, `push`, or dropping a stash. Those need the word `continue`/`commit` in the invocation or an explicit instruction from the user.
- **Isolation**: a conflict lives in the checkout where the operation is in progress, so resolve it there. Honour a handed-in `[worktree-context]` block: every `git` command and every file path resolves under its `repo-root`. Under core §2.4 the main checkout is read-only while a skill worktree is active for the repo. If the conflict is in the main checkout at that point, stop and ask. When the invocation contains `worktree` or `/git-worktrees` and has to *start* the operation (e.g. "update my branch with main"), run it in a workspace worktree per [`git-worktrees`](../git-worktrees/SKILL.md) §5.

---

## ⛔ Golden Invariants

> [!CAUTION]
> 1. **NEVER ABORT OR DISCARD.** No `merge --abort`, `rebase --abort`, `reset --hard`, `checkout -- .`, `restore .`, `clean`, `stash drop` or `rebase --skip` unless the user explicitly asks. Each of these throws away the user's work or a whole commit.
> 2. **NO BLANKET SIDE-PICKING.** No `-X ours`/`-X theirs`, no `checkout --ours/--theirs .`, no `--strategy=ours`. A side is taken per file or per hunk, with a stated reason.
> 3. **RESOLVE, DON'T REWRITE.** The result contains only what one side or the other already had, combined. Don't refactor, rename or "improve" code while resolving. Keep both sides' comments.
> 4. **STAGE ONLY RESOLVED PATHS.** `git add <path>` per file. Never `git add -A`, `git add .` or `commit -a`, because untracked files (artifacts, scratch files, `.env`s) would go into the merge commit.
> 5. **ASK WHEN THE SIDES TRULY COMPETE.** If the two sides want different values for the same thing and nothing in the code, tests or commit messages decides it, ask the user with both options. Never pick one silently.
> 6. **NON-INTERACTIVE GIT ONLY.** No `mergetool`, no `-i`, no editor. Use `GIT_EDITOR=true` for `--continue`.

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/resolve-conflicts` (optionally with `continue`, `commit`, a target branch, or `worktree`).
- `git status` shows unmerged paths (`UU`, `AA`, `DU`, `UD`, `AU`, `UA`, `DD`) or "You have unmerged paths".
- A merge, rebase, cherry-pick, revert or `stash pop/apply` stopped on conflicts.
- A PR reports conflicts with its target, or the user asks to bring a branch up to date with `main` (preview first, see Step 0b).

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| The merge went through but the build or tests fail afterwards, and no conflict is left | [`/problem`](../problem/SKILL.md) |
| Squashing or rewriting EF Core migrations that conflict across branches | [`/squash-ef-core-migrations`](../squash-ef-core-migrations/SKILL.md) |
| Reviewing a resolved merge someone else made | [`/code-review`](../code-review/SKILL.md) on the merge commit (`git show --remerge-diff <sha>`) |

---

## 2. Core Protocol & Workflow

### Step 0 — Detect the Operation, the Sides and the Repo

Resolve the repo root first (`[worktree-context]` → `repo-root`, else `git rev-parse --show-toplevel`). Then find out which operation is in progress. Use `git rev-parse --git-path` so it also works inside linked worktrees, where `.git` is a file:

```bash
R=<repo-root>
for f in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD REBASE_HEAD rebase-merge rebase-apply; do
  p=$(git -C "$R" rev-parse --git-path "$f"); [ -e "$R/$p" ] || [ -e "$p" ] && echo "$f"
done
git -C "$R" status --porcelain=v2 --branch
git -C "$R" diff --name-only --diff-filter=U
```

No head file but unmerged paths, with the stash still listed in `git stash list`, means a conflicted **stash pop/apply**.

Name the two sides by **branch**, not by "ours/theirs". Which side is which depends on the operation:

| Operation | `--ours` / stage `:2:` | `--theirs` / stage `:3:` | Where to read the "theirs" intent |
|---|---|---|---|
| `merge X` | current branch (`HEAD`) | `X` (`MERGE_HEAD`) | `git log --oneline --merge`, `git name-rev MERGE_HEAD` |
| `rebase onto U` | **`U` + the already-replayed commits** | **your commit being replayed** | `git show REBASE_HEAD`; `rebase-merge/head-name`, `onto`, `done`, `git-rebase-todo` |
| `cherry-pick C` / `revert C` | current branch | `C` (or its inverse) | `git show CHERRY_PICK_HEAD` / `REVERT_HEAD` |
| `stash pop/apply` | current branch | the stash | `git stash show -p stash@{0}` |

> [!WARNING]
> In a rebase, "ours" is the branch you are rebasing **onto** and "theirs" is **your own work**. Saying "kept ours" in a rebase usually means you threw away your own commit. Always report sides by branch name.

Check whether `rerere` already applied a recorded resolution (`git -C "$R" rerere status`, `git -C "$R" rerere diff`). A replayed resolution was right for a different context once, so verify it like any other resolution rather than trusting it.

#### Step 0b — No Operation in Progress

- **Preview** a merge without touching the tree (git ≥ 2.38). Show the user the conflicted paths it lists:
  ```bash
  git -C "$R" fetch origin
  git -C "$R" merge-tree --write-tree --name-only HEAD origin/<target>   # exit 1 = conflicts; lists them
  ```
- If the user asked to update the branch, start the operation the repo uses (merge by default; rebase only if the user or the repo's workflow rules say so, and never on a branch other people have pulled). The working tree must be clean of tracked changes first. If it isn't, stop and ask; don't stash on the user's behalf.
- If nothing is in progress and nothing was asked, report that there is nothing to resolve.

### Step 1 — Inventory and Classify Every Conflicted Path

List each unmerged path with its porcelain code. Then classify it **before** editing anything:

| Kind | Signal | Resolution route |
|---|---|---|
| **Content** (`UU`) | Conflict markers in a text file | Hunk-by-hunk (Step 3) |
| **Add/add** (`AA`) | Both sides created the same path | Combine if both are the same kind of file; ask if they are unrelated |
| **Modify/delete** (`UD`/`DU`) | One side deleted or moved the file, the other edited it | Find where the code went (`git log --follow --diff-filter=R`, `git log -S'<symbol>'`). Port the edit there and `git rm` the old path, or keep the file if the deletion was wrong. Ask if unclear |
| **Lockfile** | `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`, `Cargo.lock`, `poetry.lock`, `uv.lock`, `Gemfile.lock`, `composer.lock`, `packages.lock.json`, `go.sum` | Never hand-merge. Resolve the manifest first, then regenerate (Step 3c) |
| **Generated** | `*.gen.*`, ORM model snapshots, OpenAPI/swagger snapshots, test snapshots, compiled assets, `dist/` | Regenerate from the source of truth with the project's generator. Never hand-merge |
| **Binary** | `git diff` shows "Binary files differ" | Take one side explicitly (`git checkout --ours/--theirs -- <path>`) only after asking the user |
| **Submodule** | Mode `160000` | Choose the commit the user wants (usually the newer one that includes both sides). Ask |

Also note the files git **merged cleanly** that both sides touched (`git -C "$R" diff --name-only <merge-base> HEAD` ∩ the other side's changes). These are where semantic conflicts hide (Step 4).

### Step 2 — Understand Both Sides' Intent

For each conflicted file, look at three versions and the history behind each side:

```bash
git -C "$R" show :1:<path>    # merge base
git -C "$R" show :2:<path>    # ours  (see the table in Step 0 for which branch that is)
git -C "$R" show :3:<path>    # theirs
git -C "$R" log --oneline --left-right --merge -- <path>      # merge: the commits on each side that touched it
git -C "$R" diff <merge-base> <side> -- <path>                # what one side changed, in isolation
```

To see the base inside the markers, re-render a file with `zdiff3` markers. **This discards any edits already made to that file**, so do it before editing, never after:

```bash
git -C "$R" checkout --conflict=zdiff3 -- <path>
```

Read the commit messages, PR descriptions and any linked ticket for each side. Write down each side's intent in one sentence ("main: replaced the shader resend with `edit_scene_code`"; "branch: added a Settings section"). The resolution has to satisfy both sentences.

### Step 3 — Resolve Hunk by Hunk

#### 3a. Pick the pattern for each hunk

| Pattern | Example | Resolution |
|---|---|---|
| **Independent additions** | Both sides added a changelog section, an import, a route, an enum member, a list entry | Keep both, ordered by the file's convention (newest-first changelog, sorted imports, registration order) |
| **Identical change** | Both sides made the same fix | Keep one copy |
| **Shape change vs content change** | One side extracted, renamed or moved code; the other edited the old code | Apply the content edit to the **new** shape |
| **Overlapping edits that compose** | One side added a parameter, the other changed the body | Apply both edits |
| **Competing values** | Different constants, defaults, copy or behaviour for the same thing | Decided by tests, a later commit or the ticket → take that. Otherwise **ask** (AskUserQuestion with both versions as options, the side named by branch) |
| **Formatting-only on one side** | One side reformatted, the other changed logic | Take the logic, then run the repo's formatter on the file |

Each resolution must keep the file valid on its own: imports used, no duplicate definitions or keys, braces and JSX balanced, every symbol it references still existing after the merge.

#### 3b. Edit precisely

Use exact-string edits on the marked region. For a mechanical "keep both" across a whole file, a scripted marker strip is fine, but only when **every** conflict in the file is that same pattern. Re-read the result afterwards.

#### 3c. Lockfiles and generated files

1. Resolve the **manifest** (`package.json`, `Cargo.toml`, `pyproject.toml`, `*.csproj`, …) as a normal content conflict.
2. Start the lockfile from the side whose dependency tree should be the base, normally the target or upstream branch (`git checkout --theirs` in a merge from `main`; `--ours` in a rebase onto `main`). Then regenerate it with the project's package manager in lockfile-only mode where one exists (`npm install --package-lock-only`, `pnpm install --lockfile-only`, `yarn install --mode update-lockfile`, `cargo update -w`, `uv lock`, `poetry lock`, `dotnet restore --force-evaluate`).
3. Generated files: rerun the generator (router codegen, OpenAPI export, snapshot update, ORM snapshot) with the merged sources. Then check that the output contains both sides' additions.

#### 3d. Mark each resolved path

```bash
git -C "$R" add <path>        # resolved content
git -C "$R" rm <path>         # resolved as deleted
```

### Step 4 — Hunt for Semantic Conflicts

A clean textual merge is not necessarily a correct one. Before verifying, check:

- **Removed or renamed symbols** on one side that the other side **started using**: diff the identifiers each side removed against the identifiers the other side added (`git diff <base> <side> | grep '^-'` for the names, then `git grep` for them in the merged tree).
- **Signature changes**: one side changed a function's parameters or return type, the other added call sites with the old ones.
- **Duplicates**: both sides added the same helper, migration number, route, config key, test name or i18n key in different places.
- **Ordering and registration**: both sides appended to an ordered registry where order matters (migrations, middleware, plugin lists).
- **Docs and changelog**: both sides' entries present, and none describing behaviour the other side removed.

### Step 5 — Verify the Merged Tree

```bash
git -C "$R" diff --check                       # leftover conflict markers and whitespace errors
git -C "$R" diff --name-only --diff-filter=U   # must be empty
git -C "$R" status --short                     # only intended paths staged; untracked files untouched
```

Don't treat a plain `grep '======='` hit as a marker: Markdown setext headings and RST use it. Trust `git diff --check` for markers. Then run the repo's own gates, found in its rulebooks, `package.json` scripts, `Makefile`, project verify skills or CI config: type-check/build, unit tests, and lint if fast. Run them in full when either side touched shared code, and scoped when the conflicts were docs-only. Report any gate you skipped (e2e, integration needing services) by name. A failure the merge introduced is yours to fix before reporting. A failure that already exists on one side alone (check by running the same gate on that side) is reported, not fixed.

### Step 6 — Conclude (Only When Authorized)

Without `continue`/`commit` in the invocation or an explicit instruction: stop with everything staged and give the user the exact command that concludes the operation.

When authorized:

| Operation | Conclude with | Then |
|---|---|---|
| merge | `git -C "$R" commit --no-edit` (keep git's merge message; add the host's attribution trailer if the host requires one) | `git -C "$R" show --remerge-diff HEAD` to review the resolution as committed |
| rebase | `GIT_EDITOR=true git -C "$R" rebase --continue` | If it stops again, repeat Steps 0–5 for that commit. Run the type-check at each stop and the full gates at the end |
| cherry-pick / revert | `GIT_EDITOR=true git -C "$R" cherry-pick --continue` / `revert --continue` | Repeat per stop for a range |
| stash pop/apply | nothing to continue — the resolved changes stay in the working tree (`git restore --staged <paths>` unstages them if the user wants them unstaged) | The stash is **kept** by git after a conflicted pop. Tell the user; never `stash drop` it yourself |

Never push. If the branch was rebased, any push needs `--force-with-lease`, and that decision belongs to the user.

---

## 3. Output Format & Deliverables

Chat, concise:

1. **Operation**: what was in progress and the two sides by branch name (e.g. "merge of `main` into `feature/settings-screen`").
2. **Per file**: one line each. The path, what each side did, how it was resolved and why ("`CHANGELOG.md` — both added an Unreleased section; kept both, branch first"). Group trivially identical cases.
3. **Decisions**: any conflict resolved by the user's choice, and any assumption made.
4. **Semantic checks**: what Step 4 found, or "none found".
5. **Verification**: each gate run and its result, and each gate skipped.
6. **State and next step**: "staged, not committed — run `git commit --no-edit`", or what was concluded.

When the artifact threshold is met, `<prefix>-conflict_resolution-<suffix>.md` holds:
- `## Operation & Sides`
- `## Per-File Resolutions`: a table of path | kind | pattern | resolution | evidence (commit SHAs on each side)
- `## Decisions` (asked and answered)
- `## Semantic Checks`
- `## Verification`
- `## Next Step`

Link it per the artifacts protocol with `#L<line>` anchors.

---

## 4. Verification & Validation

- `git diff --name-only --diff-filter=U` is empty and `git diff --check` is clean.
- Every resolved hunk can be traced to content from the base, ours or theirs. Nothing new was invented.
- The repo's type-check/build and unit tests pass on the merged tree, or each failure is shown to already exist on one side.
- Only the conflicted paths, plus regenerated lockfiles or generated files, are newly staged. Untracked files are untouched.
- The operation is concluded only if authorized. Otherwise the user has the exact concluding command.
- After a commit: `git show --remerge-diff HEAD` shows exactly the resolutions reported in chat.

---

## Pitfalls

| Pitfall | Guard |
|---|---|
| Swapping ours/theirs during a rebase | Name sides by branch (Step 0 table) and read `REBASE_HEAD` for your own commit |
| `checkout --conflict=zdiff3` after editing | It discards your edits to the file. Re-render only before touching it |
| Hand-merging a lockfile | Regenerate from the resolved manifest (Step 3c) |
| `git add -A` sweeping untracked artifacts into the merge commit | Stage per path (Golden Invariant 4) |
| Clean textual merge that no longer compiles | Step 4 + Step 5 gates on every run, not only when conflicts touched code |
| `=======` mistaken for a marker in Markdown | Use `git diff --check` |
| zsh treating a bare `=======` word as `=cmd` expansion (`echo =======` fails with "not found") | Quote it: `'======='` |
| `stash drop` after a conflicted pop | Leave the stash. The user drops it once satisfied |
| Same conflicts on every stop of a long rebase | Suggest `git config rerere.enabled true`, but verify replayed resolutions (Step 0) |
| `.git` treated as a directory inside a linked worktree | Always use `git rev-parse --git-path <name>` |

## Worked Example

`main` was merged into `feature/settings-screen`. Only `CHANGELOG.md` conflicted (`UU`). The branch had added an `## Unreleased — settings` section and `main` had added `## Unreleased — assistant token use` at the same spot under the title. Pattern: independent additions. Resolution: kept both, branch section first, and stripped the three markers with a scripted edit, which was safe because it was the file's only conflict. Twenty files had merged cleanly, but both sides had touched the assistant code (`src/assistant/*`, `server/system-prompt.ts`), so Step 5 ran `npm run typecheck` (clean) and `vitest run` (241/241 passing). e2e was reported as not run. `CHANGELOG.md` was staged alone (the untracked `claude-*.md` artifacts in the root stayed untracked), and the merge was left uncommitted with `git commit --no-edit` as the next step.
