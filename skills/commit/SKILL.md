---
name: commit
description: "Commits the current change and pushes it, with the repo's drift check, pre-commit gates and commit-message convention, then updates the branch's open PR description from the commits. Refuses default branches and detached HEAD. Use for /commit, \"commit\", \"commit push\", \"commit and push\". Fast commit with no gates: /push."
argument-hint: "[no-push] [message or intent] [paths…]"
model: sonnet
---

# Skill: `/commit` — Commit and Push the Current Change

Turns the work in the working tree into one well-formed commit on the current branch and pushes it, following the repository's conventions.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`

Read these only when their step runs:
- `../_modules/git-worktrees.md`: only with an incoming `[worktree-context]` block, which names the `repo-root` to commit in; otherwise runs in place
- `../_modules/pr-host.md`: for the Step 7 PR lookup
- `../_modules/outward-writes.md`: before Step 7 writes a PR description

A Module or `references/` file already in this session's context is not read again.

- Invoking `/commit` (or explicitly asking to commit/push in the current message) satisfies `outward-writes` › *Explicit request & draft mode* for this commit and push, and for the Step 7 description update of the branch's own open PR only (never its title, labels, draft state or any other PR).
- **Never** `git add -A` / `git add .`, `--amend`, `--no-verify`, `--force` / `--force-with-lease`, `rebase`, `reset`, or `stash` here (unless the user explicitly asks for `--force-with-lease` in the current message). The one exception is Step 6 › *Behind upstream*: `git pull --rebase --autostash` of this branch's own unpushed commits onto `@{u}`.
- A denied push or PR write is final: stop, and never retry it through another tool or flag.
- Every command uses `git -C <repo-root> …` (`git-worktrees` › *Golden Invariants*), one simple command per call.

### Delegation (Skill-tool runs on a larger model)

Applies whenever this skill was invoked through the Skill tool. That call only relabels the run: the system then names this skill's `model:` while the session's own model keeps serving every message, so never judge by the model named after the call. A typed `/commit` really switches to Sonnet (`gcai` types it into a Sonnet session), so it does not delegate. Run no step, lookup or Module read yourself. Each of your messages re-reads the whole session, so your run is three: the spawn, the status check, the report.

1. Spawn one `general-purpose` sub-agent with `model: "sonnet"`, told to read this SKILL.md and run it. The brief carries this skill's base directory as printed when the skill loaded (the sub-agent runs the `realpath` step in *Modules* itself), the arguments (including `no-push`), `repo-root`, any `[worktree-context]` block, the session's working model for the trailer (the model named before the Skill call), the intent of the change, and this consent: "the user asked to commit and push; the Step 7 description update is allowed". It ends with: "Do not delegate again. Never ask: stop and report instead."
2. After any report or failure, run `git -C <repo-root> status -sb`.
3. Re-spawn once, only when a push was asked for and the branch is still ahead of its upstream. Under `no-push` the run is done when the report names the commit. When the report stopped on a question (a missing work-item ID, a mixed change), ask the user, then re-spawn with the answer.
4. When another skill called `/commit` (for example `wt-close-all`), hand the report back to that skill instead: it decides what happens next, and this section neither asks nor re-spawns.

A sub-agent that is itself running as the delegate skips this section.

### Message plan

Each message re-reads the whole session, so a run is a few full messages, never one lookup per message. Send every call of a row together, also when one call needs the one before it: the secret `grep` reads the file `diff --output` wrote, the read-backs follow `commit`, the `status` follows `push`. This host runs the calls of one message one at a time, in the order sent, so a row is one message; a row split in two is the cost this plan removes.

| Message | Calls |
|---|---|
| 1 | `realpath`, the Step 1 lookups |
| 2 | the Step 2 checker, the Step 3 `add` and secret check |
| 3 | the Step 4 gates (only when the repo documents any) |
| 4 | the Step 5 message file, `commit`, read-back |
| 5 | the Step 6 `push` and read-back, the Step 7 PR lookup |
| 6 | the report |

A drift fix (Step 2) re-runs the Step 3 secret check on the final staged diff before Step 5. A Module not yet in context is read in a message of its own after message 1, from the folder `realpath` printed (`pr-host`: with message 4). A stop, the `state-checks.md` commands on localised output, a fix from a `references/` file, a PR description update and a worktree removal add messages; nothing else does.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Branch from a work item, commit, push and open a PR in one go | the project's ship skill (e.g. `priis-ship`), when the workspace has one |
| Commit and push everything fast, with no drift check, gates or PR update | [`/push`](../push/SKILL.md) |
| Rewrite the PR title or labels, or describe the full diff rather than the commits | [`/pr-desc`](../pr-desc/SKILL.md) |
| A merge, rebase or cherry-pick is in progress before `/commit` starts | [`/resolve-conflicts`](../resolve-conflicts/SKILL.md) |
| Work that should go on its own branch in a separate checkout | [`/wt`](../wt/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the repo and check it can take a commit

1. **Repo root:** use `repo-root` from an incoming `[worktree-context]` block, else the repo of the session's working directory (in a multi-repo workspace, handle each changed repo separately; check for locked `claude-skill:` worktrees per `git-worktrees` › *Using this Module from a Command*).
2. **Lookups** (read-only; they answer Steps 1, 2, 3, 5, 6 and 8). Item 3 and Step 6 match English `git status` phrases. English output has `On branch`, `HEAD detached`, `rebase in progress` or `Not currently on any branch` in its first line. A first line with none of them is localised output: read [references/state-checks.md](references/state-checks.md) and decide those checks from its commands, never from your translation of `status`.
   ```bash
   git -C <repo-root> rev-parse --show-toplevel --absolute-git-dir --path-format=absolute --git-common-dir
   git -C <repo-root> status -uall
   git -C <repo-root> diff --stat HEAD
   git -C <repo-root> log --format=%s -20
   git -C <repo-root> ls-files -- skills/skill-drift/scripts/check_skill_drift.py .claude/scripts/check_skill_drift.py
   ```
3. **Stop and say why** when:
   - **Detached HEAD:** `status` opens with `HEAD detached`.
   - **An operation is in progress:** `status` names a merge, rebase, cherry-pick or revert (`resolve-conflicts` › *Step 0 — Detect the Operation, the Sides and the Repo*). Route to [`/resolve-conflicts`](../resolve-conflicts/SKILL.md), except a **resolved merge** (`All conflicts fixed but you are still merging`): conclude it per [references/resolved-merge.md](references/resolved-merge.md).
   - **Protected/default branch:** `main`, `master`, `develop`, `release/*`, or `origin/HEAD` — unless the repo is a trunk-only personal repo (e.g. `~/.terminal` or `~/.terminal/memory`). Otherwise propose a branch name in the repo's convention and create it only on approval.
   - **Nothing to commit and nothing to push:** say so in one line and stop.

### Step 2: Skill-drift gate (before grouping)

Claim fixes are grouped with the change that caused them. The checker is the first that the Step 1 `ls-files` printed:

| Checker | Claims file | Triage per |
|---|---|---|
| `skills/skill-drift/scripts/check_skill_drift.py` (the `~/.terminal` registry) | `skills/skills-claims.json` | [`/skill-drift`](../skill-drift/SKILL.md) |
| `.claude/scripts/check_skill_drift.py` (a project repo) | `.claude/claims/` (one file per source; `.claude/skills-claims.json` on repos not yet split) | that repo's drift skill |

No checker → state `"no skill-drift check"` and go to Step 3.

Run `python3 -I <repo-root>/<checker>` (full run, no `--file`). No STALE or FAIL row and no ORDER or MISPLACED section → go on. Otherwise fix it per [references/drift-fix.md](references/drift-fix.md) before Step 5, and stage the claim edits with the change that caused them.

### Step 3: Choose what goes into the commit

From the Step 1 `status` and `diff --stat`:

- **Paths given in arguments:** stage only those (`git -C <repo-root> add -- <path> …`).
- **Already staged:** commit the staged set and name what stays unstaged.
- **Otherwise:** stage only files belonging to this change. Unrelated concerns → separate commits; ask first, except in a trunk-only personal repo (Step 1): split without asking and name the split in chat.
- **Always exclude and name in chat:** secrets/local config (`.env*`, `*.pem`, `*.key`, `appsettings.local.json`, `credentials*`), build/test output (`bin/`, `obj/`, `dist/`, `build/`, `test-results/`), ignored/generated files, editor settings, workspace-root artifacts (`<prefix>-<artifact>-<suffix>.md`), and scratch files.
- **Secret check** on the staged diff, every run, before Step 5 (a hit stops the commit; mask the value and ask). Two plain calls, never a pipe: a session isolated with `EnterWorktree` (`/wt-close-all`) refuses a piped `git` command:
  ```bash
  git -C <repo-root> diff --staged -U0 --output=<scratchpad>/staged.diff
  grep -nE '(-----BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{36}|xox[baprs]-|(password|secret|api[_-]?key|token)["'\'' ]*[:=] *["'\''][^"'\'' ]{8,})' <scratchpad>/staged.diff
  ```

### Step 4: Run the repo's pre-commit gates

- Run only the pre-commit gates documented in the repo's rulebook (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, workflow skill), scoped to changed files when supported (e.g. formatter, import organiser, lint). None documented → state `"no pre-commit gates documented"` and continue.
- **Run independent gates at the same time**: when gates cover separate parts (backend and frontend, two repos), start the slowest with `run_in_background` and run the others meanwhile, keeping each part's own order (formatter before build or lint). Draft the Step 5 message while they run.
- Re-stage only files already in the commit if a formatter modifies them; report any untouched files it modified.
- **A failing gate or git hook stops the commit.** Fix mechanical formatting/lint issues inside the staged change; otherwise report the failure output and stop. Never `--no-verify`.
- **`leak-guard` rejection** (the `pre-commit` hook names a file that "adds a string from .leak-denylist or .env*"): fix it without asking, per [references/leak-guard.md](references/leak-guard.md).

### Step 5: Write the message and commit

- **Convention (first match wins):** (1) user's explicit message from arguments, (2) repo rulebook / workflow skill, (3) commitlint / Conventional Commits / `.gitmessage`, (4) pattern of the Step 1 `log` (e.g. `#<id>: <imperative>`, `feat(scope): …`).
- **Work-item ID:** extract from the branch name (`feature/30342_slug` → `30342`) or recent branch commits; ask if required and missing.
- **Subject & body:** imperative mood, ≤72 chars including prefix, no trailing period, matching recent commit language; add a bulleted body only when the change spans multiple behaviours.
- **Trailer (canonical rule):** apply the attribution trailer rule in force — the project profile's or user's trailer policy overrides the host's default attribution instruction (if a project forbids trailers, add none). A trailer that names a model names the session's working model, the one that wrote the change, never the `model:` this skill runs under; when the working model is unknown, use the model-neutral `Co-Authored-By: Claude <noreply@anthropic.com>`.
- **Commit from a scratchpad file** so shell metacharacters (`!`, backticks) are never expanded, then read the commit back:
  ```bash
  git -C <repo-root> commit -F <scratchpad>/commit-msg.txt
  git -C <repo-root> log -1 --stat --format='%h %s%n%(trailers:key=Co-Authored-By,valueonly)'
  git -C <repo-root> log '--format=%h %(trailers:key=Co-Authored-By,valueonly)' '@{u}..HEAD'
  ```
  The second `log` lists every commit this push sends. On a branch with no upstream (Step 1 `status`), end it with `HEAD --not --remotes=origin` in place of `'@{u}..HEAD'`. Together the read-backs must show the intended files, the convention and a trailer that follows the rule. A trailer that names this skill's own `model:` instead of the working model, on any of those commits: do not push; stop and report it, interactive and `gcai` alike (rewording needs `--amend`).

### Step 6: Push

Skip under `no-push`. Otherwise ensure upstream matches the branch itself (never push a feature branch onto `origin/main` when `@{u}` points at `origin/main`). The Step 1 `status` names the upstream in quotes (`Your branch is … 'origin/<x>'`); no such line, or `the upstream is gone`, means none is set.

- Upstream is `origin/<BR>`, the branch's own name → `git -C <repo-root> push`.
- Any other upstream, or none → `git -C <repo-root> push -u origin HEAD`.
- Read the push back in the same message: `git -C <repo-root> status -sb`.
- **Behind upstream (non-fast-forward, `fetch first`):** integrate and push; do not stop to ask. `/commit` was the request to get the commit onto the remote. Follow [references/behind-upstream.md](references/behind-upstream.md).
- **Rejected by branch policy, hook or permissions:** stop and show the server message verbatim. Never force-push.

### Step 7: Check the PR and its stack, then regenerate the description

Skip under `no-push` or when the push failed. No PR can exist, so send no lookup and report `no open PR for this branch`, when the push created the remote branch (it printed `* [new branch]`), or the commit went onto the default branch of a trunk-only repo (Step 1).

Otherwise resolve the branch's open PR per `pr-host` › *Resolve the PR from a branch*. A branch that had an upstream sends the lookup with the push; one that had none waits for the push output.

- No open PR → report `no open PR for this branch`, do not create one, and skip the rest of this step.
- Several open PRs → list them and ask which one to update.
- One open PR → follow [references/pr-description.md](references/pr-description.md): the stack, the behind-`main` warning and the generated description block.

### Step 8: Remove the worktree

Skip under `no-push`, when the push failed, or when `<repo-root>` is the main checkout (the Step 1 `rev-parse` printed the same directory as git dir and as common dir). Also skip when this session's working directory is inside `<repo-root>` (`EnterWorktree`, `gcai` run from a shell in the tree): removing it pulls the directory out from under the session or shell. `/wt-close-all` removes those after `ExitWorktree`.

Otherwise remove it per [references/worktree-removal.md](references/worktree-removal.md).

---

## 3. Output Format & Deliverables

```markdown
✅ Committed and pushed <repo-dirname> `<branch>` → `origin/<branch>`
- `<short-sha>` <subject>
- Files: <n> (<list>) · gates: <what ran> ✅
- Left out: <path> (<reason>)
- PR: [<repo> !<id>](<url>) now at `<short-sha>` · generated block rewritten (English, <n> commits; manual part kept) (or: no open PR for this branch)
- Worktree: removed `<repo-root>` (or: kept: <reason> · skipped: main checkout | session inside it)

Next: <one action, e.g. rebasing the base or opening a PR>.
```

A `references/` file that ran adds the line it names (`Rebased onto …`, `Changed: …`, `Stale: …`, `Stack: …`). Under `no-push`, state the commit is local and how many commits are unpushed, and leave out the PR and Worktree lines.

---

## 4. Verification & Validation

- The Step 5 read-back matches the intended files and convention.
- After pushing, the Step 6 read-back opens with `## <branch>...origin/<branch>` and no `ahead`, and lists only the excluded files named in chat.
- No amend, force-push, `--no-verify`, reset, or stash ran, and no rebase except Step 6 › *Behind upstream* (named in the output with the incoming commits).
- A PR description update and a worktree removal are verified in their `references/` files.
