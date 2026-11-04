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

## Full-suite gate

Record `PRE_LAND` (the `BASE` of the batch) before the first pick. After the last pick, run the project's full verify once in the landing tree: the repo's quality gate when it has one (for example a `priis-verify`-style Command), else the profile's full build and test commands. Check `git-worktrees` › _Workspace Lifecycle_ › _Verify_ first: when other `claude-skill:` worktrees of the repo are active, the shared local services force targeted suites, so say which suites ran.

On failure, do not push and do not reset. Report the failing tests, `git log --oneline $PRE_LAND..HEAD`, and which landed commits touch the failing code, then ask the user how to proceed. Only the user may decide to drop commits.

## Worktree removal

For each worktree of the batch, landed or not (every branch keeps its committed work per the brief's rule 6):

```bash
rm <DIR>/RESULT.json                       # its content is already in the report or handoff
git -C <DIR> status --porcelain            # must be empty; otherwise keep the worktree and report it
git -C <repo> worktree unlock <DIR>
git -C <repo> worktree remove <DIR>        # no --force
git -C <repo> worktree prune
```

Never delete the `fix/finding-<id>` branch. A worktree that is not clean stays locked and is listed in the report with its path and `git status` output.

## Handoff template

Write it with `artifact-protocol` naming (suffix: the PR branch slug plus `fix-findings`) at the workspace root:

````markdown
# Handoff: unlanded findings from <findings doc>

- PR branch: <branch> @ <short-sha> · Findings doc: <workspace-relative path>
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
