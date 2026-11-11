---
name: push
description: "Fast commit and push: stages all changes, splits them into logical commits, and pushes to upstream, skipping /commit's drift gate, pre-commit gates and PR-description step while keeping its stops, file exclusions and secret scan. Use for /push when the repo is public or personal and speed matters more than gates."
argument-hint: "[message]"
disable-model-invocation: true
model: sonnet
---

# Skill: `/push` — Commit Everything and Push, Fast

The fast path of [`/commit`](../commit/SKILL.md): same safety checks, none of the slow gates. The safety rules live once, in `/commit`; this skill points at them and never copies them.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/outward-writes.md`

- Invoking `/push` satisfies `outward-writes` › *Explicit request & draft mode* for this commit and push.
- **Never** `git add -A` / `git add .`, `--amend`, `--no-verify`, `--force` / `--force-with-lease`, `reset` or `stash`. The one `rebase` is Step 4 › *Behind upstream*.
- Every command uses `git -C <repo-root> …`.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Drift check, pre-commit gates or a PR-description update wanted | [`/commit`](../commit/SKILL.md) |
| A merge, rebase or cherry-pick is in progress | [`/resolve-conflicts`](../resolve-conflicts/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the repo and check it can take a commit

Apply `commit` › *Step 1* in full: repo root, then stop on detached HEAD, an operation in progress, a protected branch (allowed only in a trunk-only personal repo) or nothing to commit and nothing to push.

### Step 2: Choose and split the changes

Apply `commit` › *Step 3*: stage all changes including untracked files, minus the always-exclude list (named in chat). Unrelated concerns become separate commits, split without asking. Run the secret check on each staged set; a hit stops the push (mask the value and ask).

**Skipped on purpose:** `commit` › *Step 2* (drift gate) and *Step 4* (pre-commit gates).

### Step 3: Message and commit

Apply `commit` › *Step 5*, with the argument as the message: one commit uses it as the subject; when the changes split, it is the first group's subject and the rest are generated in the repo's convention. Commit each group from a scratchpad file.

### Step 4: Push

Apply `commit` › *Step 6*, including *Behind upstream*, with one change: on a rebase conflict, run `git -C <repo-root> rebase --abort`, confirm `HEAD` is back on the local commits, and stop with the conflicting files and the incoming commits. Do not resolve.

### Step 5: Report drift, read-only

Skipped: `commit` › *Step 7* (PR). In a repo with the registry checker (`commit` › *Step 2* table), run `python3 -I <repo-root>/<checker>` once after the push and print its STALE and FAIL counts. Fix nothing.

---

## 3. Output Format & Deliverables

```markdown
✅ Pushed <repo-dirname> `<branch>` → `origin/<branch>`
- `<short-sha>` <subject> (one line per commit)
- Rebased onto <n> incoming commits (only when Step 4 integrated)
- Left out: <path> (<reason>)
- Skipped: drift, gates, PR
- Drift: <n> stale, <n> fail (run /commit or /skill-drift) (or: no skill-drift check)

Next: <one action>.
```

---

## 4. Verification & Validation

- After pushing, `git -C <repo-root> rev-list --count @{u}..HEAD` is `0` and `@{u}` is `origin/<branch>`.
- `git -C <repo-root> status --short` holds only the excluded files named in chat; no amend, force-push, `--no-verify`, reset or stash ran.
