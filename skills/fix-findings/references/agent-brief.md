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
1. Implement ONLY finding <id>, with the smallest change that resolves it. Do not reformat unrelated code, rename things the finding does not name, or rewrite whole JSON or snapshot files: edit only the lines the fix needs. Touching a file outside "Expected files" is allowed only when the fix cannot compile without it; say why in the summary. Never change what an existing test asserts unless the finding says that test is wrong: when a test fails after your change, suspect the change first.
2. Work only under repo-root. Never touch main-checkout, other worktrees, or the network (no push, no PR, no tracker).
3. Build: <profile build command for the touched half>.
4. Test: run the tests that cover the touched code: <targeted test command(s) from the profile, with the filter for the touched classes or specs>. When a test command uses a shared local service (<the profile's Shared local services, e.g. the local SQL database or API>), run it as `flock <LOCK> <command>` so only one worktree uses the service at a time; when no flock is available, the lead has already made you the only such finding in the batch. Print the runner's discovered and executed test counts. If the filter discovers 0 tests, widen it to the touched project or spec file; a run with 0 executed tests is RED, never GREEN.
   - Run each test command in the foreground with the Bash tool's `timeout: 600000`, as one runner call with a combined filter for every touched class (TUnit: `--treenode-filter "/*/*/ClassA|ClassB/*"`), never one call per class. Never background it and wait with `sleep` or Monitor.
   - Take pass or fail from the runner's own exit code, never from the end of a pipe: `set -o pipefail`, or redirect to a log file and `echo exit=$?`. `<runner> | tail` exits 0 when the runner failed.
   - Before each build or test run, append `<HH:MM> <phase>` (for example `14:02 test DeleteUserEndpointTests`) to `<repo-root>/PROGRESS.log`, so the lead can answer "is it stuck?" without disturbing you. Never stage PROGRESS.log.
5. Environmental failure (SQL container dropped or unreachable, Testcontainers failed to start, Playwright browser missing, port in use, feed or network error, with no assertion failure in your tests): retry the same command ONCE. The first Playwright run in a freshly hydrated worktree can time out on its first locator while the dev server cold-compiles; that counts as environmental, so retry it once warm. A failure at the base commit proves nothing about your change unless that run was warm too. If it fails again the same way, stop and report BLOCKED_ENV with the log excerpt. Do not guess at a fix, change config, or install anything.
6. Commit your work on fix/finding-<id> whatever the outcome, staging files by explicit path (never `git add -A` or `.`). Message: "<repo commit prefix> Fix finding <id>: <one-line summary>". Never stage RESULT.json or PROGRESS.log.
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

## Group brief (`--group`)

Use this brief instead of the one above for a group work unit. The `RESULT.json` rules above still apply to the group as a whole, plus the `findings` list below.

```text
You fix a group of related review findings, one after another, in one isolated git worktree.

[worktree-context]
<the group's block, mode=workspace, branch=fix/finding-<group id>, base=<branch>@<BASE short-sha>>

Findings, in the order to fix them:
<for each finding: "Finding <id>:" followed by its full text, verbatim from the findings document, including its path:line references>

Expected files: <the group's union file set from the dependency graph>

Rules:
1. Fix the findings in the order given, each with the smallest change that resolves it. Rules 1–2 of the single-finding brief apply to every finding.
2. One commit per finding, staged by explicit path: "<repo commit prefix> Fix finding <id>: <one-line summary>". Build after each commit; a finding that breaks the build and that you cannot repair is reverted with `git revert --no-edit` and marked NOT_FIXED.
3. A finding you cannot fix (it does not hold at HEAD, needs a decision the text does not make, or needs a file outside "Expected files"): leave it uncommitted, mark it NOT_FIXED with the reason, and go on with the next one. A later finding that depends on it is NOT_FIXED too.
4. Apply every fix first: run no test suite until each finding is committed or marked NOT_FIXED (a compile check between commits is fine). Then run the build and the union of the group's targeted tests once, under rules 3–5 of the single-finding brief. That run sets the group's status.
   - Because the tests run last, a failing finding surfaces only after later findings were built on it. When the run traces a failure to one finding, `git revert --no-edit` its commit, mark it NOT_FIXED, and on a revert conflict keep what the later findings changed. Then build, and run the same union once more; that second run sets the status.
5. Write <repo-root>/RESULT.json (group schema below) as your last action, then reply with its content and nothing else.
```

## Group RESULT.json schema

```json
{
  "group": "g1",
  "status": "GREEN | RED | BLOCKED_ENV",
  "tests_run": 42,
  "tests_failed": 0,
  "files_changed": ["backend/source/…/Foo.cs"],
  "findings": [
    { "finding": "F3", "status": "FIXED", "commit": "<full sha>", "summary": "What changed." },
    { "finding": "F7", "status": "NOT_FIXED", "reason": "Needs a decision: restore the command or drop the section." }
  ],
  "summary": "One or two sentences for the group.",
  "commands": ["<exact build command>", "<exact test command>"],
  "log_excerpt": "Required for RED and BLOCKED_ENV."
}
```

- `GREEN` covers only the `FIXED` findings; a `NOT_FIXED` finding has no commit and never lands.
- `files_changed` is the union for the group (`git diff --name-only <BASE>..HEAD`).
