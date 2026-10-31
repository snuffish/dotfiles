# Code Review Snapshot & Scope Mechanics

On-demand reference for [SKILL.md](../SKILL.md) › *Step 1 — Determine Scope*.

---

## Snapshot Head Choice

Follow [git-worktrees-snapshot.md](../../_modules/references/git-worktrees-snapshot.md) (`<skill>=code-review`) for head resolution, creation in `<scratchpad>/code-review/<repo-dirname>/<ref-slug>@<short-sha>`, reading, path mapping back to `workspace-path`, and `--force` cleanup.

- Carry `<source-ref> @ <short-sha>` everywhere (Review Context, chat response, sub-agent briefs).
- Record the main checkout's branch and relation (`same commit`, `local ahead N / behind M`, or `on <other-branch> — PR branch not checked out`).
- For `working` / `staged` scopes, list untracked files (`git -C <repo> ls-files --others --exclude-standard`) under *Untracked, not in snapshot* and mark citations into them `(live, untracked)`.

## Pull-Request References & Counterpart PRs

1. **Resolve the PR**: parse the URL/ID or resolve from the current branch per [pr-host.md](../../_modules/pr-host.md) › *Parse a PR or work-item URL*, *Organization URL*, and *Resolve the PR from a branch*.
2. **Counterpart discovery**: run [pr-counterpart.md](../../_modules/pr-counterpart.md) › *Counterpart discovery* for every resolved PR:
   - **Found** → joins the scope automatically with its own snapshot, Spec source, Standards sources, and Review Context rows. Cross-repo contracts are checked against both snapshots.
   - **Found, excluded** → record in Review Context as **not reviewed**; flag any touched cross-repo contract as a finding because the other side was not checked.
   - **Expected but missing** → Spec finding (🟡, or 🔴 when runtime breaks without the other half).
   - **None** → record `single-repo change`. When checking a cross-repo contract against another repo in the workspace, read that repo from git objects at its default branch (`git -C <other> show <default>:<path>`, `git -C <other> grep -n '<symbol>' <default> -- <dir>`) and record `contract read at <default> @ <short-sha>`.
3. **Fetch PR & work items**: per `pr-host` › *Fetch the PR, its work items and acceptance criteria* (and *When a fetch fails* on error).
4. **Snapshot the PR head**: strip `refs/heads/` (`pr-host` › *Branch names & Diff base*), `git -C <repo> fetch origin "$SRC" "$TGT"`, and snapshot `origin/$SRC` (`git-worktrees-snapshot.md` › *Resolve the head and record its source ref — per repo*). Never check out or switch the main checkout.

## Diff Base & Trusting the Description

- **Diff base**: resolved per `pr-host` › *Branch names & Diff base* (PR target `origin/$TGT` when a PR exists, else `origin/HEAD` via `symbolic-ref` / `remote set-head origin --auto`; never `@{u}`; always three-dot `git -C "$SNAP_DIR" diff <base>...HEAD`).
- **The description states intent; the diff states truth**:
  - AC promises behavior absent from the diff → 🔴/🟡 *claimed but not implemented*.
  - Diff changes user-visible behavior absent from the description → flag as *scope creep / unannounced*.
  - Description describes an earlier revision → note as stale and follow the diff.
