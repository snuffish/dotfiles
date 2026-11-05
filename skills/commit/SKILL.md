---
name: commit
description: "Runs the skill-drift check first and fixes STALE claims surgically, then stages changed files, runs documented pre-commit gates (formatters, linters, tests), formats commit messages matching repo conventions (Conventional Commits or branch work-item prefix), and pushes to upstream. Refuses commits on default branches or detached HEAD."
argument-hint: "[no-push] [message or intent] [paths…]"
---

# Skill: `/commit` — Commit and Push the Current Change

Turns the work in the working tree into one well-formed commit on the current branch and pushes it, following the repository's conventions.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/git-worktrees.md`: only with an incoming `[worktree-context]` block, which names the `repo-root` to commit in; otherwise runs in place
- `../_modules/pr-host.md`: read-only, to name the PR the push updates
- `../_modules/outward-writes.md`

- Invoking `/commit` (or explicitly asking to commit/push in the current message) satisfies `outward-writes` › *Explicit request & draft mode* for this commit and push only.
- **Never** `git add -A` / `git add .`, `--amend`, `--no-verify`, `--force` / `--force-with-lease`, `rebase`, `reset`, or `stash` here (unless the user explicitly asks for `--force-with-lease` in the current message).
- Every command uses `git -C <repo-root> …` (`git-worktrees` › *Golden Invariants*).

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Branch from a work item, commit, push and open a PR in one go | the project's ship skill (e.g. `priis-ship`), when the workspace has one |
| Commit, push and rewrite the PR description | [`/pr-summary update`](../pr-summary/SKILL.md) |
| A merge, rebase or cherry-pick is in progress, or the push was rejected and needs a merge | [`/resolve-conflicts`](../resolve-conflicts/SKILL.md) |
| Work that should go on its own branch in a separate checkout | [`/worktrees`](../worktrees/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the repo and check it can take a commit

1. **Repo root:** use `repo-root` from an incoming `[worktree-context]` block, else `git rev-parse --show-toplevel` (in a multi-repo workspace, handle each changed repo separately; check for locked `claude-skill:` worktrees per `git-worktrees` › *Using this Module from a Command*).
2. **Stop and say why** when:
   - **Detached HEAD:** `git -C <repo-root> symbolic-ref -q HEAD` fails.
   - **An operation is in progress:** `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, or a `rebase-merge/` / `rebase-apply/` directory exists (`resolve-conflicts` › *Step 0 — Detect the Operation, the Sides and the Repo*). Route to [`/resolve-conflicts`](../resolve-conflicts/SKILL.md), except a **resolved merge**: `MERGE_HEAD` exists and `git diff --name-only --diff-filter=U` is empty. Conclude that one yourself with `resolve-conflicts` › *Step 6 — Conclude* (the user's `/commit` is the request to commit), then go to Step 6.
   - **Protected/default branch:** `main`, `master`, `develop`, `release/*`, or `origin/HEAD` — unless the repo is a trunk-only personal repo (e.g. `~/.terminal` or `~/.terminal/memory`). Otherwise propose a branch name in the repo's convention and create it only on approval.
   - **Nothing to commit and nothing to push:** say so in one line and stop.

### Step 2: Skill-drift gate (before grouping)

Runs before anything is staged, so claim fixes are grouped with the change that caused them. The checker is the first that exists in `<repo-root>`:

| Checker | Claims file | Triage per |
|---|---|---|
| `skills/skill-drift/scripts/check_skill_drift.py` (the `~/.terminal` registry) | `skills/skills-claims.json` | [`/skill-drift`](../skill-drift/SKILL.md) |
| `.claude/scripts/check_skill_drift.py` (a project repo) | `.claude/skills-claims.json` | that repo's drift skill |

No checker → state `"no skill-drift check"` and go to Step 3.

1. **Run** `python3 -I <repo-root>/<checker>` (full run, no `--file`).
2. **STALE rows → fix now.** Re-extract each claim per `skill-drift` › *3. Re-extract claims after editing a skill*: update only that claim's `quote` / `source.line` (or drop and re-add it) with the Edit tool.
   - **Never** rewrite the claims file wholesale: no `json.dump(s)`/`jq`/script regeneration, no `--update-stale` (it also silently rewrites `count` claims), no formatter on it.
   - Keep the file canonical (`json.dumps(data, indent=2)` form: 2-space indent, ASCII-escaped, trailing newline); the checker fails a non-canonical file.
3. **FAIL rows:** if the claim's `source.file` is in this change, triage and fix per `skill-drift` › *2. Triage a `FAIL`*. Otherwise leave it, name it in chat and in the output's `Left out` line, and continue.
4. **Diff guard:** before editing, copy the claims file to the scratchpad. After, run `git -C <repo-root> diff --numstat -- <claims file>`: expect about 2 changed lines per fixed claim (more only for added or removed claims). Far more means it was reformatted: restore the copy and redo the edits by hand.
5. **Re-run the checker:** `0 stale` and no FAIL from this change, else stop and report the rows.
6. Claim edits (and any skill text fixes) belong to the change that caused them: stage them with it in Step 3.

### Step 3: Choose what goes into the commit

```bash
git -C <repo-root> status --porcelain=v1 -uall
git -C <repo-root> diff --stat; git -C <repo-root> diff --staged --stat
git -C <repo-root> rev-list --count @{u}..HEAD 2>/dev/null     # commits already waiting to be pushed
```

- **Paths given in arguments:** stage only those (`git -C <repo-root> add -- <path> …`).
- **Already staged:** commit the staged set and name what stays unstaged.
- **Otherwise:** stage only files belonging to this change. Unrelated concerns → separate commits; ask first, except in a trunk-only personal repo (Step 1): split without asking and name the split in chat.
- **Always exclude and name in chat:** secrets/local config (`.env*`, `*.pem`, `*.key`, `appsettings.local.json`, `credentials*`), build/test output (`bin/`, `obj/`, `dist/`, `build/`, `test-results/`), ignored/generated files, editor settings, workspace-root artifacts (`<prefix>-<artifact>-<suffix>.md`), and scratch files.
- **Secret check** on staged diff before proceeding (a hit stops the commit; mask the value and ask):
  ```bash
  git -C <repo-root> diff --staged -U0 | grep -nE '(-----BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{36}|xox[baprs]-|(password|secret|api[_-]?key|token)["'\'' ]*[:=] *["'\''][^"'\'' ]{8,})'
  ```

### Step 4: Run the repo's pre-commit gates

- Run only the pre-commit gates documented in the repo's rulebook (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, workflow skill), scoped to changed files when supported (e.g. formatter, import organiser, lint).
- **Run independent gates at the same time**: when gates cover separate parts (backend and frontend, two repos), start the slowest with `run_in_background` and run the others meanwhile, keeping each part's own order (formatter before build or lint). Draft the Step 5 message while they run.
- Re-stage only files already in the commit if a formatter modifies them; report any untouched files it modified.
- **A failing gate or git hook stops the commit.** Fix mechanical formatting/lint issues inside the staged change; otherwise report the failure output and stop.
- If no pre-commit gates are documented, state `"no pre-commit gates documented"` and continue.

### Step 5: Write the message and commit

- **Convention (first match wins):** (1) user's explicit message from arguments, (2) repo rulebook / workflow skill, (3) commitlint / Conventional Commits / `.gitmessage`, (4) pattern of `git -C <repo-root> log --format=%s -20` (e.g. `#<id>: <imperative>`, `feat(scope): …`).
- **Work-item ID:** extract from the branch name (`feature/30342_slug` → `30342`) or recent branch commits; ask if required and missing.
- **Subject & body:** imperative mood, ≤72 chars including prefix, no trailing period, matching recent commit language; add a bulleted body only when the change spans multiple behaviours.
- **Trailer (canonical rule):** apply the attribution trailer rule in force — the project profile's or user's trailer policy overrides the host's default attribution instruction (if a project forbids trailers, add none).
- **Commit from a scratchpad file** so shell metacharacters (`!`, backticks) are never expanded:
  ```bash
  git -C <repo-root> commit -F <scratchpad>/commit-msg.txt
  ```

### Step 6: Push

Skip under `no-push`. Otherwise ensure upstream matches the branch itself (never push a feature branch onto `origin/main` when `@{u}` points at `origin/main`):

```bash
UP=$(git -C <repo-root> rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)
BR=$(git -C <repo-root> rev-parse --abbrev-ref HEAD)
if [ "$UP" = "origin/$BR" ]; then
  git -C <repo-root> push
else
  git -C <repo-root> push -u origin HEAD
fi
```

- **Rejected (non-fast-forward or branch policy):** stop, show `git -C <repo-root> log --oneline HEAD..@{u}` or the server message verbatim, and offer `git pull --rebase` or [`/resolve-conflicts`](../resolve-conflicts/SKILL.md). Never force-push.

---

## 3. Output Format & Deliverables

```markdown
✅ Committed and pushed <repo-dirname> `<branch>` → `origin/<branch>`
- `<short-sha>` <subject>
- Files: <n> (<list>) · gates: <what ran> ✅
- Left out: <path> (<reason>)
- PR: [<repo> !<id>](<url>) now at `<short-sha>` (or: no open PR for this branch)

Next: <one action, e.g. `/pr-summary update` or opening a PR>.
```

Resolve the open PR read-only via `pr-host` › *Resolve the PR from a branch*. Under `no-push`, state the commit is local and how many commits are unpushed.

---

## 4. Verification & Validation

- `git -C <repo-root> log -1 --format='%h %s'` and `show --stat HEAD` match the intended files and convention.
- After pushing, `git -C <repo-root> rev-list --count @{u}..HEAD` is `0` and `@{u}` is `origin/<branch>`.
- `git -C <repo-root> status --short` holds only the excluded files named in chat; no amend, force-push, `--no-verify`, rebase, reset, or stash ran.
