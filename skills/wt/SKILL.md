---
name: wt
description: "Runs commands or multi-step requests in isolated git worktrees or detached snapshots to keep the primary checkout clean. Supports mutating workflows in feature worktrees, read-only tasks in detached snapshots, and combining multiple PRs into local integration branches. Use for /wt, \"run this in a worktree\", \"do this in a worktree\", \"in an isolated worktree\"."
---

# Skill: `/wt` — Run a Request in a Worktree

Gives a plain prompt the same worktree isolation a Command gets from the `git-worktrees` Module: it picks the mode, creates (or reuses) one worktree per repo, does the work there and reports where the work is.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — a Command it routes to writes its own
- `../_modules/git-worktrees.md`: workspace for a request that changes anything, snapshot for one that only reads

On-demand references (`references/`):
- [`references/merge-prs-recipe.md`](references/merge-prs-recipe.md) — combining multiple PRs onto a local integration branch (`merge PR X & Y`)

- **One owner per worktree.** A worktree is created by the routed Command, or by this skill when it runs the request itself. Never by both.
- **This skill adds no gates and lifts none.** The request keeps the gates it would have without a worktree: a plan before a non-trivial change (`core` › *Planning mode first*), and the routed Command's own gates. Pushing, creating or completing a PR, and posting to a host happen only when the user asks for them explicitly.

---

## 1. When *not* to use

- **The prompt starts with another Command** (`/refine … /wt`): that Command handles the token under `core` › *Worktree opt-in*; this skill is not involved.
- **Stepping into a kept worktree from an earlier run**: give the user the path and `EnterWorktree path:<dir>` (`git-worktrees` › *Workspace Lifecycle* › *Hand-off*).
- **Starting a fresh single-task session**: launch `claude -w <slug>` (`--tmux` optional) instead; inside it `/wt` and `/wt` Commands reuse that tree (*Step 4*).
- **Running in the user's own checkout**: use [`/no-wt`](../no-wt/SKILL.md).
- **Remote-only operations** (completing a PR on the host, editing a PR description): nothing to isolate; say so and run only on an explicit ask.

---

## 2. Core Protocol & Workflow

### Step 1: Parse the prompt

1. Remove every `/wt` token. What remains is the **request**.
2. **No request (bare `/wt`):** list the worktrees per repo (`git-worktrees` › *Repo Resolution*, then *Workspace Lifecycle* › *Create*). Show each locked `claude-skill:` worktree with its path, branch, lock reason and `git -C <dir> status --short` count. Change nothing, then stop.

### Step 2: Route

| The request | Route |
|---|---|
| Names a registry Command or matches its trigger ("review PR 123" → `code-review`, "resolve the conflicts" → `resolve-conflicts`, "clean up X" → `clean`) | Invoke that Command with the request plus the token `/wt`. It runs `git-worktrees` itself, so this skill is done. Report only that the request was routed. |
| Matches several Commands in sequence ("review PR 123 and fix what you find") | Route to the first. Say which Command picks up the rest. |
| Matches no Command (merge PRs, try a rebase, bump a package, run a codemod) | Carry it out here, from Step 3 on. |

### Step 3: Choose the mode and the repos

- **Mode:** edits a file, commits, merges, rebases, cherry-picks, applies a patch, runs a generator/migration, or installs dependencies → **workspace** (`git-worktrees` › *Workspace Lifecycle*). Only reads, diffs, builds or tests a given head → **snapshot** (*Snapshot Lifecycle*). If unsure, use workspace.
- **Repos:** resolve per `git-worktrees` › *Repo Resolution*, narrowed to the repos the request names (or the repo of the current directory). Create or reuse one worktree per repo in scope (*Golden Invariants*).

### Step 4: Base, branch and worktree (workspace mode)

Follow `git-worktrees` › *Workspace Lifecycle* (`_modules/references/git-worktrees-workspace.md`) with `<skill>` = `wt`:
1. **Detect existing worktree first:** for a single-repo workspace, if the session is already inside a `claude --worktree` or `EnterWorktree` checkout (`git rev-parse --git-dir` ≠ `git rev-parse --git-common-dir`), **reuse it** instead of creating a nested worktree — rename any `worktree-*` branch to the convention, lock with the `claude-skill:worktrees … session:<session-id>` reason, and hydrate if needed.
2. **Otherwise create:** resolve base (`origin/<default>` unless specified) and branch (`<type>/<kebab-slug>`, never `worktree-<name>`), create and lock per *Workspace Lifecycle* › *Create* (`session:<session-id>` is mandatory for statusline detection), and hydrate when the request builds, tests, or runs the project.

In snapshot mode, follow `git-worktrees` › *Snapshot Lifecycle* (`_modules/references/git-worktrees-snapshot.md`).

### Step 5: Do the work

- Run every command with `git -C <repo-root>` or on absolute paths under `repo-root` (*Workspace Lifecycle* › *Work*).
- Hand the `[worktree-context]` block to every Command and sub-agent it calls.
- For "merge PR X & Y", read and follow [`references/merge-prs-recipe.md`](references/merge-prs-recipe.md).
- After any change, run the project's verify commands inside `repo-root` (*Verify*, `core` › *Post-edit verification*).

### Step 6: Land or keep, then hand off

- **Workspace:** *Workspace Lifecycle* › *Remove* (removed only when the branch is pushed and clean, and not the session's active `claude --worktree` cwd; otherwise kept, locked and reported).
- **Snapshot:** removed after the result is reported (*Snapshot Lifecycle* › *Remove*).
- Always end with the *Hand-off* line.

---

## 3. Output Format & Deliverables

No artifact. When routed, one line naming the Command it went to, followed by that Command's output. When run here, per repo:

```markdown
**<repo-dirname>**: <mode> worktree on `<branch | source-ref @ short-sha>`, <reading of the request when it was assumed>

- Done: <what ran: merges in order, commands, edits>
- Verify: <commands and result, or "not run: <reason>">
- Your checkout: unchanged, on `<its branch>`
- Worktree: <removed | kept at `<dir>`: <uncommitted / unpushed summary>>
- See it: `git -C <repo> checkout <branch>` (after stashing your changes), or open `<dir>` (`EnterWorktree path:<dir>`)
```

---

## 4. Verification & Validation

- The main checkout's `git -C <repo> status --porcelain` and `rev-parse HEAD` are unchanged before and after the run.
- `git -C <repo> worktree list --porcelain` shows the kept worktree with its `claude-skill:worktrees` lock reason, or no longer shows a removed one.
- Every path in chat uses `workspace-path`, never the worktree or scratchpad path (*Snapshot Lifecycle* › *Map paths back*).
- No push, PR or host write happened without an explicit ask.
