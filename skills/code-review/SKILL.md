---
name: code-review
description: Perform a structured, high-quality review of code changes, identifying potential bugs, design issues, and performance optimizations.
---

# Code Review Skill

Use this skill whenever the user requests a code review, feedback on a pull request, or a review of specific changes in the workspace.

---

## Step 1 — Determine Scope

Before reviewing any code, establish **what** to review:

| User says | What to diff |
|---|---|
| `staged` / `commit` | `git diff --staged` |
| `unstaged` / `working` | `git diff` |
| `branch` / `pr` / (default) | All commits on the current branch vs. its remote base |
| Specific file(s) | Read those files directly |
| `frontend` / `backend` | Branch diff, scoped to that sub-directory |

### Branch Discovery

When the scope is a branch diff, find the correct base automatically — **do not guess**:

```bash
# 1. Find the upstream tracking ref recorded for this branch
git rev-parse --abbrev-ref --symbolic-full-name @{u}   # e.g. origin/develop

# 2. Fall back: find the merge-base with common integration branches
git merge-base HEAD origin/develop
git merge-base HEAD origin/main

# 3. Build the diff using the merge-base (three-dot syntax):
git diff $(git merge-base HEAD <base>)...HEAD --name-only
```

Always use the **three-dot** form (`A...B`) so you see only the commits introduced by this branch, not divergent commits on the base.

---

## Step 2 — Gather Context

1. **List changed files** first (`--name-status` or `--name-only`) to understand the blast radius before reading code.
2. **For small diffs** (< ~200 lines): read the raw diff directly.
3. **For large diffs**: read each changed file in full with `view_file`. Do **not** rely solely on truncated diff output — you will miss essential context.
4. **Deleted / moved files**: for every deleted file, grep the codebase for remaining imports or references to ensure nothing is left dangling.
5. **Do not** run `npm ci`, `npm install`, `dotnet restore`, or any install/build commands unless the user explicitly requests it.
6. **Do not** run the linter or test suite unless the user explicitly requests it.
7. **Skip auto-generated files** (e.g., `routeTree.gen.ts`, `*.g.cs`) — they are machine-produced and not manually reviewable.

---

## Step 3 — Key Review Dimensions

Assess the changes across the following criteria:

- **Correctness & Edge Cases**: Logical bugs, off-by-one errors, boundary conditions, race conditions, null/undefined references, and unhandled exceptions. Ensure proper error-handling and logging are in place.
- **Conventions & Standards**: Match the design conventions of the target codebase:
  - **Backend (.NET)**: classes are `sealed` by default, EF Core reads use `AsNoTracking()`, endpoints follow FastEndpoints, validators use FluentValidation.
  - **Frontend (React)**: correct hook usage, Zod v4 imports, Radix UI styling patterns, RTK Query cache tagging, TanStack Router file-based routing.
- **Design & Maintainability (DRY)**: Duplicated code or types that should be consolidated, improper separation of concerns, unnecessary prop drilling.
- **Performance & Resource Management**: N+1 query patterns, missing `async/await`, excessive re-renders, missing `useCallback`/`useMemo` on stable references, potential memory leaks, resources not disposed of.
- **Security**: SQL injection, XSS, missing authorization checks, exposed secrets, insecure input validation.
- **Readability**: Variable and function names, comments explaining *why* not *what*, consistent formatting.

---

## Step 4 — Do Not Use Planning Mode

> **Never** produce an implementation plan for a code review. Go straight to gathering context and writing findings. Planning mode is for *code changes*, not reviews.

---

## Step 5 — Output Format

### Summary of Changes

Brief 1-3 sentence overview of what the changes accomplish and their architectural intent.

### Review Findings

Categorize findings by severity:

- **🔴 Critical / Defect** — Blocking bugs, security vulnerabilities, or logic errors that produce incorrect behavior.
- **🟡 Important / Design** — Architectural concerns, DRY violations, convention mismatches, or meaningful performance issues.
- **🟢 Minor / Polish** — Readability, naming, minor style suggestions.
- **💙 Praise** — Exceptionally clean code, clever solutions, or solid architectural choices worth highlighting.

For large reviews (many files), open with a **summary table** before detailed findings:

| # | Severity | File | Issue |
|---|---|---|---|
| 1 | 🔴 | `foo.ts` | Missing null check on `userId` |
| 2 | 🟡 | `bar.tsx` | Duplicated `IssueWriter` type |

### Actionable Suggestions

For every 🔴 and 🟡 finding, provide a concrete code block or diff showing the fix, with a brief rationale:

```diff
- public class UserService {
+ public sealed class UserService {
```

---

## Heuristics & Common Pitfalls

- If the changed files include a **schema or type definition**, search for all consumers to catch downstream type-safety issues.
- If a **context or hook** is changed, verify that all components using it still receive the correct contract.
- If **prop mutation** is spotted (directly modifying a prop object), flag it as 🟡 — use a local `const` copy instead.
- If the same **type is defined in more than one file**, flag it as a DRY violation.
