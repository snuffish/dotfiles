# commit: conclude a resolved merge

Read from `commit` Step 1 when `/commit` starts on a merge that is resolved but not concluded: `MERGE_HEAD` exists and `git -C <repo-root> diff --name-only --diff-filter=U` is empty (`status` says `All conflicts fixed but you are still merging`).

1. Run `resolve-conflicts` › *Step 5 — Verify the Merged Tree* on it first (the build, the tests the merge touched and the base profile's *Post-merge checks*), even when the conflicts were resolved by hand.
2. Conclude it yourself with `resolve-conflicts` › *Step 6 — Conclude* (the user's `/commit` is the request to commit).
3. Go to `commit` Step 6 (push).
