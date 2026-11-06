# PR target

On-demand reference for [`SKILL.md`](../SKILL.md) when the target is a pull request (URL or `!<id>`). Resolve and read the PR with `pr-host`; everything here is read-only.

## 1. Pin the PR

1. Fetch the PR (`pr-host` › *Fetch the PR, its work items and acceptance criteria*): repo, source and target branch, status, author, auto-complete, and the **head SHA** (`lastMergeSourceCommit.commitId` on Azure DevOps, `headRefOid` on GitHub).
2. Fetch both branches (`pr-host` › *Branch names & Diff base*) and read the head SHA from a snapshot (`git-worktrees` › *Snapshot Lifecycle*). The **ref** is the head SHA; the **base** is `origin/<target>`.
3. List the changed files: `git -C <repo> diff --name-status origin/<target>...<head>`.
4. When auto-complete is set or the PR is completed, say so in the chat summary's first line.

Done when repo, head SHA, base, author and the changed-file list are written down.

## 2. Map changed files to targets

Give each changed file one kind. One artifact covers the whole PR, with suffix `pr<id>` (e.g. `-pr18952`) and findings grouped by target.

| Kind | Matches | Review as |
|---|---|---|
| Skill file | `<skills-dir>/<skill>/SKILL.md`, `references/*` | Target `<skill>`: every lens |
| Shared module | `_shared/*`, `_modules/*`, any file several skills load | Target itself. **Consumers** are `git grep -l -F '<file name>'` at the head; read each consumer's pointer and check the changed text still fits it |
| Rule or profile a skill loads | `.claude/rules/*`, profile files | Reference text of every skill that names it (`git grep -l -F '<file name>'`); lenses 3, 5, 7, 8 |
| Claims file | `skills-claims.json` or the profile's equivalent | Run the repo's drift script in the head snapshot; review each added or changed claim with lens 5 |
| Anything else | product code, config, pipelines | Out of scope: list them in the report and point at `/code-review` |

Done when every changed file has a kind and every target is named.

## 3. Review depth

- **Changed hunks** get every lens that applies to their kind.
- **Unchanged text** in a touched file gets lenses 5 and 7 only where the diff changes something it relies on.
- A problem that predates the PR is `later`, marked *pre-existing*; it does not block the PR.

## 4. PR checks

Run these alongside the lenses; findings carry source `new (pr)`.

- **Description vs diff.** Re-check every fact the PR description states (counts, "0 FAIL", cited commits with `git show --stat <sha>`, precedents, before/after behaviour) at the head. The description states intent; the diff states truth.
- **One home.** A new fact lives in one file: `git grep -n -F '<distinctive phrase>'` at the head finds it once (a pointer elsewhere is fine).
- **Claims coverage.** When the repo pins skill text with claims, each new factual sentence has a claim, and that claim would fail if the behaviour it describes changed.
- **Behaviour claims about tools.** A sentence stating how a CLI, API or git behaves is checked against its docs or a harmless local run; record which, or mark it *unverified*.

## 5. Inputs, change scope and evidence

- The PR's existing threads (`pr-host` › *Fetch discussion threads*) are inputs: open them in step 3, after the independent pass.
- Statuses are at the head SHA. **Latent** here means true at the head, wrong once the target branch's newer commits reach it (check `origin/<target>` when it moved after branch-off).
- **Change scope:** when the PR author is the git user, fixes may land on the PR branch with `/proceed`. Otherwise the fixes are review comments for `/pr-post-comments`, and a fix the user wants made goes on a new branch stacked on the PR, never onto the author's branch.
- Cite `path:line` at the head SHA, on a line the diff touches when one exists, so `/pr-post-comments` can anchor the comment there.
