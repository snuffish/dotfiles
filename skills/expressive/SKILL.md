---
name: expressive
description: "Rewrites imperative, nested or procedural code into declarative, intent-revealing code without changing behaviour: lookup tables for nested ternaries, domain predicates for complex booleans, guard clauses for nested conditionals, dispatch maps, declarative pipelines, and early-return subcomponents for `&&`-chained markup. Use for /expressive, \"make this more expressive\", \"use early returns instead\", \"flatten this\", \"clean up this conditional mess\", or a readability sweep of a PR. Not for removing dead code (/clean) or finding bugs (/code-review)."
---

# Skill: `/expressive` — Make Code Expressive & Intent-Revealing

Elevates code readability and maintainability by refactoring low-level, nested, or procedural constructs into clean, self-documenting, domain-expressive logic.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-expressive-<suffix>.md` when requested or providing an in-depth review (suffix from the target component or refactoring topic, e.g. `-ticket-category`, `-review-ratings`)
- `../_modules/git-worktrees.md`

- When asked directly on specific code lines (e.g. *"make lines 168–174 more expressive"*), propose and apply the clean refactoring directly to the file while explaining the transformation.

---

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Tidying one file: unused exports, dead variables, debug statements (nested ternaries only) | [`/clean`](../clean/SKILL.md) |
| Moving files, splitting modules, reshaping folders | [`/organize`](../organize/SKILL.md) |
| Duplication across files, or aligning with past decisions | [`/refine`](../refine/SKILL.md) / `priis-backend-dry` |

---

## 2. Transformation Patterns

Consult [Transformation Catalog](references/transformation-catalog.md) when refactoring complex conditionals, nested pipelines, or multi-branch switches:
- **Pattern 1:** Declarative Lookup Tables over Nested Ternary Ladders
- **Pattern 2:** Domain Predicates & Semantic Variables over Raw Booleans
- **Pattern 3:** Guard Clauses over the "Pyramid of Doom"
- **Pattern 4:** Strategy & Dispatch Maps over Giant `switch`/`if-else` Chains
- **Pattern 5:** Declarative Pipelines (`filter`/`map`/`reduce`) over Imperative Loops
- **Pattern 6:** Early-Return Subcomponents over Mutually Exclusive Sibling `&&` Markup
- **Pattern 7:** Prefer `type` over `interface` for shapes and domain models


## 3. Step-by-Step Refactoring Protocol

When prompted to make code more expressive:

1. **Identify the Core Decision or Intent**:
   - What business decision is this code actually making?
   - What are the dimensions or axes of variation (e.g. `mode`, `selectionKind`, `status`)?
2. **Select the Right Pattern**:
   - Nested ternaries / branching values → **Declarative Lookup Map (Pattern 1)**
   - Complex inline booleans → **Domain Predicates (Pattern 2)**
   - Nested `if` blocks, a precondition repeated inside branches, or a redundant last-case test on a closed set → **Guard Clauses (Pattern 3)**
   - Multi-branch action dispatching → **Strategy / Dispatch Map (Pattern 4)**
   - Manual loops with accumulators or flags → **Declarative Pipeline (Pattern 5)**
   - Mutually exclusive sibling `{cond && …}` blocks in markup → **Early-Return Subcomponent (Pattern 6)**
3. **Verify Type Safety & Exhaustiveness**:
   - In TypeScript, use `as const` or a typed `Record<Key, Value>` so the compiler enforces that all cases are covered. New types follow Pattern 7 (`type` over `interface`).
   - In C#, use exhaustive pattern-matching expressions (`status switch { ... }`).
4. **Preserve Semantic Equivalence**:
   - Ensure null/undefined handling, edge cases, and defaults match the original logic 100%.
   - Before collapsing sibling conditionals into early returns, confirm they are mutually exclusive. If two can be true at once, the original rendered or ran both and the refactor must too.
   - Keep test ids, aria labels, user-facing strings, and side-effect order unchanged. A readability refactor should produce no visible diff.

---

## 3b. Sweeping a PR or Branch

When asked to apply this skill across a whole change set rather than a snippet:

1. Diff against the merge base (`git diff --stat $(git merge-base HEAD <target>)`) to list the touched source files; skip generated files, tests, and styles unless asked.
2. Read each changed source file in full. The diff alone hides the surrounding structure you need to judge exclusivity and prop counts.
3. Apply the patterns, then run the project's formatter, linter, and type-checker on the edited files only.
4. Report in two lists: **what changed** (file, pattern, one line on why) and **what was deliberately left alone** (file, which pattern was considered, why it doesn't fit). The second list is as useful to the reader as the first.

---

## 4. Verification & Validation

After refactoring for expressiveness:
1. Run linter and type-checker (`npm run lint`, `tsc -b`, or `dotnet build`).
2. Run existing unit and regression test suites to guarantee zero behavioral regressions.
