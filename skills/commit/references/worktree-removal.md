# commit: remove a finished worktree

Read from `commit` Step 8 when the commit was pushed from a linked worktree that this session's working directory is not inside. `<wt>` is `../wt-close-all/scripts/wt-close-all.sh` in this skill's real folder.

Run `<wt> rm none <repo-root>`. `none` matches no session, so every running session counts as live, this one included: a tree that a `/proceed` or `/wt` run owns stays for that run's own *Remove* step. When that run is this session (its id is the `session:` field of the tree's lock reason), run `<wt> rm <this session's id> <repo-root>` instead, so its own lock doesn't read as live. `wt-rm` removes the tree only when `wt-status` classes it `safe` and keeps its branch; a `kept` line names the reason (`keep:live`, `keep:dirty`, `keep:include`), so report it and leave the tree.

Verify: `git -C <main checkout> worktree list` no longer lists a removed `<repo-root>`.
