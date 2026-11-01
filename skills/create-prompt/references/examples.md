# Prompt Generation Examples

Reference examples demonstrating grounded, concise prompt outputs for `/create-prompt`.

---

## Example 1: Code Simplification & DRY

**Intent**: `/create-prompt I want to DRY and simplify this PR before commit`
**Context**: Branch `feature/22470_audit-log` in a repo with a backend DRY reference skill (`priis-backend-dry`) and a verify skill (`priis-verify`), with uncommitted backend changes.

````markdown
**Skill:** `/simplify` — its job is reuse and simplification of changed code; `/expressive` only reshapes conditionals.

```text
/simplify
Scope: feature/22470_audit-log vs merge-base origin/main, plus uncommitted changes (backend/ only).
Goal: remove duplication and needless complexity; behaviour unchanged.
Rules: apply priis-backend-dry patterns.
Done when: priis-verify passes; then stop — don't commit.
```

Next: paste it, or `/proceed` to run it here.
````

---

## Example 2: Vague Request Clarification

**Intent**: User sent `clean this up` with uncommitted changes on branch `main`.

````markdown
Your request can be read several ways; here is a sharper version.

**Skill:** `/clean` — removes dead code, unused exports, and stale comments in changed files without altering behavior.

```text
/clean path/to/changed_file.py
Scope: path/to/changed_file.py uncommitted changes
Goal: remove dead symbols and unused imports; preserve runtime behavior
Done when: ruff check passes; then stop — don't commit
```

**Open questions**

- Target files — recommend: run on the currently edited file first

Next: paste it, or `/proceed` to run it here.
````
