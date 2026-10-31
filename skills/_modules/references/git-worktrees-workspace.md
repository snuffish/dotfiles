# Workspace Lifecycle (implementation)

On-demand reference for [git-worktrees.md](../git-worktrees.md). Read before running **workspace** mode.

---

## Reuse an active linked worktree (`claude --worktree` / `EnterWorktree`)

Before creating a worktree, check whether `<repo>` is already a linked worktree:

```bash
GIT_DIR=$(git -C <repo> rev-parse --path-format=absolute --git-dir)
COMMON_DIR=$(git -C <repo> rev-parse --path-format=absolute --git-common-dir)
```

When `$GIT_DIR != $COMMON_DIR`:
1. Do **not** create a nested worktree. Set `repo-root` to `$(git -C <repo> rev-parse --show-toplevel)` and `main-checkout` to `$(dirname "$COMMON_DIR")`.
2. If the current branch matches `worktree-*`, rename it in place to the project's branch convention (`git -C <repo-root> branch -m <branch>`) and unset any accidental upstream to `origin/<default>` (`git -C <repo-root> branch --unset-upstream 2>/dev/null || true`).
3. Lock the worktree with the standard `claude-skill:` reason if not already locked, emit the `[worktree-context]` block, and proceed directly to **Hydrate**.

## Base and branch

```bash
git -C <repo> fetch -q origin
DEFAULT=$(git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD)   # e.g. origin/main
```

- Default base: `origin/<default>` as just fetched ("branch out of latest main"). A caller may pass another base explicitly (a release branch, a PR head).
- Branch name: the project's convention from its workflow skill or profile (e.g. `feature/<id>_<slug>`), **never** `worktree-<name>`.
- If the branch already exists:
  - checked out in no worktree → `git -C <repo> worktree add --lock --reason "$REASON" <dir> <branch>` (check it out, no `-b`; format `$REASON` per *Create*);
  - checked out in the **main checkout** → **stop and ask** the user: switch the main checkout off it, or branch off its head under a derived name (`<branch>-wt`, say). Do not decide this alone; the main checkout is theirs.
  - checked out in another worktree → it belongs to another run; report the lock reason and ask.

## Create

```bash
SLUG=<ticket-id>-<kebab-slug>                                   # or the branch slug
DIR=<repo>/.claude/worktrees/$SLUG
REASON="claude-skill:<skill> ticket:<id> branch:<branch> started:$(date +%F) session:<session-id>"   # session id as in artifact-protocol › Claim › owner marker
git -C <repo> worktree prune
EXCLUDE="$(git -C <repo> rev-parse --path-format=absolute --git-common-dir)/info/exclude"   # absolute: a relative .git would resolve against the session cwd, i.e. the wrong repo
git -C <repo> check-ignore -q .claude/worktrees/probe || echo '.claude/worktrees/' >> "$EXCLUDE"   # idempotent: skipped when any rule already ignores the path
git -C <repo> worktree add --lock --reason "$REASON" --no-track -b <branch> "$DIR" <base>
```

The exclude entry is local and never committed; it keeps the directory out of `git status` and the host's own `Grep` tool (`rg` also skips the hidden `.claude/` directory by default). `--no-track` matters: without it a branch created from `origin/<default>` would report that remote branch as its upstream, and *Remove*'s "nothing unpushed" check would compare against the wrong ref. The lock reason is what `git-worktrees` › *The `[worktree-context]` Block*, *Crash recovery*, and `~/.terminal/claude/statusline.sh` read (the statusline matches `session:$session ` to show `wt→<name>`; omitting `session:<session-id>` or using freeform text causes it to report `no-wt`). Never omit `session:<session-id>` or use a freeform reason. Emit the `[worktree-context]` with `mode=workspace`.

## Hydrate

A worktree is a fresh checkout: ignored files and dependencies are absent.

1. Copy each file on the project's **Worktree include list** ([project-profile.md](../project-profile.md) › *Shared fields*, answered by the base profile; typical entries: `appsettings.local.json`, `.env.local`, local secrets) from `main-checkout` into `repo-root` — a read of the main checkout, never a write. Report what was copied; say which listed files did not exist.
2. Run the project's **Dependency hydration** commands inside `repo-root` from the base profile (*Shared fields*; e.g. `npm ci` in the package directory; .NET restores on first build). Without a base profile, derive them from the lockfiles present. Dependency symlinking is off unless the base profile enables it.
3. Do **not** copy `.claude/settings.local.json` or other host state; it is not needed to build or test.

## Work

- Every git command is `git -C <repo-root>`; every file read or edit uses absolute paths under `repo-root`.
- Every sub-agent brief carries the block and the sentence *"Read-only; work only under `repo-root`; never touch `main-checkout`; report paths as `workspace-path` + relative path."*
- Artifacts and chat use `workspace-path` + relative path, never the worktree path.
- Workspace-wide searches (`rg`, `grep -r`, `find`) add `-g '!**/.claude/worktrees/**'` (or the equivalent `--exclude-dir`) so the worktree's copies do not count as consumers.
- A code-intelligence index covers the main checkout: navigate there, cite from the worktree.

## Verify

Run the project's verify commands inside `repo-root`. First check for parallel runs:

```bash
git -C <repo> worktree list --porcelain | grep -c '^locked claude-skill:'
```

If another `claude-skill:` worktree of the same repo is active, run **targeted suites only** and say why: dev-server ports, a local API port and a local database (the base profile's **Shared local services**, [project-profile.md](../project-profile.md) › *Shared fields*) are shared between worktrees, so concurrent full suites collide and flake.

## Land

Commits, `git -C <repo-root> push -u origin <branch>` and PR creation all run inside `repo-root`, behind the calling skill's gates (plan gate, ship gate). Nothing here lifts a gate.

## Remove

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

## Hand-off line (mandatory in chat and in any walkthrough)

State, per repo: which branch holds the work; that the user's checkout is unchanged and on `<its branch>`; whether the worktree was removed or kept (and why); and how to see the work — `git -C <repo> checkout <branch>` after stashing their own changes, or, while the worktree is kept, open `<dir>` directly (`EnterWorktree path:<dir>` in Claude Code). Remind that `/manual-testing` tests what is on disk, so manual tests run from the kept worktree or after the checkout.

## Crash recovery

```bash
git -C <repo> worktree list --porcelain      # paths, HEADs, 'locked <reason>' lines
git -C <repo> worktree prune                 # drops admin entries whose directory is gone
ls <repo>/.claude/worktrees/                 # directories with no admin entry are orphans — list them, never delete silently
```

A locked `claude-skill:` worktree from an earlier session is reported to the user with its reason; it is never removed as a side effect of a new run.
