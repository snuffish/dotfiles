---
name: commit
description: "Runs the skill-drift check first and fixes STALE claims surgically, then stages changed files, runs documented pre-commit gates (formatters, linters, tests), formats commit messages matching repo conventions (Conventional Commits or branch work-item prefix), and pushes to upstream. After the push, finds the branch's open PR and the branch it is stacked on, warns when that base is behind main, and regenerates its marked description block in English from the commits, leaving hand-written parts untouched. Refuses commits on default branches or detached HEAD."
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
- `../_modules/git-worktrees.md`: only with an incoming `[worktree-context]` block, which names the `repo-root` to commit in; otherwise runs in place
- `../_modules/pr-host.md`: to resolve the PR, its target branch and the stack in Step 7
- `../_modules/outward-writes.md`

- Invoking `/commit` (or explicitly asking to commit/push in the current message) satisfies `outward-writes` › *Explicit request & draft mode* for this commit and push, and for the Step 7 description update of the branch's own open PR only (never its title, labels, draft state or any other PR).
- **Never** `git add -A` / `git add .`, `--amend`, `--no-verify`, `--force` / `--force-with-lease`, `rebase`, `reset`, or `stash` here (unless the user explicitly asks for `--force-with-lease` in the current message). The one exception is Step 6 › *Behind upstream*: `git pull --rebase --autostash` of this branch's own unpushed commits onto `@{u}`.
- Every command uses `git -C <repo-root> …` (`git-worktrees` › *Golden Invariants*).

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
git -C <repo-root> diff --stat
git -C <repo-root> diff --staged --stat
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
- **Trailer (canonical rule):** apply the attribution trailer rule in force — the project profile's or user's trailer policy overrides the host's default attribution instruction (if a project forbids trailers, add none). A trailer that names a model names the session's working model, the one that wrote the change, never the `model:` this skill runs under; when the working model is unknown, use the model-neutral `Co-Authored-By: Claude <noreply@anthropic.com>`. Before Step 6, run `git -C <repo-root> log '--format=%h %(trailers:key=Co-Authored-By,valueonly)' '@{u}..HEAD'` (on a branch with no upstream, `<base>..HEAD`) and reword any commit whose trailer names this skill's own model.
- **Commit from a scratchpad file** so shell metacharacters (`!`, backticks) are never expanded:
  ```bash
  git -C <repo-root> commit -F <scratchpad>/commit-msg.txt
  ```

### Step 6: Push

Skip under `no-push`. Otherwise ensure upstream matches the branch itself (never push a feature branch onto `origin/main` when `@{u}` points at `origin/main`):

Run each as its own Bash call:

1. `git -C <repo-root> rev-parse --abbrev-ref HEAD` gives the branch `<BR>`.
2. `git -C <repo-root> rev-parse --abbrev-ref --symbolic-full-name @{u}` gives the upstream. It fails when none is set.
3. When the upstream is `origin/<BR>`, run `git -C <repo-root> push`. Otherwise, or when step 2 failed, run `git -C <repo-root> push -u origin HEAD`.

- **Behind upstream (non-fast-forward, `fetch first`):** integrate and push; do not stop to ask. Run the same push mode: `/commit` was the request to get the commit onto the remote.
  1. Note the incoming commits: `git -C <repo-root> fetch` then `git -C <repo-root> log --oneline HEAD..@{u}` (name them in the output).
  2. `git -C <repo-root> pull --rebase --autostash`. This only replays this branch's unpushed commits onto `@{u}`; nothing already pushed is rewritten.
  3. **Conflicts:** resolve them in place per [`/resolve-conflicts`](../resolve-conflicts/SKILL.md) (rebase mode: Steps 1–6), then `git -C <repo-root> -c core.editor=true rebase --continue` until done. When a hunk's intent cannot be reconstructed with confidence, run `git -C <repo-root> rebase --abort`, confirm `HEAD` is back on the local commit, and stop with the conflicting files and the incoming commits.
  4. **Re-run the Step 2 drift checker** when `git -C <repo-root> diff --name-only ORIG_HEAD HEAD` (or the incoming log) touches `skills/`, `.claude/`, `AGENTS.md` or the claims file. STALE fixes become their own follow-up commit (`fix(skills): …`), committed per Step 5.
  5. Push again (plain `git -C <repo-root> push`). Rejected a second time for the same reason → repeat once from 1, then stop.
- **Rejected by branch policy, hook or permissions:** stop and show the server message verbatim. Never force-push.

### Step 7: Check the PR and its stack, then regenerate the description

Skip under `no-push` or when the push failed.

1. **Find the PR:** resolve the branch's open PR per `pr-host` › *Resolve the PR from a branch*. No open PR → report `no open PR for this branch`, do not create one, and skip the rest of this step. Several open PRs → list them and ask which one to update.
2. **Find the stack:** take the PR's target branch `TGT` (strip `refs/heads/` per `pr-host` › *Branch names & Diff base*) and the default branch `DEF` (`git -C <repo-root> symbolic-ref --short refs/remotes/origin/HEAD`, minus `origin/`). Then `git -C <repo-root> fetch origin "$TGT" "$DEF"`.
   - `TGT` = `DEF` → not stacked.
   - `TGT` ≠ `DEF` → stacked on `TGT`. Resolve `TGT`'s own open PR the same way and repeat until a target is `DEF` (stop after 5 levels), giving the chain, e.g. `this !B → feature/x !A → main`.
3. **Warn when the base is behind main** (stacked only): `git -C <repo-root> rev-list --count origin/$TGT..origin/$DEF`. A count above 0 → `⚠️ <TGT> is <n> commits behind <DEF>`, and suggest rebasing the base first. Never rebase or merge here.
4. **Regenerate the description from the commits:**
   - Read the commits the PR adds: `git -C <repo-root> log --reverse --format='%h %s%n%b' origin/$TGT..HEAD`, plus `git -C <repo-root> diff --stat origin/$TGT...HEAD` to check each claim against what changed.
   - Read the current description first and save it to `<scratchpad>/pr-<id>/previous.md` so it can be restored (`pr-desc` › *Apply*, item 2).
   - **Rewrite only the generated block.** The text between `<!-- commit:auto:start -->` and `<!-- commit:auto:end -->` belongs to this skill. Everything outside the markers is hand-written (screenshots, reviewer notes) and stays byte for byte.
     - One marker pair → replace only what is between the markers.
     - No markers (first run) → the new description is the generated block, followed by `## Manual` and the old description verbatim (leave the section out when the old description is empty).
     - A lone marker or several pairs → do not write. Print the generated block and ask where it goes.
   - **Check the manual part for stale claims.** Byte for byte means unedited, not unchecked: read the manual part against the commits and the PR's live state (target branch, merged or abandoned PRs it names, behaviour, counts). List every line the change made false (`"<quote>"` → what is true now) in chat and in the output's `Stale` line. Fix them only on the user's go, as their own text; then they are no longer byte for byte, so say so.
   - Write the block **in English**, whatever the profile's *Report language*. Follow the repo PR template per `pr-desc` › *Step 4 — Compose the body and title* item 1. Group the commits by behaviour (one bullet per behaviour, not one per commit), and open the block with `Stacked on !<id>` when Step 2 found a stack. Run `outward-writes` › *Voice pass* on the block only.
   - **4000-character budget for the whole description:** when it is over, shorten the generated block, never the manual part. When the manual part alone is over, do not write: print the block and say so.
   - Apply only the description per `pr-desc` › *Apply* item 3 (body from `<scratchpad>/pr-<id>/body.md`; on Azure DevOps always pass `--draft <isDraft>` from the read-back). Then read it back per `outward-writes` › *Read back*.
   - A denied or failed write → print the body and the exact command, then continue to the output.

---

## 3. Output Format & Deliverables

```markdown
✅ Committed and pushed <repo-dirname> `<branch>` → `origin/<branch>`
- `<short-sha>` <subject>
- Rebased onto <n> incoming commits (<conflicts resolved: files | clean>; drift re-run: <result>) (only when Step 6 integrated)
- Files: <n> (<list>) · gates: <what ran> ✅
- Left out: <path> (<reason>)
- PR: [<repo> !<id>](<url>) now at `<short-sha>` · generated block rewritten (English, <n> commits; manual part kept) (or: no open PR for this branch)
- Stale: <n> manual-part lines contradict the change: "<quote>" → <now> (or: none)
- Stack: `<branch>` → `<TGT>` !<id> → `main` (or: not stacked)
- ⚠️ `<TGT>` is <n> commits behind `main`: rebase the base first (only when it is)

Next: <one action, e.g. rebasing the base or opening a PR>.
```

Under `no-push`, state the commit is local and how many commits are unpushed, and leave out the PR and Stack lines.

---

## 4. Verification & Validation

- `git -C <repo-root> log -1 --format='%h %s'` and `show --stat HEAD` match the intended files and convention.
- After pushing, `git -C <repo-root> rev-list --count @{u}..HEAD` is `0` and `@{u}` is `origin/<branch>`.
- After Step 7, the live PR description matches `<scratchpad>/pr-<id>/body.md`, everything outside the markers matches `previous.md`, and on Azure DevOps `isDraft` is unchanged.
- `git -C <repo-root> status --short` holds only the excluded files named in chat; no amend, force-push, `--no-verify`, reset, or stash ran, and no rebase except Step 6 › *Behind upstream* (named in the output with the incoming commits).
