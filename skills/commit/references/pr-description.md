# commit: the PR's stack and its generated description block

Read from `commit` Step 7 when the branch has exactly one open PR. Read the `outward-writes` Module first (path in `commit` › *Modules*) unless it is already in context.

1. **Find the stack:** take the PR's target branch `TGT` (strip `refs/heads/` per `pr-host` › *Branch names & Diff base*) and the default branch `DEF` (`git -C <repo-root> symbolic-ref --short refs/remotes/origin/HEAD`, minus `origin/`). Then `git -C <repo-root> fetch origin "$TGT" "$DEF"`.
   - `TGT` = `DEF` → not stacked.
   - `TGT` ≠ `DEF` → stacked on `TGT`. Resolve `TGT`'s own open PR the same way and repeat until a target is `DEF` (stop after 5 levels), giving the chain, e.g. `this !B → feature/x !A → main`.
2. **Warn when the base is behind main** (stacked only): `git -C <repo-root> rev-list --count origin/$TGT..origin/$DEF`. A count above 0 → `⚠️ <TGT> is <n> commits behind <DEF>`, and suggest rebasing the base first. Never rebase or merge here.
3. **Regenerate the description from the commits:**
   - Read the commits the PR adds: `git -C <repo-root> log --reverse --format='%h %s%n%b' origin/$TGT..HEAD`, plus `git -C <repo-root> diff --stat origin/$TGT...HEAD` to check each claim against what changed.
   - Read the current description first and save it to `<scratchpad>/pr-<id>/previous.md` so it can be restored (`pr-desc` › *Apply*, item 2). On Azure DevOps: `az repos pr show --id <id> --org <org-url> --query description -o tsv > <scratchpad>/pr-<id>/previous.md`. Continue only when the command exits 0; a failed read leaves an empty file.
   - **Rewrite only the generated block.** The text between `<!-- commit:auto:start -->` and `<!-- commit:auto:end -->` belongs to this skill. Everything outside the markers is hand-written (screenshots, reviewer notes) and stays byte for byte.
     - One marker pair → replace only what is between the markers.
     - No markers (first run) → the new description is the generated block, followed by `## Manual` and the old description verbatim (leave the section out when the old description is empty).
     - No markers, but the old description follows the repo PR template (written by `/pr-desc`) → it is generated, not hand-written: edit the lines the commits made false in place, keep the rest, and add no markers. Appending it under `## Manual` would repeat every claim and break the 4000-character budget.
     - A lone marker or several pairs → do not write. Print the generated block and ask where it goes.
   - **Check the manual part for stale claims.** Byte for byte means unedited, not unchecked: read the manual part against the commits and the PR's live state (target branch, merged or abandoned PRs it names, behaviour, counts). List every line the change made false (`"<quote>"` → what is true now) in chat and in the output's `Stale` line. Fix them only on the user's go, as their own text; then they are no longer byte for byte, so say so.
   - Write the block **in English**, whatever the profile's *Report language*. Follow the repo PR template per `pr-desc` › *Step 4 — Compose the body and title* item 1. Group the commits by behaviour (one bullet per behaviour, not one per commit), and open the block with `Stacked on !<id>` when item 1 found a stack. Run `outward-writes` › *Voice pass* on the block only.
   - **4000-character budget for the whole description:** when it is over, shorten the generated block, never the manual part. When the manual part alone is over, do not write: print the block and say so.
   - Apply only the description per `pr-desc` › *Apply* item 3 (body from `<scratchpad>/pr-<id>/body.md`; on Azure DevOps always pass `--draft <isDraft>` from the read-back). Then read it back per `outward-writes` › *Read back*.
   - A denied or failed write → print the body and the exact command, then continue to the output.

Verify: the live PR description matches `<scratchpad>/pr-<id>/body.md`, everything outside the markers matches `previous.md`, and on Azure DevOps `isDraft` is unchanged.

Output lines, after the `PR:` line:

```markdown
- Stale: <n> manual-part lines contradict the change: "<quote>" → <now> (or: none)
- Stack: `<branch>` → `<TGT>` !<id> → `main` (or: not stacked)
- ⚠️ `<TGT>` is <n> commits behind `main`: rebase the base first (only when it is)
```
