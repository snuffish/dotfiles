---
name: commit
description: "Commits the current change and pushes it, in the repo's own convention. Stages only the files that belong to the change (never `git add -A`), keeps secrets, build output and local artifacts out, runs the repo's documented pre-commit gates (formatter, import sorter, lint) on the changed files, writes the message in the repo's format (work-item prefix from the branch, Conventional Commits, or whatever `git log` shows) with the attribution trailer the project allows, then pushes, setting the upstream when there is none. Refuses the default branch, detached HEAD and an in-progress merge or rebase, and never amends, force-pushes or skips hooks. `no-push` stops after the commit. Use for /commit, \"commit this\", \"commit and push\", \"push my changes\", \"commit with message …\". Not for opening a PR or branching from a work item (the project's ship skill), rewriting the PR description (/pr-summary update), or resolving conflicts (/resolve-conflicts)."
argument-hint: "[no-push] [message or intent] [paths…]"
---

# Skill: `/commit` — Commit and Push the Current Change

Turns the work in the working tree into one well-formed commit on the current branch and pushes it, following the conventions the repository already uses. It commits what the user asked to commit and nothing else.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — the deliverable is the commit and the push
- `../_modules/git-worktrees.md`: runs in place; a handed-in `[worktree-context]` block names the repo to commit in
- `../_modules/pr-host.md`: read-only, to name the PR the push updates

- **Invoking `/commit`, or asking in the current message to commit or push, is the explicit request** that `core` › *The `/proceed` gate* requires for these outward-facing actions. Anything else is not: a plan, an artifact or your own judgement that the work is done. The request covers this one commit and push. It does not cover a PR, a description, a comment, a tracker write or a later commit.
- **Never** `git add -A` / `git add .`, `--amend`, `--no-verify`, `--force` / `--force-with-lease`, `rebase`, `reset` or `stash` here. The only exception is a force push the user asks for by name in the current message, and then only `--force-with-lease`.
- Every command is `git -C <repo-root> …`. The session's working directory never moves (`git-worktrees` › *Golden Invariants*).

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

1. **Repo root:** the `repo-root` of a handed-in `[worktree-context]` block, else `git rev-parse --show-toplevel` from the directory the change lives in. In a multi-repo workspace (`git-worktrees` › *Repo Resolution*), take every repo that holds part of the change and handle each one separately, one commit per repo. If a locked `claude-skill:` worktree exists for the current branch, follow the *Repo root* rule in `git-worktrees` and ask which tree is meant.
2. **Stop and say why** when:
   - **Detached HEAD:** `git -C <repo-root> symbolic-ref -q HEAD` fails.
   - **An operation is in progress:** `.git/MERGE_HEAD`, `REBASE_HEAD`, `CHERRY_PICK_HEAD` or a `rebase-merge/` / `rebase-apply/` directory exists under `git rev-parse --git-dir`. That is `/resolve-conflicts`.
   - **The branch is the default or a protected branch:** `main`, `master`, `develop`, `release/*`, or the remote's `origin/HEAD`. Propose a branch name in the repo's convention (from its workflow rulebook, else the shape of recent branches in `git branch -r`), and create it only when the user agrees.
   - **Nothing to commit and nothing to push:** say so in one line and stop.

### Step 2: Choose what goes into the commit

```bash
git -C <repo-root> status --porcelain=v1 -uall
git -C <repo-root> diff --stat; git -C <repo-root> diff --staged --stat
git -C <repo-root> rev-list --count @{u}..HEAD 2>/dev/null     # commits already waiting to be pushed
```

- **Paths given in the arguments:** stage exactly those.
- **Something is already staged:** commit exactly the staged set. Name what stays unstaged.
- **Otherwise:** stage the files that belong to the change. Use what this session edited and what the request describes. A file that is unrelated, or was changed by someone or something else, stays out.
- **Always kept out, and named in chat:**
  - secrets and local config: `.env*` that are not tracked, `*.pem`, `*.key`, `appsettings.local.json`, `credentials*`
  - build and test output: `bin/`, `obj/`, `dist/`, `build/`, `test-results/`
  - generated files the repo ignores or regenerates
  - editor settings
  - workspace-root artifacts (`<prefix>-<artifact>-<suffix>.md`)
  - scratch files
- **Untracked files** go in only when they clearly belong to the change, such as a new source file the change imports. An untracked file whose purpose is unclear is a question.
- **Unrelated concerns in one tree** (a fix plus an unrelated refactor): propose one commit per concern and ask. Otherwise make one commit.
- Stage by explicit path: `git -C <repo-root> add -- <path> …`.
- **Secret check** on what is staged, before anything else runs:

  ```bash
  git -C <repo-root> diff --staged -U0 | grep -nE '(-----BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{36}|xox[baprs]-|(password|secret|api[_-]?key|token)["'\'' ]*[:=] *["'\''][^"'\'' ]{8,})'
  ```

  A hit stops the commit. Show the line with the value masked and ask.

### Step 3: Run the repo's pre-commit gates

- Take the gates from the repo's rulebook (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, its workflow skill), and only the ones it says to run **before a commit**. Typical examples: a formatter on changed files, an import organiser, lint.
- Scope each gate to the changed files when the rulebook says so. Build and full test runs are the job of the project's verify skill. Run them here only when the rulebook lists them as pre-commit gates or the user asks.
- When a gate rewrites files, look at what it changed:
  - Re-stage only the files that are already in the commit.
  - A file outside the commit that the gate touched gets reported, not staged.
- **A failing gate stops the commit.** Report the output. Fix the cause only when it is inside the staged change and the fix is mechanical, such as a lint autofix or a formatting fix. Otherwise hand it back.
- Git's own hooks run as usual. A hook failure is a gate failure.
- **No documented gates:** say "no pre-commit gates documented" and continue.

### Step 4: Write the message and commit

- **Convention, first match wins:**
  1. The user's message from the arguments, used verbatim.
  2. The repo's rulebook or workflow skill.
  3. A commitlint, Conventional Commits or `.gitmessage` config.
  4. The pattern of the last 20 subjects in `git -C <repo-root> log --format=%s -20` (e.g. `#<id>: <imperative>`, `feat(scope): …`, `[ABC-123] …`).
- **Work-item id:** from the branch name (`feature/30342_slug` → `30342`), else from recent commit subjects on the branch. When the convention needs an id and none can be found, ask. Never invent one.
- **Subject:** describe the change's intent, read from the staged diff, not its mechanics. Use the imperative mood ("Add", not "Added"), at most 72 characters including the prefix, no trailing period. Write it in the language recent subjects use.
- **Body:** only when the change has more than one behaviour, with one bullet per behaviour.
- **Trailer:** apply the attribution rule in force (the host's attribution instruction, overridden by the project's or user's rule on trailers). Add nothing that rule does not ask for.
- **Commit from a file,** so backticks and `!` reach git unexpanded:

  ```bash
  git -C <repo-root> commit -F <scratchpad>/commit-msg.txt
  ```

### Step 5: Push

Skip this step under `no-push`.

```bash
git -C <repo-root> rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null \
  && git -C <repo-root> push \
  || git -C <repo-root> push -u origin HEAD
```

- **Upstream is not `origin/<same branch>`**, for example a branch created from `origin/main` that tracks it: push with `-u origin HEAD` instead, so the push never lands on the integration branch.
- **Rejected (non-fast-forward):** stop. The commit stays local. Show `git -C <repo-root> log --oneline HEAD..@{u}` (what the remote has that this branch lacks), and offer `git pull --rebase` or `/resolve-conflicts`. Never force.
- **Rejected by policy** (protected branch, required PR, hook on the server): report the remote's message verbatim.

---

## 3. Output Format & Deliverables

Chat response, short:

```markdown
✅ Committed and pushed <repo-dirname> `<branch>` → `origin/<branch>`
- `<short-sha>` <subject>
- Files: <n> (<list, or the first few + "…">) · gates: <what ran> ✅
- Left out: <path> (<reason>) · …
- PR: [<repo> !<id>](<url>) now at `<short-sha>` (or: no open PR for this branch)

Next: <one action, e.g. `/pr-summary update` when the description no longer matches, or opening a PR>.
```

- Name the PR the push updated, found read-only with `pr-host` › *Resolve the PR from a branch*.
- If a gate or the push failed, lead with that instead and show its output.
- Under `no-push`, say the commit is local and how many commits are waiting to be pushed.

---

## 4. Verification & Validation

- `git -C <repo-root> log -1 --format='%h %s'` shows the new commit, and its subject follows the resolved convention.
- `git -C <repo-root> show --stat HEAD` lists only the files chosen in Step 2.
- After a push, `git -C <repo-root> rev-list --count @{u}..HEAD` prints `0`, and `@{u}` is `origin/<branch>`.
- `git -C <repo-root> status --short` holds only what was deliberately left out, and the chat names each of those files.
- No amend, force push, `--no-verify`, rebase, reset or stash ran.
