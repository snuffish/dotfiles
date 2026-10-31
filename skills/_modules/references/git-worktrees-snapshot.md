# Snapshot Lifecycle (read-only)

On-demand reference for [git-worktrees.md](../git-worktrees.md). Read before running **snapshot** mode. `<skill>` is the calling skill's name.

---

## Resolve the head and record its source ref — per repo

| Scope | Head to snapshot | Source ref to record |
|---|---|---|
| branch head (default) | `git -C <repo> rev-parse HEAD` | `<local-branch>` |
| PR whose branch is not checked out | `git -C <repo> fetch origin <source-branch>`, then `git -C <repo> rev-parse origin/<source-branch>` | `origin/<source-branch>` |
| working tree | `SNAP=$(git -C <repo> stash create)` → head is `$SNAP` | `<local-branch> + working tree` |
| index | `SNAP=$(git -C <repo> stash create)` → head is `$SNAP^2` | `<local-branch> + index` |

`<source-branch>` and `<target-branch>` are the PR's branch names **without** the `refs/heads/` prefix that Azure DevOps returns ([pr-host.md](../pr-host.md) › *Branch names*).

`<local-branch>` is `git -C <repo> rev-parse --abbrev-ref HEAD` (`detached` when it prints `HEAD`). The snapshot is detached, so its own `HEAD` carries no branch name: capture the source ref **now** and carry it next to the SHA everywhere the head is mentioned. A bare SHA in an artifact is a defect.

Also record how the main checkout relates to the head:

```bash
git -C <repo> rev-parse --abbrev-ref HEAD                   # main checkout's branch
git -C <repo> rev-list --left-right --count <head>...HEAD   # "<behind> <ahead>"
```

`git stash create` writes one unreferenced commit object and changes nothing else. An empty result means the tree is clean: the working-tree scope is empty, stop. It does **not** capture untracked files — list them with `git -C <repo> ls-files --others --exclude-standard`, read them from the main checkout, and mark citations into them `(live, untracked)`.

When the caller handed in a **workspace** `[worktree-context]`, `<repo>` above is its `repo-root` (the worktree), and the main checkout is reported separately as "user's checkout on `<branch>`, not reviewed".

## Create

```bash
SNAP_DIR=<scratchpad>/<skill>/<repo-dirname>/<ref-slug>@<short-sha>   # ref-slug: '/' → '-'
git -C <repo> worktree prune
git -C <repo> worktree add --detach "$SNAP_DIR" <head>
```

Reuse `$SNAP_DIR` when it exists and `git -C "$SNAP_DIR" rev-parse HEAD` equals `<head>`; otherwise remove it first. Emit a `[worktree-context]` with `mode=snapshot`, `branch=detached`, `source-ref` filled.

## Read

Every diff, log, grep and file read runs with `-C "$SNAP_DIR"` or on paths under it. Inside the snapshot `HEAD` **is** the pinned head and remote refs are shared, so `git diff <base>...HEAD` works unchanged. A code-intelligence index (e.g. CodeGraph) covers the main checkout only: use it for navigation, open the same file in the snapshot for the citation. When the main checkout's `HEAD` equals the head and its `git status` is clean, index lines are exact and may be cited directly; say which case applied.

## Map paths back (mandatory)

Before any `path:line` reaches an artifact or the chat, replace the `$SNAP_DIR` prefix with `workspace-path`. A link into the scratchpad is a defect.

## Remove

After the artifact is written and its links are emitted — in a fan-out, after every sub-agent has returned:

```bash
git -C <repo> worktree remove --force "$SNAP_DIR"   # disposable: nothing of the user's lives there
git -C <repo> worktree prune
```

Say in chat that the snapshot of `<source-ref> @ <short-sha>` was removed, or why it was kept (the user asked to keep it).

## When no snapshot is possible

Files never committed, a directory that is not a repository, or a failing `worktree add` → read the main checkout live, record `live checkout` in the artifact, and warn that edits during the run invalidate line numbers.
