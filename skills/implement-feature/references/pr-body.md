# Phase 6a — PR Body via `/pr-desc`

Every PR body comes from invoking [`/pr-desc --dry-run`](../../pr-desc/SKILL.md) once per repo **with the repo's `[worktree-context]` block** so its diff runs against `repo-root` and never against the main checkout. Never hand-write a body "in its style". `/pr-desc` owns the repo's PR template, classification vocabulary, Key-impacts grouping, `---` footer (`Resolved:` first, `This PR relates to:` last), 4000-character budget, temp file, and cross-link fill-in.

Run it at two points:

| When | How | Why |
|------|-----|-----|
| At the ship gate, before anything is committed | **Dry run** (`/pr-desc --dry-run <base>`), never bare or `--draft` | Those offer to commit and push in their Step 1, which would bypass the ship gate. The dry run composes from the working-tree diff. Keep its block verbatim, with `!<other-pr-id>` placeholders for a paired change, and save it to a temp file. |
| After every paired PR exists | Replace the placeholder in the approved temp file with the other repo's real PR id. Apply it with `pr-desc` › *Apply* items 2–3: show the current description, update from the file, then read it back to verify. | Preserves the text the user approved. Use `/pr-desc --draft` only if the diff changed after the gate, so the new body is approved before it is written. |

Create each PR from the preview's temp file, passed by path: `gh pr create --body-file`, `az repos pr create --description "$(cat …)"`, or `glab mr create --description-file`. Verification results, merge instructions and coordination prose go in the gate message and the walkthrough, never in the PR body.
