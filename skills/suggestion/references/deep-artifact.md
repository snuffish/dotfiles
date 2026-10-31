# `/suggestion deep` — Artifact Structure (`<prefix>-suggestion-<suffix>.md`)

Write `<prefix>-suggestion-<suffix>.md` at the **workspace root** via `artifact-protocol` › *Claim* containing, in order:

1. `# Suggestion: <short title>`
2. **Header** — a small table: question as framed (Step 1), goal (and whether it was assumed), constraints, repo(s), head SHA, mode (`deep`), related artifacts and prior decisions.
3. `## Recommendation` — the pick in two or three sentences (TL;DR).
4. `## Context & Prior Art` — precedent and conventions found, each with a clickable `path:line` link.
   - *(Optional)* `## Try This First` — a cheap, no-code diagnostic or experiment that would settle the question faster than building anything.
5. `## Approaches` — one `### <n>. <name>` subsection per candidate, numbered per Step 3, the recommended one as `### 1. <name> (Recommended)`, each with:
   - **What**: one or two sentences.
   - **Fits because / Precedent**: `path:line` link to the existing pattern or convention.
   - **Trade-offs**: effort, risk, reversibility, maintenance.
   - **Pick this when**: the condition that makes it the right choice.
   - **Impact**: files touched, contract/migration impact, tests affected, effort (T-shirt size).
6. `## Comparison` — a table across the dimensions that actually differ, one row per approach labelled `1. <name>`, `2. <name>` (only when there are three or more approaches; otherwise omit).
7. `## Decision & Rationale` — why the pick wins against the goal and constraints; what single fact would flip it.
8. `## What /proceed will do` — the _Proceed plan_: ordered steps, stop condition, verification, and what it will not do. None executed.
9. `## Open Questions / Unverified` — anything inferred rather than read. Omit when empty.

The artifact may run long but never pads.
