# git-worktrees

One protocol for every skill that must read or change a repository without touching the user's main checkout. `/code-review` and `/pr-feedback-review` use **snapshot** mode by default; `/implement-feature` uses **workspace** mode by default; every other mutating skill switches to workspace mode when invoked with the word `worktree` or when it runs under `/implement-feature`. Each of them delegates here instead of carrying its own copy of the lifecycle.

---

## Modules

Read these before using this one:
- [core.md](core.md) (same folder as this file)

Artifacts stay at the **workspace root** and keep workspace-relative paths. This Module writes none; its deliverables are the worktree, the `[worktree-context]` block handed to the calling Command, and the hand-off line in chat.

---

## Using this Module from a Command

A Command that lists this Module in its `## Modules` section gets both rules below without restating them. Its `git-worktrees` line names only its default mode (`snapshot by default`, `workspace by default`, or nothing for "in place unless opted in").

- **Isolation.** When the invocation contains the opt-in token `/worktrees` (*Modes* › *Opt-in token*), a `[worktree-context]` block was handed in, or the Command runs under `/implement-feature`, a mutating Command edits in a workspace worktree (*Workspace Lifecycle*) and a read-only Command reads from a snapshot (*Snapshot Lifecycle*). Otherwise it uses its default mode, or works in place. The opt-out token `/no-worktrees` (*Modes* › *Opt-out token*) overrides the default mode, so the Command works in place. The main checkout stays read-only while a worktree is active (*Golden Invariants*).
- **Repo root.** The `repo-root` of a `[worktree-context]` block handed in by the caller when one is present; otherwise the discovery the Command does today. Every `git` command and file path resolves under it. Before any `git status`, `stash create`, `checkout`, `add`, `commit` or `push`, confirm the target is that root. If no block was handed in but `git -C <repo> worktree list --porcelain` shows a **locked** worktree whose reason begins with `claude-skill:` for the same ticket or branch, stop and ask which tree is meant.

---

## ⛔ Golden Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR DEVIATION:**
>
> 1. **THE MAIN CHECKOUT IS READ-ONLY WHILE A WORKTREE IS ACTIVE FOR ITS REPO.** No `status`-driven decisions, `stash create`, `checkout`, `switch`, `add`, `commit`, `push`, `reset` or file edits there, by you or by any sub-agent. The only writes outside a worktree are artifacts at the workspace root and the `.git/info/exclude` entry in §5b. `/proceed` approves edits in the worktree; it does not lift this invariant.
> 2. **THE SESSION'S WORKING DIRECTORY NEVER MOVES.** Every command is `git -C <path>` or an absolute path. Artifact links are workspace-root-relative and break the moment the cwd changes.
> 3. **NO HOST WORKTREE TOOLING.** Do not use Claude Code's `EnterWorktree`, `ExitWorktree`, `claude --worktree` or the Agent tool's `isolation: "worktree"` to satisfy this protocol: they are Claude-Code-only, they act on the repository of the launch directory (an empty shell in a multi-repo workspace), they move the cwd, and they name branches `worktree-<name>` against every project's convention. `EnterWorktree` with `path:` is acceptable **only** when the user asks to step into a kept worktree themselves (§5h).
> 4. **ONE WORKTREE PER REPO IN SCOPE.** A two-repo change has two worktrees, two context blocks and two removals.
> 5. **SUB-AGENTS NEVER CREATE, REMOVE, LOCK OR UNLOCK WORKTREES.** The orchestrating skill does it before spawning and after the last sub-agent returns. Sub-agents receive the context block and read or edit inside `repo-root` only.
> 6. **NEVER DELETE A BRANCH.** Removing a worktree keeps its branch; the branch is what survives. Branch deletion happens only on the user's explicit instruction.
> 7. **`--force` REMOVAL ONLY IN SNAPSHOT MODE.** A workspace worktree may hold the only copy of unpushed work; it is removed without `--force` and only when §5g's preconditions hold, or on the user's explicit "discard".

---

## 1. Modes

| Mode | Purpose | Location | Branch | Removed when |
|---|---|---|---|---|
| **snapshot** | Read a pinned head (branch, PR, working tree or index) while the user keeps editing | `<scratchpad>/<skill>/<repo-dirname>/<ref-slug>@<short-sha>` (the session scratchpad when the host provides one, else `${TMPDIR:-/tmp}`) | detached | Always, after the calling skill's artifact is written |
| **workspace** | Implement on a branch without touching the main checkout | `<repo>/.claude/worktrees/<slug>` | the project's branch convention | After the branch is pushed and the PR exists; otherwise kept and reported |

Default users: `/code-review`, `/pr-feedback-review` → snapshot; `/implement-feature` → workspace. `clean`, `expressive`, `organize`, `refine`, `problem`, `pr-fix-pipeline`, `squash-ef-core-migrations` → workspace when opted in (below) or under `/implement-feature`, otherwise in place. Other read-only skills keep their live, head-pinned reading unless opted in, which gives them a snapshot.

**Opt-in token.** Any skill invocation whose arguments contain the token `/worktrees` runs under this protocol even when the skill does not isolate by default, e.g. `/refine <request> /worktrees` or `/explain deep <symbol> /worktrees`. Only that exact token counts. The bare words `worktree` and `worktrees` are ordinary text, because requests are often *about* worktrees: `/explain how git worktree prune works` or `/plan add worktree support` must run where they were asked. A user who writes "do this in a worktree" without the token is asking the `worktrees` Command, whose description triggers on that phrasing. Only the first `/<name>` in a message is a command; `/worktrees` later in the line is plain text the invoked skill must recognise, which `core` › *Worktree opt-in* makes a universal rule. A prompt that invokes no Command ("Merge PR 123 & 456 /worktrees") goes to the `worktrees` Command, which routes the request to a matching Command or runs it under this protocol itself. A mutating skill gets **workspace** mode, a read-only skill gets **snapshot** mode. The skill loads this file, follows §2–§5 for the mode, and otherwise runs unchanged with `repo-root` as its repository.

**Opt-out token.** The token `/no-worktrees` does the opposite: the Command creates no worktree and works in place, even when its default is snapshot or workspace, e.g. `/code-review 123 /no-worktrees` or `/implement-feature 1234 /no-worktrees`. A snapshot-by-default Command reads the live checkout, as its `live` modifier does, and accepts that edits during the run shift line numbers. A workspace-by-default Command edits the user's checkout: it switches or creates the branch there only after asking when the checkout has uncommitted changes or is on another branch. The token never moves work that already lives in a kept worktree (`/continue` resumes there), and a `[worktree-context]` block handed in by a caller still wins. Both tokens in one invocation → ask. A prompt that invokes no Command ("bump the package /no-worktrees") goes to the `no-worktrees` Command.

Why the workspace location is inside the repo: it is under the host's project directory in single-repo workspaces (so file edits do not prompt per file), it is where Claude Code's own tooling looks, and a kept worktree can be entered by the user with `EnterWorktree path:`. The cost is the exclude entry in §5b and the search glob in §5d. Snapshots live in the scratchpad because nothing of the user's ever lives in them.

---

## 2. Repo Resolution

```bash
find <workspace-root> -maxdepth 2 -name .git            # every repo under the workspace root
git -C <candidate> rev-parse --show-toplevel            # confirm each one
```

- A workspace root that is itself a repo **but ignores its child repos** (e.g. `~/Projects/GR` ignores `GR.PRIIS.Backend/` and `GR.PRIIS.Frontend/`) is a shell: skip it and work per child repo.
- `<repo-dirname>` is the directory name under the workspace root (e.g. `GR.PRIIS.Backend`); for a single-repo workspace it is the repo's own directory name and `workspace-path` is empty.
- Every step below runs **per repo in scope**.

---

## 3. The `[worktree-context]` Block — Active Repo Root Contract

Delegated skills (`/code-review`, `/spec-verification`, `/pr-summary`, verify and ship recipes) discover "the repo" from the workspace root or the cwd on their own. Without this block they would act on the main checkout. The calling skill therefore pastes the block **verbatim** into every delegated skill invocation and every sub-agent brief, one block per repo:

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

Every delegated skill follows the *Repo root* rule in *Using this Module from a Command*.

The lock reason (§5b) is the discovery mechanism, so no marker file is left in the tree and `git status` stays clean. Its `session:` token ties a worktree to the session that created it; the Claude Code status line (`claude/statusline.sh`) matches it against its own `session_id` to show the worktrees this session works in. A new session (`/clear`) no longer matches a kept worktree.

---

## 4. Snapshot Lifecycle (read-only)

Used by `/code-review`, `/pr-feedback-review` and by any read-only skill asked for a snapshot. `<skill>` is the calling skill's name.

**a. Resolve the head and record its source ref — per repo**

| Scope | Head to snapshot | Source ref to record |
|---|---|---|
| branch head (default) | `git -C <repo> rev-parse HEAD` | `<local-branch>` |
| PR whose branch is not checked out | `git -C <repo> fetch origin <source-branch>`, then `git -C <repo> rev-parse origin/<source-branch>` | `origin/<source-branch>` |
| working tree | `SNAP=$(git -C <repo> stash create)` → head is `$SNAP` | `<local-branch> + working tree` |
| index | `SNAP=$(git -C <repo> stash create)` → head is `$SNAP^2` | `<local-branch> + index` |

`<source-branch>` and `<target-branch>` are the PR's branch names **without** the `refs/heads/` prefix that Azure DevOps returns ([pr-host.md](pr-host.md) › *Branch names*).

`<local-branch>` is `git -C <repo> rev-parse --abbrev-ref HEAD` (`detached` when it prints `HEAD`). The snapshot is detached, so its own `HEAD` carries no branch name: capture the source ref **now** and carry it next to the SHA everywhere the head is mentioned. A bare SHA in an artifact is a defect.

Also record how the main checkout relates to the head:

```bash
git -C <repo> rev-parse --abbrev-ref HEAD                   # main checkout's branch
git -C <repo> rev-list --left-right --count <head>...HEAD   # "<behind> <ahead>"
```

`git stash create` writes one unreferenced commit object and changes nothing else. An empty result means the tree is clean: the working-tree scope is empty, stop. It does **not** capture untracked files — list them with `git -C <repo> ls-files --others --exclude-standard`, read them from the main checkout, and mark citations into them `(live, untracked)`.

When the caller handed in a **workspace** `[worktree-context]`, `<repo>` above is its `repo-root` (the worktree), and the main checkout is reported separately as "user's checkout on `<branch>`, not reviewed".

**b. Create**

```bash
SNAP_DIR=<scratchpad>/<skill>/<repo-dirname>/<ref-slug>@<short-sha>   # ref-slug: '/' → '-'
git -C <repo> worktree prune
git -C <repo> worktree add --detach "$SNAP_DIR" <head>
```

Reuse `$SNAP_DIR` when it exists and `git -C "$SNAP_DIR" rev-parse HEAD` equals `<head>`; otherwise remove it first. Emit a `[worktree-context]` with `mode=snapshot`, `branch=detached`, `source-ref` filled.

**c. Read**

Every diff, log, grep and file read runs with `-C "$SNAP_DIR"` or on paths under it. Inside the snapshot `HEAD` **is** the pinned head and remote refs are shared, so `git diff <base>...HEAD` works unchanged. A code-intelligence index (e.g. CodeGraph) covers the main checkout only: use it for navigation, open the same file in the snapshot for the citation. When the main checkout's `HEAD` equals the head and its `git status` is clean, index lines are exact and may be cited directly; say which case applied.

**d. Map paths back (mandatory)**

Before any `path:line` reaches an artifact or the chat, replace the `$SNAP_DIR` prefix with `workspace-path`. A link into the scratchpad is a defect.

**e. Remove**

After the artifact is written and its links are emitted — in a fan-out, after every sub-agent has returned:

```bash
git -C <repo> worktree remove --force "$SNAP_DIR"   # disposable: nothing of the user's lives there
git -C <repo> worktree prune
```

Say in chat that the snapshot of `<source-ref> @ <short-sha>` was removed, or why it was kept (the user asked to keep it).

**f. When no snapshot is possible**

Files never committed, a directory that is not a repository, or a failing `worktree add` → read the main checkout live, record `live checkout` in the artifact, and warn that edits during the run invalidate line numbers.

---

## 5. Workspace Lifecycle (implementation)

**a. Base and branch**

```bash
git -C <repo> fetch -q origin
DEFAULT=$(git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD)   # e.g. origin/main
```

- Default base: `origin/<default>` as just fetched ("branch out of latest main"). A caller may pass another base explicitly (a release branch, a PR head).
- Branch name: the project's convention from its workflow skill or profile (e.g. `feature/<id>_<slug>`), **never** `worktree-<name>`.
- If the branch already exists:
  - checked out in no worktree → `git -C <repo> worktree add --lock --reason "<reason>" <dir> <branch>` (check it out, no `-b`);
  - checked out in the **main checkout** → **stop and ask** the user: switch the main checkout off it, or branch off its head under a derived name (`<branch>-wt`, say). Do not decide this alone; the main checkout is theirs.
  - checked out in another worktree → it belongs to another run; report the lock reason and ask.

**b. Create**

```bash
SLUG=<ticket-id>-<kebab-slug>                                   # or the branch slug
DIR=<repo>/.claude/worktrees/$SLUG
REASON="claude-skill:<skill> ticket:<id> branch:<branch> started:$(date +%F) session:<session-id>"   # session id as in artifact-protocol › Claim › owner marker
git -C <repo> worktree prune
EXCLUDE="$(git -C <repo> rev-parse --path-format=absolute --git-common-dir)/info/exclude"   # absolute: a relative .git would resolve against the session cwd, i.e. the wrong repo
git -C <repo> check-ignore -q .claude/worktrees/probe || echo '.claude/worktrees/' >> "$EXCLUDE"   # idempotent: skipped when any rule already ignores the path
git -C <repo> worktree add --lock --reason "$REASON" --no-track -b <branch> "$DIR" <base>
```

The exclude entry is local and never committed; it keeps the directory out of `git status` and the host's own `Grep` tool (`rg` also skips the hidden `.claude/` directory by default). `--no-track` matters: without it a branch created from `origin/<default>` would report that remote branch as its upstream, and §5g's "nothing unpushed" check would compare against the wrong ref. The lock reason is what §3's rule and §5i read. Emit the `[worktree-context]` with `mode=workspace`.

**c. Hydrate**

A worktree is a fresh checkout: ignored files and dependencies are absent.

1. Copy each file on the project's **Worktree include list** ([project-profile.md](project-profile.md) › *Shared fields*, answered by the base profile; typical entries: `appsettings.local.json`, `.env.local`, local secrets) from `main-checkout` into `repo-root` — a read of the main checkout, never a write. Report what was copied; say which listed files did not exist.
2. Run the project's **Dependency hydration** commands inside `repo-root` from the base profile (*Shared fields*; e.g. `npm ci` in the package directory; .NET restores on first build). Without a base profile, derive them from the lockfiles present. Dependency symlinking is off unless the base profile enables it.
3. Do **not** copy `.claude/settings.local.json` or other host state; it is not needed to build or test.

**d. Work**

- Every git command is `git -C <repo-root>`; every file read or edit uses absolute paths under `repo-root`.
- Every sub-agent brief carries the block and the sentence *"Read-only; work only under `repo-root`; never touch `main-checkout`; report paths as `workspace-path` + relative path."*
- Artifacts and chat use `workspace-path` + relative path, never the worktree path.
- Workspace-wide searches (`rg`, `grep -r`, `find`) add `-g '!**/.claude/worktrees/**'` (or the equivalent `--exclude-dir`) so the worktree's copies do not count as consumers.
- A code-intelligence index covers the main checkout: navigate there, cite from the worktree.

**e. Verify**

Run the project's verify commands inside `repo-root`. First check for parallel runs:

```bash
git -C <repo> worktree list --porcelain | grep -c '^locked claude-skill:'
```

If another `claude-skill:` worktree of the same repo is active, run **targeted suites only** and say why: dev-server ports, a local API port and a local database (the base profile's **Shared local services**, [project-profile.md](project-profile.md) › *Shared fields*) are shared between worktrees, so concurrent full suites collide and flake.

**f. Land**

Commits, `git -C <repo-root> push -u origin <branch>` and PR creation all run inside `repo-root`, behind the calling skill's gates (plan gate, ship gate). Nothing here lifts a gate.

**g. Remove**

Two procedures; never confuse them.

*Landed (automatic):* all three must hold —

```bash
test -z "$(git -C <repo-root> status --porcelain)"                      # clean
test "$(git -C <repo-root> rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)" = "origin/<branch>"   # upstream is the branch's own remote counterpart
test "$(git -C <repo-root> rev-list --count @{u}..HEAD)" = 0             # nothing unpushed
```

then

```bash
git -C <repo> worktree unlock "$DIR"
git -C <repo> worktree remove "$DIR"        # no --force
git -C <repo> worktree prune
```

*Not landed (keep):* the ship gate was declined, the run was interrupted, or any precondition fails → keep the worktree locked and report its path, branch, what is uncommitted or unpushed, and the resume command (`git -C <repo> worktree list`). Remove it only on the user's explicit **"discard"** — then `worktree unlock` + `worktree remove --force` + `prune`. Delete the branch only on a further explicit instruction.

**h. Hand-off line (mandatory in chat and in any walkthrough)**

State, per repo: which branch holds the work; that the user's checkout is unchanged and on `<its branch>`; whether the worktree was removed or kept (and why); and how to see the work — `git -C <repo> checkout <branch>` after stashing their own changes, or, while the worktree is kept, open `<dir>` directly (`EnterWorktree path:<dir>` in Claude Code). Remind that `/manual-testing` tests what is on disk, so manual tests run from the kept worktree or after the checkout.

**i. Crash recovery**

```bash
git -C <repo> worktree list --porcelain      # paths, HEADs, 'locked <reason>' lines
git -C <repo> worktree prune                 # drops admin entries whose directory is gone
ls <repo>/.claude/worktrees/                 # directories with no admin entry are orphans — list them, never delete silently
```

A locked `claude-skill:` worktree from an earlier session is reported to the user with its reason; it is never removed as a side effect of a new run.

---

## 6. Host Notes

- The commands above are identical under Antigravity IDE and Claude Code; the only host-specific input is the scratchpad path for snapshots.
- Claude Code's built-ins (`--worktree`, `EnterWorktree`, Agent `isolation: "worktree"`) move the cwd, act on the launch repository, branch as `worktree-<name>` from `worktree.baseRef`, and leave sub-agent changes with no documented merge-back. Their one useful guard — refusing to remove a worktree with unsaved work — is reproduced as §5g, not inherited by calling them.
- `WorktreeCreate` / `WorktreeRemove` hooks do not fire for `git worktree` run through the shell; nothing here depends on them.

---

## 7. Quick Reference

| Need | Do | Not |
|---|---|---|
| Read a pinned head while the user edits | §4 snapshot, scratchpad, `--detach`, remove `--force` | read the main checkout live |
| Implement without touching the checkout | §5 workspace, `<repo>/.claude/worktrees/<slug>`, `--lock --reason`, project branch name | `EnterWorktree`, `worktree-<name>`, `cd` |
| Tell a delegated skill where the repo is | paste the `[worktree-context]` block | rely on its cwd discovery |
| Branch already checked out in the main checkout | stop and ask | `checkout` the user's tree, `-f` |
| Missing `appsettings.local.json` / `.env` | copy from the base profile's *Worktree include list* | run tests against defaults |
| Second run on the same repo | targeted suites, say why | full suite in parallel |
| Done | landed → unlock, remove, prune; else keep and report | `remove --force` on unpushed work |
| Branch | keep | delete |
