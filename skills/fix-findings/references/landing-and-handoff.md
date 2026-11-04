# Landing, worktree removal and handoff

On-demand reference for [`SKILL.md`](../SKILL.md) › _Step 4_ and _Step 5_.

## Cherry-pick

Land GREEN findings one at a time, in the topological order from the dependency graph (dependencies first, then by finding ID):

```bash
git -C <landing-tree> cherry-pick -x <commit from RESULT.json>
```

- `-x` records the source commit, which links the PR history to the `fix/finding-<id>` branch.
- On a conflict: `git -C <landing-tree> cherry-pick --abort`, mark the finding `CONFLICT`, and skip every finding that depends on it. Never resolve the conflict by hand inside this skill. The handoff repro covers it, and [`/resolve-conflicts`](../../resolve-conflicts/SKILL.md) can take it from there.
- An empty cherry-pick (the change already exists on the branch) is skipped with `git cherry-pick --skip` and reported as landed with the note "already present".

### Groups

A GREEN group (`--group`) lands all or nothing, because its tests ran only on the whole group, and it lands as **one commit**: the PR branch gets one commit per group, so nothing has to be squashed or force-pushed after the push. Stage the group's whole tested range, then commit once:

```bash
git -C <landing-tree> cherry-pick --no-commit $BASE..fix/finding-<group id>
git -C <landing-tree> diff --quiet --cached fix/finding-<group id> -- <group's files> && echo "matches the tested tree"
git -C <landing-tree> commit -F <message file>
```

- **Message:** `<repo commit prefix> <one-line summary of the group>`, a blank line, one bullet per `FIXED` finding (`<finding or thread id>: <its summary>`), then `Squashed from fix/finding-<group id> @ <short-sha>` (it replaces `-x`) and the attribution trailer. Thread replies cite this commit.
- **`NOT_FIXED` findings:** an attempt and its `git revert` (rule 2 of the group brief) cancel out inside the range, and a finding left uncommitted (rule 3) has no commit in it. Either way it goes to the handoff with the agent's reason.
- **Landing part of a group** (only on the user's say-so, after a RED group's failures are traced to some of its findings): `cherry-pick --no-commit` only the picked commits, in order, then commit once, and name the left-out findings in the handoff.
- **Conflict:** `git -C <landing-tree> cherry-pick --abort` returns the branch to where it was before the sequence started, with nothing staged. Mark every finding of the group `CONFLICT` and skip the groups that depend on it.
- **Already present:** when `git diff --cached --quiet` shows nothing staged after the pick, skip the commit and report the group as landed with the note "already present".

## Full-suite gate

Record `PRE_LAND` (the `BASE` of the batch) before the first pick. After the last pick, run the project's full verify once in the landing tree: the repo's quality gate when it has one (for example a `priis-verify`-style Command), else the profile's full build and test commands. Check `git-worktrees` › _Workspace Lifecycle_ › _Verify_ first: when other `claude-skill:` worktrees of the repo are active, the shared local services force targeted suites, so say which suites ran.

On failure, do not push and do not reset. Report the failing tests, `git log --oneline $PRE_LAND..HEAD`, and which landed commits touch the failing code, then ask the user how to proceed. Only the user may decide to drop commits.

## Worktree removal

For each worktree of the batch, landed or not (every branch keeps its committed work per the brief's rule 6):

```bash
rm -f <DIR>/RESULT.json <DIR>/PROGRESS.log # their content is already in the report or handoff
git -C <DIR> status --porcelain            # must be empty; otherwise keep the worktree and report it
git -C <repo> worktree unlock <DIR>
git -C <repo> worktree remove <DIR>        # no --force
git -C <repo> worktree prune
```

Never delete the `fix/finding-<id>` branch. A worktree that is not clean stays locked and is listed in the report with its path and `git status` output.

## Handoff template

Write it with `artifact-protocol` naming (suffix: the PR branch slug plus `fix-findings`) in the artifact dir:

````markdown
# Handoff: unlanded findings from <findings doc>

- PR branch: <branch> @ <short-sha> · Findings doc: <absolute path>
- Landed: <ids> · Not landed: <ids>

## <id>: <finding title> — RED | BLOCKED_ENV | CONFLICT

- **Branch:** fix/finding-<id> @ <short-sha> (based on <BASE short-sha>)
- **Summary:** <RESULT.json summary>
- **Failure:** <log_excerpt, or the conflicting paths>
- **Repro:**
  ```bash
  git -C <repo> worktree add <repo>/.claude/worktrees/finding-<id> fix/finding-<id>
  cd <repo>/.claude/worktrees/finding-<id>
  <hydration commands from the profile>
  <exact build command from RESULT.json>
  <exact test command from RESULT.json>
  ```
  For CONFLICT: `git -C <landing-tree> cherry-pick -x <commit>` reproduces the conflict on the current PR head.
- **Next step:** <fix the test / restart the SQL container and re-run / rebase onto the new head>
````
