---
name: suggestion
description: "Answers an open \"how should I do X?\" with ranked, evidence-backed approaches and one clear recommendation, weighed against the project's actual code and conventions. Use when nothing is chosen yet: /suggestion, \"what's the best way to handle Y?\", \"which option would you pick?\", \"is there a better way to do this?\", \"give me some ideas for Z\". Bare /suggestion answers in chat; /suggestion deep researches cross-cutting decisions and writes `<prefix>-suggestion-<suffix>.md`. Not for stress-testing an approach already chosen (/what-am-I-missing) or checking stated facts against docs (/verify-assumptions). Read-only until /proceed."
---

# Skill: `/suggestion` — Recommended Approaches & Suggestions

Takes a question — technical, architectural, procedural or product-shaped — and answers it with a short, ranked set of **concrete suggestions**, each with its trade-offs, grounded in the real codebase and its conventions. Ends with one clear recommendation and the smallest next step to act on it.

Applicable to **any software project, language, framework or technology stack**.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-suggestion-<suffix>.md` at the **workspace root** in `/suggestion deep` only (suffix derived from the question, e.g. `-cache-invalidation-strategy`, `-pdf-export-library`); bare `/suggestion` writes no artifact. A deep follow-up in the same session updates that artifact in place; a follow-up in a new session writes the next counter (`artifact-protocol` › *Ownership*, *Claim*).

- **Read-only**: produces advice, never code changes. No edits, checkouts, installs, migrations or commits — for you and for any sub-agent. Implementation only after an explicit `/proceed` (see `core` › *The `/proceed` gate*), and then usually via [`/plan`](../plan/SKILL.md) or [`/implement-feature`](../implement-feature/SKILL.md).

---

## 1. When to Use

### Modes

| Command | Output | Research scope | Latency |
| :--- | :--- | :--- | :--- |
| **`/suggestion <question>`** (default — Simple & Fast) | Direct in-chat answer (no artifact written) | Focused: the files, symbols and conventions the question touches | **Fast** |
| **`/suggestion deep <question>`** (or "compare these thoroughly") | Workspace-root artifact + linked chat summary | Comprehensive: wider prior-art sweep, every affected layer, optional parallel sub-agents per candidate approach | **Thorough** |

There is no intermediate mode: a request for a written-up comparison or a document to share is `deep`. Suggest `deep` in chat (never switch silently) when a bare `/suggestion` turns out to span several repos or layers, needs a contract or migration decision, or when the ranking hinges on facts that require more than a handful of reads.

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Full ground-truth research with a confidence ledger *before* a planned change | [`/investigate`](../investigate/SKILL.md) |
| Understanding how existing code works, not choosing what to do | [`/explain`](../explain/SKILL.md) |
| Finding the single hidden risk in an approach already chosen | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |
| Something is already broken and needs a diagnosis | [`/problem`](../problem/SKILL.md) |
| Judging a drafted plan or a diff | [`/plan-review`](../plan-review/SKILL.md) · [`/code-review`](../code-review/SKILL.md) |
| Turning the chosen suggestion into an implementation plan | [`/plan`](../plan/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Frame the question

1. **Restate the question in one sentence** as a decision: *"Choose how to X, given Y, optimising for Z."* If the user did not state what they are optimising for (speed, simplicity, consistency, safety, reversibility), infer the most likely goal from context and **state the assumption** — do not block on it.
2. **Capture the constraints** the answer must respect: stack and versions, repo rulebooks (`CLAUDE.md`, `copilot-instructions.md`, `.agents/rules/`), registered project-scoped skills, cross-repo contracts, deadlines or scope limits the user mentioned, and anything the user has already ruled out.
3. **Classify the question type** — it changes what counts as evidence:
   - *Implementation* ("how do I build X here") → prior art in the codebase dominates.
   - *Design / architecture* ("where should X live", "which pattern") → conventions, blast radius and reversibility dominate.
   - *Tooling / library* ("which package", "which approach to testing") → what is already installed, maintained and used dominates; external research only if the codebase has no precedent.
   - *Process / workflow* ("how should we roll this out", "how do I review this") → team conventions and risk dominate.

### Step 2: Gather just enough context (read-only)

- **Prior art first.** Search the codebase for how the same or a similar problem is already solved (CodeGraph where indexed, otherwise grep/search). An existing pattern beats a theoretically better one unless it is demonstrably broken; name the precedent with `path:line`.
- **Conventions second.** Read the governing rulebook sections and any project-scoped skill that covers the area. A suggestion that violates a documented convention must say so explicitly and justify it, or be dropped.
- **Blast radius third.** For each candidate, note what it touches: contracts, generated files, migrations, shared enums, public APIs, tests that pin behaviour.
- **Prior decisions.** Check recent git history, open PRs, workspace-root artifacts (`<prefix>-investigation-*`, `<prefix>-implementation_plan-*`) and memory for an earlier decision on the same topic — do not re-litigate a settled choice without flagging that it is settled.
- **External research** (docs, changelogs, web) only when the codebase and rulebooks leave the question genuinely open, and only in `deep` mode or when a version/API fact must be verified.
- Keep bare mode to a **handful of reads**. If you cannot answer confidently within that budget, give the best-effort answer in chat, say what is unverified, and offer `deep`.

### Step 3: Enumerate and rank

1. **List 2–4 viable approaches.** Include the user's own draft approach if they gave one. Omit approaches that violate a hard constraint rather than listing them to reject — mention them in one line only if the user is likely to ask.
2. **For each approach record**: what it is (one sentence), where it fits the codebase (precedent / files it touches), the concrete trade-offs (effort, risk, reversibility, consistency with conventions, maintenance), and the conditions under which it is the right pick.
3. **Rank against the stated goal and constraints**, not against abstract best practice. Prefer: existing precedent > documented convention > simplest thing that meets the goal > reversible over irreversible > fewest cross-cutting touches.
4. **Pick one** and say why in a sentence. If two are genuinely tied, say what single fact would decide it and how to find out.
5. **Be honest about confidence.** Separate what you verified (`path:line`, doc section) from what you inferred. Never present a guess as a finding.

### Step 4 (deep mode only): Parallel candidate evaluation

When `deep` is requested and the candidates are independent, spawn **one read-only sub-agent per approach** (one message, parallel calls). Each prompt includes: the repo path(s), the framed question and constraints from Step 1, the precedent found in Step 2, the head SHA, and its candidate. Ask each to report: files it would touch, closest existing pattern, required contract or migration changes, the tests that would need to change, risks, and an effort estimate in T-shirt size — under 500 words, every claim with `path:line`.

Aggregate yourself. **Re-open every `path:line` a sub-agent cites** before it enters the artifact; drop or mark as unconfirmed anything you cannot see. Sub-agent output is evidence, not a verdict.

---

## 3. Output Format & Deliverables

### Bare `/suggestion` — in-chat answer

- **No artifact created**: do **not** write a suggestion file to disk.
- **Response structure**:
  - **Recommendation**: 1–2 sentences that answer the question directly — the pick, or a plain yes/no when the question is "is X suitable?".
  - **Why**: 2–4 concise bullets with the deciding facts and trade-offs, each grounded in a clickable `path:line` link or a named doc where one exists.
  - **Alternatives**: one line per other viable approach (at most two) saying when it would win instead. Omit when there is none.
  - **Next step**: one line — the first concrete action, and that `/proceed` acts on the pick.
- Name an assumed goal in the *Recommendation* line when the user did not state one. Offer `deep` in one line when the question outgrew bare mode.
- No header table, no comparison table, no section anchors. Keep the whole answer readable in under a minute.

### `/suggestion deep` — artifact

Write `<prefix>-suggestion-<suffix>.md` at the **workspace root** containing, in order:

1. `# Suggestion: <short title>`
2. **Header** — a small table: question as framed (Step 1), goal (and whether it was assumed), constraints, repo(s), head SHA, mode (`deep`), related artifacts and prior decisions.
3. `## Recommendation` — the pick in two or three sentences (TL;DR).
4. `## Context & Prior Art` — precedent and conventions found, each with a clickable `path:line` link.
5. `## Approaches` — one `###` subsection per candidate, recommended first, each with:
   - **What**: one or two sentences.
   - **Fits because / Precedent**: `path:line` link to the existing pattern or convention.
   - **Trade-offs**: effort, risk, reversibility, maintenance.
   - **Pick this when**: the condition that makes it the right choice.
   - **Impact**: files touched, contract/migration impact, tests affected, effort (T-shirt size).
6. `## Comparison` — a table across the dimensions that actually differ (only when there are three or more approaches; otherwise omit).
7. `## Decision & Rationale` — why the pick wins against the goal and constraints; what single fact would flip it.
8. `## Suggested Next Steps` — concrete, ordered, none executed (e.g. "run `/plan` with approach 1", "confirm X with the team").
9. `## Open Questions / Unverified` — anything inferred rather than read. Omit when empty.

A cheap, no-code diagnostic or experiment that would settle the question faster than building anything belongs in its own `## Try This First` section after *Context & Prior Art*.

The artifact may run long but never pads.

### `/suggestion deep` — chat response

Format all links per the **`artifact-protocol`** (workspace-relative in Claude Code, `file://` absolute in Antigravity). Get the anchor line numbers with `grep -n '^#\{1,3\} ' <artifact>` after the final write — re-run it if you edit the artifact again.

```markdown
📄 **[claude-<model>-suggestion-<suffix>.md](claude-<model>-suggestion-<suffix>.md)**

- 📄 [Recommendation](claude-<model>-suggestion-<suffix>.md#L<n>): [the pick in one sentence]
- 📄 [Approaches](claude-<model>-suggestion-<suffix>.md#L<n>): [the candidates, in ranked order]
- 📄 [Decision & Rationale](claude-<model>-suggestion-<suffix>.md#L<n>): [what would flip it]
- 📄 [Suggested Next Steps](claude-<model>-suggestion-<suffix>.md#L<n>): [the first step]
```

After the links, the chat adds only: the mode and head SHA, and the 2–3 facts most likely to change the user's mind. Do not repeat the document.

---

## 4. Verification & Validation

- **Self-check before answering**: every approach cites at least one real location or document where the codebase or docs have one; the recommendation respects every constraint from Step 1 or explicitly flags the violation; no approach is "recommended" that the user has already ruled out; the next step is actionable without further clarification.
- **Artifact check** (`deep` only): the artifact exists at the workspace root under the model-prefixed, suffixed name, and every chat anchor points at the heading it names. Bare mode wrote nothing.
- **Precedent check**: if the recommended approach has no precedent in the codebase while another candidate does, say so and justify the departure.
- **Read-only check**: confirm no files were modified (`git status` is unchanged), apart from the suggestion artifact at the workspace root in `deep` mode.
- **User validation**: the user confirms the goal assumption, picks an approach, and runs `/proceed` (or `/plan` / `/implement-feature`) to act on it. Until then, nothing is implemented.
