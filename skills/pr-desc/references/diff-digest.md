# Diff digest brief (Step 3.3)

Used by `/pr-desc` Step 3.3 when the diff has about 200 lines or more. Spawn one digest sub-agent per area in one message (`fan-out` › _Speed fan-out_), at most 3.

## Brief

- **Read-only.** _"Read-only. Make no file edits, commits, worktrees, or outward writes. Cite every claim as `path:line`."_ (`fan-out` › _Brief contract_)
- **Diff:** the exact command for the area, `git -C <repo-root> diff "$BASE...HEAD" -- <area paths>`, with `<repo-root>` and `$BASE` already resolved in Step 2. The agent reads the changed files in full where the hunk alone does not show intent.
- **Context:** the work-item title and acceptance criteria when the lead already has them, and the project's domain terms from the profile's *Report language*.
- **Return:**
  - 5–10 impact bullets, each one change in this diff with its `path:line` (behaviour added, changed or removed; contract, schema, config or permission changes first).
  - One line naming the area's main change, for the title.
  - Risks: anything that needs a reviewer's attention (a migration, a breaking contract, a removed check), or `none`.
  - No pasted code, no commit-message paraphrase, no claims about code outside the diff.
