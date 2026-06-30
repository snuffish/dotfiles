---
name: pr-summary
description: Generate standardized, high-quality pull request summaries from the changes in any repository.
---

# PR Summary Generator Skill

Use this skill whenever the user requests a pull request (PR) summary, PR description, or commit log summary for changes made in the workspace.

> **Never** produce an implementation plan. Go straight to gathering context and writing the summary.

---

## Step 1 — Determine the diff

Find exactly what changed. Choose the appropriate strategy in order:

| Situation | Command |
|---|---|
| Branch / PR (default) | `git diff $(git merge-base HEAD <base>)...HEAD` |
| Staged only | `git diff --staged` |
| Unstaged only | `git diff` |
| Specific commit range | `git log <base>..HEAD --oneline` |

### Base branch discovery

When comparing a branch, find the correct base — **do not guess**:

```bash
# 1. Check the upstream tracking ref recorded for this branch
git rev-parse --abbrev-ref --symbolic-full-name @{u}   # e.g. origin/main

# 2. Fall back: find the merge-base against common integration branches
git merge-base HEAD origin/main
git merge-base HEAD origin/develop

# 3. Build the diff using three-dot syntax (only commits introduced by this branch):
git diff $(git merge-base HEAD <base>)...HEAD --name-only
```

Always use the **three-dot** form so you see only what this branch introduces, not divergent commits on the base.

---

## Step 2 — Gather context

1. **List changed files first** (`--name-status` or `--name-only`) to grasp the scope.
2. **For small diffs** (< ~200 lines): read the raw diff directly.
3. **For large diffs**: read each changed file in full with `view_file` — do **not** rely on truncated diff output.
4. **Identify the core objective**: new feature, bug fix, performance improvement, refactoring, dependency update, test coverage, or documentation.
5. **Look for a PR template**: if a file like `docs/pull_request_template.md` exists in the repo root, read it and use it as the structural basis for the output.
6. **Capture the work item / ticket reference**: extract it from the branch name (e.g. `feature/28048_my-feature` → `28048`), commit messages, or user input. Include it in the output.
7. **Skip auto-generated files** (e.g., `routeTree.gen.ts`, `*.g.cs`) — do not describe machine-produced changes as if they were hand-authored.

---

## Step 3 — Compose the PR body

Use the structure below. If the repo supplies its own PR template, honour that structure instead — do not invent a different shape.

```markdown
#### PR Classification

<!-- Concise classification. Examples: "New feature and code cleanup", "Bug fix and regression test", "Refactoring and performance" -->

#### PR Summary

<!-- 2–3 sentences: what changed, why it changed, and what problem it solves. Be specific — avoid vague phrases like "updated code" or "fixed things". -->

**Key impacts:**

- `<area or file>`: What changed and why it matters
- `<area or file>`: What changed and why it matters
<!-- 2–5 bullets. Do not pad with filler. Match the number to the actual scope of the change. -->

#### Bug description

<!-- Include ONLY for bug fix or hotfix branches. Explain what the bug was, why it happened, and how it was resolved. Remove this section entirely for all other PR types. -->

```

**Composition rules:**

- **PR Classification**: one concise line; comma-separate if the change spans multiple types.
- **PR Summary**: 2–3 sentences maximum; state *what*, *why*, and *impact*. Avoid filler.
- **Key impacts**: label each bullet with the area, component, or file using a backtick-wrapped label. 2–5 bullets is the normal range — do not pad. Each bullet should say something specific and non-obvious.
- **Bug description**: include only for `bugfix/` and `hotfix/` branches. **Remove the section entirely** for `feature/`, refactoring, or other PR types.
- **Language**: write in English unless the project clearly uses another language for PR descriptions.
- **Tone**: clear, professional, concise — written for a reviewer who knows the codebase but not the exact intent of this change.

---

## Step 4 — Output

Wrap the final PR body in a fenced markdown block so the user can copy-paste it directly:

````text
```markdown
<the complete PR body from Step 3>
```
````

Do **not** add extra commentary around the block unless the user asks a question. The output should be immediately paste-ready.

---

## Heuristics & Common Pitfalls

- **Do not summarise commit messages verbatim.** Read the actual diff and describe the intent, not the mechanics.
- **Do not fabricate details** not present in the diff (e.g., "this improves performance by 30%").
- **If the diff is ambiguous**, inspect the changed files directly rather than guessing from filenames alone.
- **Match the project's terminology**: if the codebase uses specific domain terms (e.g. "ticket", "suggestion", "matching"), use them in the summary rather than generic synonyms.
