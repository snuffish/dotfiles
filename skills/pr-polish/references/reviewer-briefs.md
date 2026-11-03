# pr-polish reviewer briefs

On-demand reference for [`../SKILL.md`](../SKILL.md) › _Step 2: Fan out four reviewers_. Send all four in one message. Fill `<…>` from Step 1.

## Shared preamble (prepend to every brief)

```text
Read-only. Make no file edits, commits, worktrees, or outward writes. Cite every claim as `path:line`.
Repo: <repo-root> (the user's checkout; include uncommitted changes). Branch <branch> vs <base>, merge base <merge-base>.
Files in scope: <one path per line>. Read the diff with `git diff <merge-base> -- <files>`; read untracked files whole.
Loaded profiles and rulebooks: <list>. Follow them over general habits.
Report only problems you can point at in the changed lines or code they call. No style nits the formatter fixes.
Return ONLY a JSON array (no prose, no code fence), each element:
{"file": "<repo-relative path>", "line": <int>, "severity": "critical|important|minor",
 "issue": "<one sentence>", "proposed_fix": "<concrete edit, naming the symbol>", "confidence": "high|medium|low"}
Use "high" only when the fix is local, mechanical and provably correct from the code. Return [] if nothing holds up.
```

## (A) Correctness

```text
Lens: logic bugs, wrong conditions and off-by-one, null and nullable-annotation handling, missing usings/imports,
async misuse (unawaited tasks, sync-over-async), and EF Core queries that will not translate to SQL or evaluate
client-side (method calls inside Where/Select on IQueryable, unsupported string/date functions). For each EF finding,
name the query's entry point and the expression that fails translation.
```

## (B) Data safety

```text
Lens: every migration in <migrations>. For each, read Up AND Down: does Down restore schema and data Up changed?
Flag dropped/renamed columns or tables without a data copy, NOT NULL added without default or backfill, type
narrowing, unbatched UPDATE/DELETE on large tables, lost temporal/history tables or history rows, and any operation
that cannot be reversed. Also check model snapshot vs migration consistency. Proposed fixes to migrations are never "high".
```

## (C) Simplifier

```text
Lens: the four angles of /simplify-branch › Step 3 (Reuse, Simplify, Efficiency, Altitude), restricted to duplication
and dead code: new code that repeats an existing helper (name it, with path:line), copy-pasted blocks within the
branch, unused members/parameters/usings left behind, test-only flags in production code. Do not propose renames or
restructurings beyond removing the duplicate.
```

## (D) Conventions

```text
Lens: compliance with the repo's ADRs (<adr dirs from the profile or rulebook>), rulebook naming rules, and the
repo's test patterns (base classes, factory helpers, required 401/403 or minimum-coverage tests, test naming).
Every finding cites both the violated rule (file:line of the ADR/rulebook) and the code line.
```
