# Phase 6a — PR Body via `/pr-summary`

Every PR body comes from invoking [`/pr-summary`](../../pr-summary/SKILL.md) once per repo **with the repo's `[worktree-context]` block** so its Step 0 and diff run against `repo-root` and never against the main checkout. Never hand-write a body "in its style". `/pr-summary` owns the repo's PR template, classification vocabulary, Key-impacts grouping, `---` footer (`Resolved:` first, `This PR relates to:` last), 4000-character budget, temp file, and cross-link fill-in.

Run it at two points:

| When | How | Why |
|------|-----|-----|
| At the ship gate, before anything is committed | **Preview mode** (`/pr-summary <base>`), never `update` | `update` commits and pushes in its Step 0, which would bypass the ship gate. Preview composes from the working-tree diff. Keep its block verbatim, with `!<other-pr-id>` placeholders for a paired change, and save it to a temp file. |
| After every paired PR exists | Replace the placeholder in the approved temp file with the other repo's real PR id. Apply it with `pr-summary` §5.2–5.3: show the current description, update from the file, then read it back to verify. | Preserves the text the user approved. Use `/pr-summary update` only if the diff changed after the gate, and present the new body before writing it. |

Create each PR from the preview's temp file, passed by path: `gh pr create --body-file`, `az repos pr create --description "$(cat …)"`, or `glab mr create --description-file`. Verification results, merge instructions and coordination prose go in the gate message and the walkthrough, never in the PR body.
