# commit: fix what the skill-drift checker reported

Read from `commit` Step 2 when the checker printed a STALE or FAIL row, or an ORDER or MISPLACED section. The checker and its claims file are the row of the Step 2 table that matched.

1. **Diff guard, first:** before editing, copy each claim file you will edit to the scratchpad.
2. **STALE rows → fix now.** Re-extract each claim per `skill-drift` › *3. Re-extract claims after editing a skill*: update only that claim's `quote` / `source.line` (or drop and re-add it), with the script method that step's item 2 gives.
   - Touch only the stale claims: no `jq` or prettier pass over the file, no `--update-stale` (it also silently rewrites `count` claims).
   - When the repo's checker has `--format` (a claims directory), run it after the edits; the checker fails the run with ORDER otherwise.
3. **FAIL rows:** if the claim's `source.file` is in this change, triage and fix per `skill-drift` › *2. Triage a `FAIL`*. Otherwise leave it, name it in chat and in the output's `Left out` line, and continue.
4. **Diff guard, after** (and after `--format`): run `git -C <repo-root> diff --numstat -- <claim files touched>`: expect about 2 changed lines per fixed claim (more only for added or removed claims). Far more means it was reformatted: restore the copy and redo the edits by hand.
5. **Re-run the checker:** `0 stale`, no FAIL from this change and no ORDER or MISPLACED section, else stop and report the rows.
6. Claim edits (and any skill text fixes) belong to the change that caused them: stage them with it (`commit` Step 3).
