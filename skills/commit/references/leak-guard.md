# commit: fix a `leak-guard` rejection

Read from `commit` Step 4 when the `pre-commit` hook rejects the commit and names a file that "adds a string from .leak-denylist or .env*". The hook does not name the string. Fix it without asking, since `gcai` runs headless and cannot answer.

1. Find the string: `git -C <repo-root> grep -n -o -i -F -f <repo-root>/.leak-denylist -- <file>` (never print the denylist itself).
2. Replace each hit with the placeholder the file already uses for that kind of value (e.g. `<ado-org-url>`), or `<redacted>` when it has none. Edit only the added lines, then re-stage the file.
3. Retry the commit once. Name the replaced values as `Changed: <file>: <kind> → <placeholder>` in the output, never the value.
4. Still rejected, or the value is the point of the change (a private-only file in a public repo): stop and report the file and the kind. Never `--no-verify`.
