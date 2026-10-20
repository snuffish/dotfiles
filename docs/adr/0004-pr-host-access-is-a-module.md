# PR-host access is a Module

How a Command reads a pull request from its host (parsing a PR or work-item URL, choosing the organization URL, normalising branch names, resolving the PR from a branch, fetching the PR with its work items and acceptance criteria, fetching discussion threads, and handling a failed fetch) lives in one Module, `skills/_modules/pr-host.md`. Until now `/code-review`, `/pr-feedback-review`, `/pr-fix-pipeline`, `/pr-summary`, `/spec-verification` and `/pr-post-comments` each carried their own copy, and `/manual-testing` pulled in all of `/code-review` to reach one section.

The copies had drifted into contradictions. Three said the `https://<org>.visualstudio.com` organization URL "fails auth", and `create-ticket`'s script refused it, while another accepted it. Some used `--detect` without `--org`, so the result depended on the directory the command ran in. Some built `origin/<sourceRefName>` from a full `refs/heads/…` ref that never resolves. One read a thread's `rightFileStart` as a number when it is a `{line, offset}` object. A read check on 2026-10-20 showed both organization URL forms working with `az` 2.87.0, so the rule became "use the form the workspace already uses" instead of either ban.

## Considered Options

- **Keep the copies and fix each one.** Rejected: the drift came from having copies, and six fixes today would be six divergences tomorrow.
- **Let `/code-review` own the section and have the others point into it.** Rejected: `/manual-testing` already did this, and it made a test-plan Command load a 670-line review Command. A Command is not a contract other Commands should depend on.
- **Merge PR-host access into `pr-counterpart`.** Rejected: counterpart discovery is a classification problem with its own signals; reading one PR is a precondition for it, not part of it. `pr-counterpart` now links `pr-host` for the fetch.

## Consequences

- A Command that reads a PR lists `pr-host` in its `## Modules` and keeps only what is specific to it: which fields it needs, and what a fetched description means for its output.
- `<org-url>` is the placeholder for the organization URL everywhere. Its resolution order is defined once, in `pr-host` › *Organization URL*.
- `git-worktrees` › *Snapshot Lifecycle* refers to `pr-host` › *Branch names* for the `refs/heads/` rule.
- Posting stays in `/pr-post-comments`. The Module is read-only, so a read-only Command can depend on it without inheriting any write.
