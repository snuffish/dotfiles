---
name: pr-summary
description: Generate standardized, high-quality pull request summaries from the changes in any repository.
---

# PR Summary Generator Skill

Use this skill whenever the user requests a pull request (PR) summary, PR description, or commit log summary for changes made in the workspace.

## Guidelines for Generating PR Summaries

### 1. Information Gathering

- Determine what changed. Prefer comparing against the repository's base branch (e.g. `git diff <base>...HEAD`, where `<base>` is typically `main`, `master`, or `develop`). Fall back to `git diff` / `git diff --staged` for uncommitted work, or `git log <base>..HEAD` to review the commit history.
- Inspect the actual modified files when the diff is large or ambiguous — do not rely on commit messages alone.
- Identify the core objective: Is it a new feature, a bug fix, performance optimization, refactoring, dependency update, test coverage, or documentation?
- Capture any linked issue or ticket reference if one is present in the branch name, commits, or that the user provides — include it in the summary when available.

### 2. Output Format

Always format the output strictly using the following Markdown template:

```markdown
#### PR Classification

<!-- Concise classification. Example: "New feature, refactoring, and bundle optimization" or "Bugfix and regression testing" -->

#### PR Summary

<!-- A high-level description of the purpose, context, and overall solution. Keep it to 2-3 sentences. -->

**Key impacts:**

- `<impact1>`: Concise description of the first key change or benefit
- `<impact2>`: Concise description of the second key change or benefit
- `<impact3>`: Concise description of the third key change or benefit

#### Bug description

<!-- Only include this section if the PR fixes a bug. Detail what the bug was, why it happened, and how it was resolved. Remove this section completely if not applicable. -->
```

### 3. Style and Tone

- Write clearly and professionally, in a way that suits any codebase or stack.
- Be concise but specific: avoid vague phrases like "updated code" or "fixed things"; instead, state what was done, e.g. "Extracted a shared context helper to coordinate selection state across components" or "Added retry-with-backoff to the upload client".
- Match the project's conventions where they are evident (language, terminology, and any issue/ticket reference style), but never assume project-specific details that are not present in the changes.
- Number the key impacts to the number that fits the change — typically 2 to 5 bullets. Do not pad with filler.
- Remove the `#### Bug description` section entirely if the changes did not address a bug.
- **Markdown Fenced Code Block**: Always wrap the generated PR summary output within a fenced markdown block (i.e. ` ```markdown ... ``` `) so the user receives a raw, easily copy-pasteable markdown/md response.
