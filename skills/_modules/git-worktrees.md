# git-worktrees

One protocol for reading or changing a repository without touching the user's main checkout. Commands either isolate by default or opt in via the `/wt` token (*Modes*).

---

## Modules

Read these before using this one:
- [core.md](core.md) (same folder as this file)

Artifacts live in `<artifact-dir>` (`artifact-protocol` › *Artifact directory*), outside every checkout, and are linked by absolute path. This Module writes none; its deliverables are the worktree, the `[worktree-context]` block handed to called Commands/sub-agents, and the hand-off line in chat.

---

## Using this Module from a Command

A Command that lists this Module in `## Modules` gets both rules below without restating them. Its `git-worktrees` line names only its default mode (`snapshot by default`, `workspace by default`, or nothing for "in place unless opted in").

- **Isolation.** When the invocation contains `/wt` (*Modes* › *Opt-in token*), a `[worktree-context]` block was handed in, or the Command runs under `/implement-feature` (or a base profile with `Implementation mode: workspace`), a mutating Command runs in a **workspace** worktree (*Workspace Lifecycle*) and a read-only Command reads from a **snapshot** (*Snapshot Lifecycle*). `/no-wt` (*Modes* › *Opt-out token*) overrides the default and runs in place.
- **Repo root.** Use `repo-root` from an incoming `[worktree-context]` block, or an active linked worktree when the session started inside one (`claude --worktree` / `EnterWorktree`); otherwise discover the repo per *Repo Resolution*. Every `git` command and file path resolves under `repo-root`. If no block was handed in but `git -C <repo> worktree list --porcelain` shows a **locked** `claude-skill:` worktree for the same ticket or branch, stop and ask which tree is meant.

---

## Golden Invariants

1. **The main checkout is read-only while a worktree is active for its repo.** No `status`-driven decisions, `stash create`, `checkout`, `switch`, `add`, `commit`, `push`, `reset`, or file edits there. The only writes outside the worktree are artifacts in `<artifact-dir>` and `.git/info/exclude` (*Workspace Lifecycle* › *Create*).
2. **Never move the session working directory.** Use `git -C <path>` and absolute file paths.
3. **Hybrid host worktree support.** If the session was launched in a linked worktree (`claude --worktree` / `-w` or `EnterWorktree`, detected by `git rev-parse --git-dir` ≠ `--git-common-dir`), reuse that linked worktree as `repo-root` instead of creating a nested one (*Workspace Lifecycle* › *Reuse an active linked worktree*). Never use sub-agent `isolation: "worktree"` — sub-agents always work inside the parent's `repo-root`.
4. **One worktree per repo in scope.** A two-repo change has two worktrees, two context blocks, and two removals.
5. **Sub-agents never create, remove, lock, or unlock worktrees.** The orchestrating skill manages the lifecycle before spawning and after the last sub-agent returns.
6. **Never delete a branch.** Removing a worktree keeps its branch; delete branches only on explicit user instruction. Exception: `wt-rm` (`~/.terminal/wt.bash`) deletes a branch that `wt-new` made (`made:1` in the lock reason) when it has no commit past its base.
7. **`--force` removal only in snapshot mode.** Workspace worktrees are removed without `--force` only when landed, or on the user's explicit `"discard"`.

---

## Modes

| Mode | Purpose | Location | Branch | Removed when |
|---|---|---|---|---|
| **snapshot** | Read a pinned head (branch, PR, working tree, or index) while the user edits | `<scratchpad>/<skill>/<repo-dirname>/<ref-slug>@<short-sha>` (else `${TMPDIR:-/tmp}`) | detached | Always, after the calling skill's artifact/output is emitted |
| **workspace** | Implement on a branch without touching the main checkout | `<repo>/.claude/worktrees/<slug>` (or active `claude --worktree` tree) | project branch convention | After the branch is pushed and clean; otherwise kept locked and reported |

- **Default users**: `/code-review`, `/pr-feedback-review`, `/squash-code-review` → **snapshot**; `/implement-feature` → **workspace**; `/proceed` on a plan implementation → **workspace** (`proceed` › *Step 2*). `clean`, `expressive`, `organize`, `refine`, `problem`, `pr-fix-pipeline`, `squash-ef-core-migrations`, `resolve-conflicts`, `proceed` on other items → **workspace** when opted in, under `/implement-feature`, or when the base profile sets `Implementation mode: workspace`; otherwise in place. Other read-only Commands use **snapshot** when opted in.
- **Opt-in token (`/wt`)**: only the exact token `/wt` opts a Command in; bare words `worktree` / `worktrees` are ordinary text (unless the user asks to "run this in a worktree", which triggers the [`wt`](../wt/SKILL.md) Command).
- **Opt-out token (`/no-wt`)**: forces in-place execution even when the Command or profile defaults to snapshot/workspace. Never moves work that already lives in a kept worktree. If both `/wt` and `/no-wt` appear, ask.

---

## Repo Resolution

```bash
find <workspace-root> -maxdepth 2 -name .git            # every repo under the workspace root
git -C <candidate> rev-parse --show-toplevel            # confirm each one
```

- When the current directory is inside a linked worktree (`git rev-parse --git-dir` ≠ `--git-common-dir`), `main-checkout` is `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")`.
- A workspace root that is itself a repo **but ignores its child repos** (e.g. a parent folder that git-ignores `api/` and `web/`) is a shell: skip it and work per child repo.
- `<repo-dirname>` is the directory name under the workspace root (e.g. `api`); for a single-repo workspace it is the repo's own directory name and `workspace-path` is empty.

---

## The `[worktree-context]` Block — Active Repo Root Contract

Paste this block **verbatim** into every delegated Command invocation and sub-agent brief, one block per repo:

```text
[worktree-context]
repo=<repo-dirname>
mode=workspace|snapshot
repo-root=<absolute worktree path>        # run every git, file, build and test command here
workspace-path=<repo-dirname>/            # prefix for every path in artifacts and chat ('' for a single-repo workspace)
main-checkout=<absolute path>             # read-only; never status/stash/checkout/add/commit/push here
branch=<branch> | detached
base=<ref>@<short-sha>
source-ref=<ref the head came from>       # snapshot mode: the branch or origin/<ref> the SHA was taken from
```

The lock reason (`references/git-worktrees-workspace.md` › *Create*) carries `session:<session-id>` so `claude/statusline.sh` and crash recovery can identify the owning session without leaving marker files in the tree.

---

## Snapshot Lifecycle (read-only)

Read [references/git-worktrees-snapshot.md](references/git-worktrees-snapshot.md) before running **snapshot** mode (head resolution, detached creation in `<scratchpad>`, path mapping back to `workspace-path`, and `--force` cleanup).

---

## Workspace Lifecycle (implementation)

Read [references/git-worktrees-workspace.md](references/git-worktrees-workspace.md) before running **workspace** mode (reusing an active `claude --worktree` linked worktree and renaming `worktree-*` branches, base/branch resolution, locked creation with `.git/info/exclude`, hydrating `Worktree include list` and dependencies, verification, landing, safe removal, hand-off line, and crash recovery).
