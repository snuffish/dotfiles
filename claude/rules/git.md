# Commits, branches and PRs

## Commit workflow

- When the user asks to commit or push, commit immediately. Do not wait on test runs unless the user asks for them. The repo's documented format gate still runs first. If tests are pending, say so in one line and continue.
- Split unrelated changes into separate logical commits and push to the current branch's upstream.

## Reported defects

- Before formulating a fix plan for a reported defect, check recent commits on active PR branches (`git log -n 5 --oneline origin/main..HEAD`) to verify the defect is not already resolved upstream.

## Merges

- After merging a linked worktree's branch into its target (e.g. a `~/.terminal` branch into `main`) and pushing the target, remove the worktree with `~/.terminal/skills/wt-close-all/scripts/wt-close-all.sh rm <id> <dir>`, where `<id>` is this session's id when the tree's lock reason names it (`session:<id>`; with `none` its own run reads as live and the tree is kept as `keep:live`) and `none` otherwise, then delete the merged local branch with `git -C <main checkout> branch -d <branch>` (never `-D`). Skip both when this session's working directory is inside the tree. A `kept` line from `wt-rm` (another session uses it, dirty, a `.worktreeinclude` copy differs) leaves the tree and its branch; report the reason.

## Git / PR workflow

- Cut new PRs from `main` unless I name another base, even when we are currently on a feature branch. Exception: work that builds on someone else's open PR stacks on that PR's branch (see memory `stack-on-others-pr-branches`).
- When extracting or cherry-picking work into a standalone PR, take the latest version of the code, including later fix commits. Compare test counts before and after.
- To retarget a PR, use the method in memory `az-pr-update-drops-draft` (MCP `repo_pull_request_write` with `targetRefName`). Check memory before stating any az CLI command.
- After pushing to a branch with an open PR, update the PR description so it matches the actual commits.
