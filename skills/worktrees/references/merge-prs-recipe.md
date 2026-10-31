# Recipe: Merge PR X & Y in a Worktree

"Merge PR X & Y" defaults to **combining the PR heads on a local integration branch**, so they can be built and tested together. State this reading in the first chat line. Ask instead when the prompt points to one of the other readings below.

1. **Resolve each PR** through the host's CLI or MCP (`gh pr view <n> --json headRefName,baseRefName,headRepository`, `az repos pr show --id <n>`). Record the repo, source branch and target branch of each.
2. **Group by repo.**
   - PRs in different repos cannot be merged together. Give each repo its own worktree with its PRs, and say that nothing crosses the repo boundary.
   - PRs in one repo with different targets: ask which target is the base.
3. **Create the worktree** on `integrate/<x>-<y>` (or the convention's equivalent) from `origin/<target>`. Fetch every source branch first.
4. **Merge in the order given**, one at a time: `git -C <repo-root> merge --no-ff --no-edit origin/<source>`. A conflict goes to `resolve-conflicts` with the `[worktree-context]` block, and that skill concludes the merge.
5. **Verify** the combined result (*Verify*). Report what passes, and which PR each failure came from where `git log` shows it.
6. **Stop.** The integration branch stays local. Never push it, open a PR for it or complete either PR on the host unless the user asks.

## Other Readings

- **Merge PR Y's branch into PR X's:** workspace on X's existing source branch (`git-worktrees` › *Workspace Lifecycle* › *Base and branch*), then merge `origin/<Y source>`. Pushing it changes X's PR, so push only on an explicit ask.
- **Complete both PRs on the host:** no worktree (see `SKILL.md` › *When not to use*).
