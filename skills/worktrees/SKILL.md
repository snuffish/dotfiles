---
name: worktrees
description: Runs any request in a git worktree so the user's main checkout stays untouched. It is the launcher for the git-worktrees Module when no other Command is invoked. Strips the `/worktrees` token wherever it sits in the prompt (start or end, e.g. "Merge PR 123 & 456 /worktrees"), routes a request that matches a registry Command to that Command with the opt-in token, and otherwise carries out the request itself. It works in a workspace worktree when the request changes anything (merge, rebase, fix, refactor, generate) and in a detached snapshot when the request only reads. It ships a recipe for combining several PRs on a local integration branch. Bare `/worktrees` lists the active skill worktrees per repo. Trigger whenever a prompt contains `/worktrees` anywhere and invokes no other Command, or asks to do something "in a worktree", "in a separate worktree" or "without touching my checkout".
---

# Skill: `/worktrees` — Run a Request in a Worktree

Gives a plain prompt the same worktree isolation a Command gets from the `git-worktrees` Module: it picks the mode, creates one worktree per repo, does the work there and reports where the work is.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — a Command it routes to writes its own
- `../_modules/git-worktrees.md`: workspace for a request that changes anything, snapshot for one that only reads

- **The token belongs to whoever was invoked.** When the prompt starts with another Command (`/refine … /worktrees`), that Command handles the token under `core` › *Worktree opt-in*. This skill is not involved.
- **One owner per worktree.** A worktree is created by the routed Command, or by this skill when it runs the request itself. Never by both.
- **This skill adds no gates and lifts none.** The request keeps the gates it would have without a worktree: a plan before a non-trivial change (`core` › *Planning mode first*), and the routed Command's own gates. Pushing, creating or completing a PR, and posting to a host happen only when the user asks for them explicitly.

---

## 1. When to Use

### When *not* to use

- The prompt starts with another Command. That Command handles the token.
- The user wants to step into a worktree that was kept from an earlier run. Give them the path and `EnterWorktree path:<dir>` (`git-worktrees` › *Workspace Lifecycle* › *Hand-off line*).
- The user wants the request done in their own checkout. That is [`/no-worktrees`](../no-worktrees/SKILL.md).
- The request only changes a remote, such as completing a PR on the host or editing a PR description. There is nothing to isolate. Say so, and run it only on an explicit ask.

---

## 2. Core Protocol & Workflow

### Step 1: Parse the prompt

1. Remove every `/worktrees` token. What remains is the **request**.
2. **No request (bare `/worktrees`):** list the worktrees per repo (`git-worktrees` › *Repo Resolution*, then *Workspace Lifecycle* › *Crash recovery*). Show each locked `claude-skill:` worktree with its path, branch, lock reason and `git -C <dir> status --short` count. Change nothing, then stop.

### Step 2: Route

| The request | Route |
|---|---|
| Names a registry Command or matches its trigger ("review PR 123" → `code-review`, "resolve the conflicts" → `resolve-conflicts`, "clean up X" → `clean`) | Invoke that Command with the request plus the token `/worktrees`. It runs `git-worktrees` itself, so this skill is done. Report only that the request was routed. |
| Matches several Commands in sequence ("review PR 123 and fix what you find") | Route to the first. Say which Command picks up the rest. |
| Matches no Command (merge PRs, try a rebase, bump a package, run a codemod) | Carry it out here, from Step 3 on. |

### Step 3: Choose the mode and the repos

- **Mode.** The request edits a file, commits, merges, rebases, cherry-picks, applies a patch, runs a code generator or migration, or installs dependencies → **workspace** (`git-worktrees` › *Workspace Lifecycle*). It only reads, diffs, builds or tests a given head → **snapshot** (*Snapshot Lifecycle*). If unsure, use workspace: it never writes the main checkout either.
- **Repos.** Find them per `git-worktrees` › *Repo Resolution*. Narrow to the repos the request names. A PR id or URL resolves to its repo. A path resolves to the repo that contains it. When nothing names a repo, use the repo of the current directory. Create one worktree per repo in scope (*Golden Invariants*).

### Step 4: Base, branch and worktree (workspace mode)

1. **Base:** `origin/<default>` as fetched, unless the request names another base (a release branch, a PR's target).
2. **Branch:** the project's branch convention from its workflow skill or profile (`git-worktrees` › *Workspace Lifecycle* › *Base and branch*). Without a convention, propose `<type>/<kebab-slug>` from the request (`chore/`, `fix/`, `integrate/`) and confirm it in the first chat line. Never use `worktree-<name>`.
3. **Create** per *Workspace Lifecycle* › *Create*, with `<skill>` = `worktrees` in the lock reason.
4. **Hydrate** (*Hydrate*) only when the request builds, tests or runs the project.

In snapshot mode, *Snapshot Lifecycle* › *Resolve the head* and *Create* apply instead.

### Step 5: Do the work

- Run every command with `git -C <repo-root>` or on absolute paths under `repo-root` (*Workspace Lifecycle* › *Work*).
- Hand the `[worktree-context]` block to every Command and sub-agent it calls, for example `resolve-conflicts` on a conflicted merge.
- After any change, run the project's verify commands inside `repo-root` (*Verify*, `core` › *Post-edit verification*).

#### Recipe: merge PR X & Y

"Merge PR X & Y" defaults to **combining the PR heads on a local integration branch**, so they can be built and tested together. State this reading in the first chat line. Ask instead when the prompt points to one of the other readings below.

1. **Resolve each PR** through the host's CLI or MCP (`gh pr view <n> --json headRefName,baseRefName,headRepository`, `az repos pr show --id <n>`). Record the repo, source branch and target branch of each.
2. **Group by repo.**
   - PRs in different repos cannot be merged together. Give each repo its own worktree with its PRs, and say that nothing crosses the repo boundary.
   - PRs in one repo with different targets: ask which target is the base.
3. **Create the worktree** on `integrate/<x>-<y>` (or the convention's equivalent) from `origin/<target>`. Fetch every source branch first.
4. **Merge in the order given**, one at a time: `git -C <repo-root> merge --no-ff --no-edit origin/<source>`. A conflict goes to `resolve-conflicts` with the `[worktree-context]` block, and that skill concludes the merge.
5. **Verify** the combined result (*Verify*). Report what passes, and which PR each failure came from where `git log` shows it.
6. **Stop.** The integration branch stays local. Never push it, open a PR for it or complete either PR on the host unless the user asks.

The other readings:
- **Merge PR Y's branch into PR X's:** workspace on X's existing source branch (*Base and branch* › *If the branch already exists*), then merge `origin/<Y source>`. Pushing it changes X's PR, so push only on an explicit ask.
- **Complete both PRs on the host:** no worktree. See *When not to use*.

### Step 6: Land or keep, then hand off

- **Workspace:** *Workspace Lifecycle* › *Remove*. The worktree is removed only when the branch is pushed and clean. Otherwise it is kept, locked and reported.
- **Snapshot:** removed after the result is reported (*Snapshot Lifecycle* › *Remove*).
- Always end with the *Hand-off line*.

---

## 3. Output Format & Deliverables

No artifact. The chat response, per repo:

```markdown
**<repo-dirname>**: <mode> worktree on `<branch | source-ref @ short-sha>`, <reading of the request when it was assumed>

- Done: <what ran: merges in order, commands, edits>
- Verify: <commands and result, or "not run: <reason>">
- Your checkout: unchanged, on `<its branch>`
- Worktree: <removed | kept at `<dir>`: <uncommitted / unpushed summary>>
- See it: `git -C <repo> checkout <branch>` (after stashing your changes), or open `<dir>` (`EnterWorktree path:<dir>`)
```

When the request was routed, the response is one line naming the Command it went to. That Command's own output follows.

---

## 4. Verification & Validation

- The main checkout's `git -C <repo> status --porcelain` and `rev-parse HEAD` are the same before and after the run.
- `git -C <repo> worktree list --porcelain` shows the kept worktree with its `claude-skill:worktrees` lock reason, or no longer shows a removed one.
- Every path in chat uses `workspace-path`, never the worktree or scratchpad path (*Snapshot Lifecycle* › *Map paths back*).
- No push, PR or host write happened without an explicit ask.
