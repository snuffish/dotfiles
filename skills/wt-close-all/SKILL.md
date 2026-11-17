---
name: wt-close-all
description: "Commits and pushes the work in every linked worktree of the current repo through /commit, after one confirmation of what each tree holds, then removes each worktree that is now clean and pushed. Skips worktrees a running Claude session is using, branches with commits by someone else, detached trees with changes, and trees whose .worktreeinclude copies differ, and reports them. Branches are kept. Use for /wt-close-all, \"commit and delete all worktrees\", \"close all worktrees\"."
argument-hint: "[<repo path>]"
disable-model-invocation: true
---

# Skill: `/wt-close-all` — Commit, Push and Remove Every Worktree

Lands the work in each linked worktree with `/commit`, then removes the trees that are safe. Removal goes through `wt-rm` in `~/.terminal/wt.bash`, which removes a tree only when `wt-status` classes it `safe`: clean, nothing unpushed, no live session, `.worktreeinclude` copies equal to the main checkout's. This skill never forces a removal.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/outward-writes.md`

- The Step 2 confirmation satisfies `outward-writes` › *Explicit request & draft mode* for the commits, pushes and removals it lists; nothing outside that list.
- `<script>` is `scripts/wt-close-all.sh` in this skill's real folder. `<self>` is this session's id: `${CLAUDE_SESSION_ID}`.
- **Never** `git worktree remove --force`, `wt-rm --discard`, `ExitWorktree` with `remove`, or `git branch -D`. A tree that is not safe stays.
- **Never** commit or push onto a branch that holds someone else's commits (an open PR branch checked out for a review): keep it.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Remove only the trees that are already safe, no commits | `wt-sweep --apply <repo>` (`~/.terminal/wt.bash`) |
| Throw away a tree's uncommitted work | `wt-rm --discard <dir>`, run by the user |
| One worktree, not all | [`/wt`](../wt/SKILL.md) › *Remove* |

---

## 2. Workflow

### Step 1: List and sort the worktrees

Repo = the argument, else the current directory's main checkout. Run `<script> status <repo> <self>`. No linked trees → report that and stop. Sort each row:

| `class` | Action |
|---|---|
| `safe` | Remove in Step 4 |
| `keep:dirty` or `keep:unpushed` on a branch | Commit in Step 3, unless foreign (below) |
| `keep:dirty` or `keep:unpushed`, branch `(detached)` | Keep: `/commit` refuses detached HEAD |
| `keep:live` | Keep: another running session uses it |
| `keep:unknown` | Keep: the session registry could not be read |
| `keep:include` | Keep: a local config copy differs from the main checkout's; name the files and let the user decide |

**Foreign branch:** for each tree marked for commit, run `git -C <dir> log --format=%ae origin/HEAD..HEAD` and compare with `git -C <repo> config user.email`. Any other author → keep, reason `foreign: <author>`.

### Step 2: Confirm once

For each tree marked for commit, run `git -C <dir> status --short` and `git -C <dir> log --oneline @{u}..HEAD` (no upstream: `origin/HEAD..HEAD`). Print one table: dir, branch, what will be committed and pushed, what will be removed, what is kept and why. Ask once with `AskUserQuestion`: *go*, *go but keep <tree>* (the user names trees in *Other*), *stop*. Only the trees the answer approves go on.

### Step 3: Commit and push each approved tree, one at a time

1. `EnterWorktree` with `path: <dir>`.
2. `Skill("commit")`. It stages, gates, commits and pushes from the worktree.
3. `ExitWorktree` with `action: "keep"`, whatever step 2 did.

When `/commit` stops (protected branch, secret hit, failing gate, rebase conflict), record its reason, keep that tree and go on to the next. Never fix and retry inside this skill.

### Step 4: Remove the safe trees

Run `<script> status <repo> <self>` again. For each `safe` row run `<script> rm <self> <dir>`; a `kept` line from `wt-rm` means the tree changed since the listing, so record it as kept. `wt-rm` keeps the branch unless `wt-new` made it and it has no commits.

---

## 3. Output Format

```markdown
🧹 Worktrees of <repo-dirname>
| Worktree | Branch | Result |
|---|---|---|
| <dir name> | `<branch>` | ✅ committed `<short-sha>` + removed / ✅ removed / ⏸ kept: <reason> |

Branches kept on origin: `<branch>`, …
Next: <one action, e.g. how to resolve a kept tree>.
```

---

## 4. Verification

- A final `<script> status <repo> <self>` lists only the trees reported as kept.
- `git -C <repo> branch --list <branch>` still shows every committed branch, and `git -C <repo> rev-list --count origin/<branch>..<branch>` is `0` for each one.
