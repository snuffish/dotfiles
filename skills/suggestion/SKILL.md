---
name: suggestion
description: 'Answers an open "how should I do X?" with ranked, evidence-backed approaches and one clear recommendation, weighed against the project''s actual code and conventions. Use when nothing is chosen yet: /suggestion, "what''s the best way to handle Y?", "which option would you pick?", "is there a better way to do this?", "give me some ideas for Z". Bare /suggestion answers in chat; /suggestion --deep researches cross-cutting decisions and writes `<prefix>-suggestion-<suffix>.md`. Read-only until /proceed.'
argument-hint: "[--deep] <question>"
---

# Skill: `/suggestion` — Recommended Approaches & Suggestions

Takes a question — technical, architectural, procedural or product-shaped — and answers it with a short, ranked set of **concrete suggestions**, each with its trade-offs, grounded in the real codebase and its conventions. Ends with one clear recommendation and the smallest next step to act on it.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-suggestion-<suffix>.md` at the **workspace root** in `/suggestion --deep` only (suffix derived from the question, e.g. `-cache-invalidation-strategy`, `-pdf-export-library`); bare `/suggestion` writes no artifact
- `../_modules/fan-out.md` (`--deep` mode)

On-demand references (`references/`):
- [`references/deep-artifact.md`](references/deep-artifact.md) — artifact structure for `/suggestion --deep`

---

## 1. When to Use

| Command                                                             | Output                                        | Research scope                                                                                                  | Latency      |
| :------------------------------------------------------------------ | :-------------------------------------------- | :-------------------------------------------------------------------------------------------------------------- | :----------- |
| **`/suggestion <question>`** (default — Simple & Fast)              | Direct in-chat answer (no artifact written)   | Focused: the files, symbols and conventions the question touches (handful of reads)                             | **Fast**     |
| **`/suggestion --deep <question>`** (or "compare these thoroughly") | Workspace-root artifact + linked chat summary | Comprehensive: wider prior-art sweep, every affected layer, optional parallel sub-agents per candidate approach | **Thorough** |

Suggest `--deep` in chat (never switch silently) when a bare `/suggestion` spans several repos or layers, needs a contract or migration decision, or requires more than a handful of reads.

### When _not_ to use — pick the right neighbor

| Situation                                                                     | Use instead                                                                           |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Full ground-truth research with a confidence ledger _before_ a planned change | [`/investigate`](../investigate/SKILL.md)                                             |
| Understanding how existing code works, not choosing what to do                | [`/explain`](../explain/SKILL.md)                                                     |
| Finding the single hidden risk in an approach already chosen                  | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md)                                 |
| Something is already broken and needs a diagnosis                             | [`/problem`](../problem/SKILL.md)                                                     |
| Judging a drafted plan or a diff                                              | [`/plan --review`](../plan/SKILL.md) · [`/code-review`](../code-review/SKILL.md) |
| Turning the chosen suggestion into an implementation plan                     | [`/plan`](../plan/SKILL.md)                                                           |

---

## 2. Core Protocol & Workflow

### Step 1: Frame the question

1. **Restate the question in one sentence** as a decision: _"Choose how to X, given Y, optimising for Z."_ If the user did not state what they are optimising for, infer the most likely goal from context and **state the assumption** — do not block on it.
2. **Capture the constraints**: stack and versions, repo rulebooks, registered project-scoped skills, cross-repo contracts, deadlines/scope limits, and anything the user already ruled out.
3. **Classify the question type**:
   - _Implementation_ ("how do I build X here") → prior art in the codebase dominates.
   - _Design / architecture_ ("where should X live", "which pattern") → conventions, blast radius and reversibility dominate.
   - _Tooling / library_ ("which package") → what is already installed, maintained and used dominates; external research only if no precedent exists.
   - _Process / workflow_ ("how should we roll this out") → team conventions and risk dominate.

### Step 2: Gather just enough context (read-only)

- **Prior art first** (`core` › *Codebase investigation* › *Navigation*): an existing pattern beats a theoretically better one unless demonstrably broken; cite the precedent with `path:line`.
- **Conventions second**: read governing rulebook sections and project-scoped skills (`core` › *Precedence*). Flag and justify any departure.
- **Blast radius & prior decisions**: note touched contracts/migrations/enums/tests, and check recent git history, open PRs, workspace-root artifacts and memory (`core` › *Codebase investigation* › *Historical decisions*).
- **External research**: only in `--deep` mode or when a version/API fact must be verified.

### Step 3: Enumerate and rank

1. **List 2–4 viable approaches** (include the user's draft approach if given; omit approaches that violate a hard constraint).
2. **For each approach record**: what it is (one sentence), precedent / files touched, concrete trade-offs (effort, risk, reversibility, consistency, maintenance), and when it is the right pick.
3. **Rank against the stated goal and constraints** (existing precedent > documented convention > simplest > reversible > fewest cross-cutting touches).
4. **Number them in ranked order**, the pick as **1**. Keep numbers stable for the rest of the session (dropped approaches leave a gap; nothing else in the answer uses numbers).
5. **Pick one** and say why in a sentence (or state the single deciding fact if two are tied). Separate verified facts (`path:line`) from inferences.

### Step 4 (--deep mode only): Parallel candidate evaluation

When `--deep` is requested and candidates are independent, spawn one read-only sub-agent per approach per `fan-out` (passing repo path(s), Step 1 framing/constraints, Step 2 precedent, head SHA, and candidate; returning touched files, closest pattern, contract/migration/test changes, risks, and T-shirt effort with `path:line`). Aggregate and re-open every cited `path:line` yourself (`fan-out` › *Aggregation*).

---

## 3. Output Format & Deliverables

### Bare `/suggestion` — in-chat answer

- **Recommendation**: 1–2 sentences naming the pick (`**1. <name>**`, plus assumed goal if inferred), or plain yes/no.
- **Why**: 2–4 concise bullets grounded in clickable `path:line` links or named docs.
- **Options**: numbered list (`1. **<name>** (recommended): <one line>`, `2. **<name>**: <when it would win instead>`, up to 4).
- **What `/proceed` will do (option 1)**: the _Proceed plan_ below.
- **Next step**: the _Next step_ line below.

### The Proceed plan & Next step route

Both modes end with the _Proceed plan_ for option 1:
- **3–7 lettered steps** (`- **a.** …`, `- **b.** …`) on named files, commands, or scripts (>7 steps → make step a "draft the plan with `/plan`").
- **Measure before changing** when the gap is a hypothesis, naming the **stop condition**.
- **How it is verified** (command/test and bar) and **What it will not do** (outward-facing actions per `core` › _The `/proceed` gate_).

Choose the closing **Next step** line per `core` › *Golden invariants* › *Planning mode first* (where the _Direct_ route is the single-repo, ≤7-step, no-contract/migration exception):

| Route          | When                                                                                                                  | Line                                                                                                                                                            |
| -------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Direct**     | ≤7 reversible steps, single repo, no contract/schema/migration change, verification named                             | `**Next step:** /proceed to run option 1's steps directly, /proceed <n> to act on option <n> instead, or /plan <suffix> if you want a written plan first.`      |
| **Plan first** | >7 steps, cross-repo, contract/migration changes, or an open question the steps depend on                             | `**Next step:** /plan <suffix> to turn option 1 into an implementation plan (/proceed does the same: it drafts the plan first; /proceed <n> picks option <n>).` |

### `/suggestion --deep` — artifact & chat response

Write `<prefix>-suggestion-<suffix>.md` at the **workspace root** using [`references/deep-artifact.md`](references/deep-artifact.md). In chat, render the `artifact-protocol` › _Chat link block_ linking `Recommendation`, `Approaches`, `Decision & Rationale`, and `What /proceed will do` (with a one-line summary on each), followed by the mode and head SHA, the 2–3 deciding facts, and the _Next step_ line.

---

## 4. Verification & Validation

- Every approach cites real `path:line` precedent or justifies its absence; approaches are numbered with the pick as 1 (stable across the session) and steps use letters (`a.`–`g.`).
- The _Proceed plan_ names its verification, stop condition, and excluded outward-facing actions, and the _Next step_ line matches the _Direct_ vs _Plan first_ criteria.
- `git status` is unchanged (apart from `<prefix>-suggestion-<suffix>.md` in `--deep` mode).
