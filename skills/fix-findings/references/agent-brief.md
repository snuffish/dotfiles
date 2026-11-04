# Sub-agent brief and RESULT.json

On-demand reference for [`SKILL.md`](../SKILL.md) › _Step 3_. Paste the brief once per finding, with every `<…>` filled. Spawn all briefs of a batch in one message.

## Brief

```text
You fix exactly one review finding in an isolated git worktree.

[worktree-context]
<the finding's block, mode=workspace, branch=fix/finding-<id>, base=<branch>@<BASE short-sha>>

Finding <id>:
<full finding text, verbatim from the findings document, including its path:line references>

Expected files: <file set from the dependency graph>

Rules:
1. Implement ONLY finding <id>, with the smallest change that resolves it. Do not reformat unrelated code, rename things the finding does not name, or rewrite whole JSON or snapshot files: edit only the lines the fix needs. Touching a file outside "Expected files" is allowed only when the fix cannot compile without it; say why in the summary.
2. Work only under repo-root. Never touch main-checkout, other worktrees, or the network (no push, no PR, no tracker).
3. Build: <profile build command for the touched half>.
4. Test: run the tests that cover the touched code: <targeted test command(s) from the profile, with the filter for the touched classes or specs>. When a test command uses a shared local service (<the profile's Shared local services, e.g. the local SQL database or API>), run it as `flock <LOCK> <command>` so only one worktree uses the service at a time; when no flock is available, the lead has already made you the only such finding in the batch. Print the runner's discovered and executed test counts. If the filter discovers 0 tests, widen it to the touched project or spec file; a run with 0 executed tests is RED, never GREEN.
5. Environmental failure (SQL container dropped or unreachable, Testcontainers failed to start, Playwright browser missing, port in use, feed or network error, with no assertion failure in your tests): retry the same command ONCE. If it fails again the same way, stop and report BLOCKED_ENV with the log excerpt. Do not guess at a fix, change config, or install anything.
6. Commit your work on fix/finding-<id> whatever the outcome, staging files by explicit path (never `git add -A` or `.`). Message: "<repo commit prefix> Fix finding <id>: <one-line summary>". Never stage RESULT.json.
7. Write <repo-root>/RESULT.json (schema below) as your last action, then reply with its content and nothing else.
```

## RESULT.json schema

```json
{
  "finding": "F3",
  "status": "GREEN | RED | BLOCKED_ENV",
  "tests_run": 14,
  "tests_failed": 0,
  "files_changed": ["backend/source/…/Foo.cs"],
  "summary": "One or two sentences: what changed and why it resolves the finding.",
  "commit": "<full sha on fix/finding-<id>>",
  "commands": ["<exact build command>", "<exact test command>"],
  "log_excerpt": "Required for RED and BLOCKED_ENV: the first failing assertion or the environment error, ≤ 40 lines."
}
```

- `finding`, `status`, `tests_run`, `tests_failed`, `files_changed` and `summary` are required. The lead adds nothing to the file and reads it as written.
- `GREEN` requires the build to pass, `tests_run > 0` and `tests_failed == 0`.
- `files_changed` lists repo-relative paths as committed (`git diff --name-only <BASE>..HEAD`).
