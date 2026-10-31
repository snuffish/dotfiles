# Default PR Body Template & Composition Rules

On-demand reference for [SKILL.md](../SKILL.md) › *Step 3 — Compose the PR body*. When the repo defines its own PR template (`docs/pull_request_template.md`, `.github/pull_request_template.md`), use the repo's template structure instead.

---

## Default Structure

```markdown
#### PR Classification

<!-- Concise classification. Examples: "New feature and code cleanup", "New content and validation change", "Bug fix and regression test", "Refactoring and performance" -->

#### PR Summary

<!-- 2–3 sentences: what changed, why it changed, and what problem it solves. Be specific — avoid vague phrases like "updated code" or "fixed things". -->

**Key impacts:**

- `<change or behaviour>`: What the change does and why it matters
- `<change or behaviour>`: What the change does and why it matters
<!-- 2–5 bullets. Label each by the change/behaviour it introduces; a file name only when that file is itself one cohesive change. Group edits across files under one conceptual bullet. -->

#### Bug description

<!-- Include whenever the PR actually fixes a bug — i.e. the classification includes "Bug fix"/"Hotfix" — regardless of branch prefix. Explain what the bug was, why it happened, and how it was resolved. Omit entirely when nothing incorrect is being corrected. -->
```

---

## Composition Rules

- **PR Classification**: one concise line containing *only* the classification term(s), comma-separated (never append `(work item #xxxx)` here). Vocabulary:
  - **New feature** — genuinely new user-facing capability, workflow, endpoint, or screen.
  - **New content** — additional values inside an *existing* mechanism (new enum members, dropdown options, selectable reasons, seed/reference data, labels, config entries). Extending an existing feature's options is **New content**, never **New feature**.
  - **Bug fix / Hotfix** — corrects incorrect behaviour (requires *Bug description* section).
  - **Refactoring** — restructures code with no behaviour change.
  - **Performance** — makes existing behaviour faster or lighter.
  - **Validation change** — adds, tightens, or relaxes input rules.
  - **Dependency update**, **Test coverage**, **Documentation**, **Code cleanup**.
- **PR Summary**: 2–3 sentences maximum stating *what*, *why*, and *impact*. Do not mention a paired PR in prose when the footer relation link (`This PR relates to: !<id>`) carries it.
- **Key impacts**: 2–5 bullets labelled by backticked behaviour name (e.g. `` `Closure under expired template` ``), grouping related file edits.
- **Bug description**: include whenever the classification includes **Bug fix** or **Hotfix** (regardless of branch prefix); omit entirely when no defect is fixed.
- **Footer trailer lines**: place platform trailer lines at the bottom after a `---` divider, with `Resolved: #<work-item-id>` first and `This PR relates to: !<counterpart-id>` last.
- **Length budget — max 4000 characters**: Azure DevOps hard-caps PR descriptions at 4000 characters. Measure with `wc -m` before printing or updating; if over 4000 characters, condense (tighten prose → collapse nested sub-bullets → merge overlapping bullets → shorten Bug description) without truncating mid-sentence or dropping footer trailers.
