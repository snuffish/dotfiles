---
name: investigate
description: Read-only research and discovery pass that builds the evidence base for a task before it is designed — maps the relevant code, finds the prior art worth copying, surfaces constraints and cross-layer contracts, weighs approach options, and separates verified fact from assumption. Writes an investigation artifact that /plan consumes. Triggered by /investigate or requests like "research this", "how does X work before we change it", "what would it take to add Y", "scope this out". Runs before /plan; never designs a plan and never modifies code.
---

# Skill: `/investigate` — Pre-Plan Research & Discovery

The reconnaissance pass that runs **before** `/plan`. It answers *"what is actually true in this codebase right now, and what are my real options?"* — and hands `/plan` an evidence base instead of a blank page.

A plan built on guesses fails during implementation. This skill exists to make sure that never happens: every claim it produces is either traced to a real line of code or explicitly labelled as an assumption.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **Target Artifact**: `<prefix>-investigation.md` at the **workspace root**.

---

## ⛔ Golden Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR DEVIATION:**
>
> 1. **STRICTLY READ-ONLY.** Never edit source files, scaffold code, run migrations, stage commits, or execute any state-mutating command. Investigation observes; it does not change. The only file this skill writes is its own artifact.
> 2. **DO NOT WRITE THE PLAN.** This skill produces findings, options and trade-offs — **not** phases, task checklists, or `<prefix>-implementation_plan.md`. Designing the solution is `/plan`'s job. Stopping short is the point, not a shortcoming.
> 3. **NO UNCITED CLAIMS.** Every statement of fact about the codebase carries a `path:line` citation. Anything not traced to real source is labelled **Inferred** or **Unknown** — never presented as fact.
> 4. **NO AUTO-PROCEED.** Never roll straight from investigation into planning or implementation. Hand off and stop; the user decides what runs next.

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/investigate` (bare or with a topic).
- The user asks to *"research this"*, *"scope this out"*, *"look into how X works before we touch it"*, *"what would it take to add Y?"*, *"where does Z live?"*, or *"is this even feasible?"*.
- A work item, ticket, or feature request has arrived and the shape of the change is not yet obvious.
- `/plan` was attempted but stalled on unknowns — investigate the unknowns, then re-plan.

### When *not* to use — pick the right neighbour

| Situation | Correct skill |
|---|---|
| Research the ground truth **before** a solution exists | **`/investigate`** (this skill) |
| A specific known symbol/comment/behaviour needs explaining | [`/explain`](../explain/SKILL.md) |
| The evidence is gathered; now design the change | [`/plan`](../plan/SKILL.md) |
| A concrete error, failing test, or regression needs diagnosing | [`/problem`](../problem/SKILL.md) |
| A plan already exists and needs a read-only audit | [`/review`](../review/SKILL.md) |
| A design looks finished and needs a blind-spot sweep | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 0 — Frame the Question (do this first, in writing)

Before opening a single file, pin down:

1. **The goal** — restate the user's request in one sentence, in your own words.
2. **The open questions** — the 3–7 specific questions that must be answered before a sound plan is possible. These become the artifact's spine.
3. **The done condition** — what makes this investigation complete. Without one, research sprawls.

If the goal is genuinely ambiguous in a way that changes *what you would research*, ask once, up front — then proceed. Do not ask about details you could resolve by reading the code.

### Step 1 — Orient: Rulebooks, Scope & Prior Decisions

1. **Read the workspace rulebooks first.** `CLAUDE.md` / `GEMINI.md` / `.agents/rules/` at the workspace root and in each subproject. They encode constraints (cross-repo contracts, conventions, forbidden patterns) that silently invalidate otherwise-reasonable designs.
2. **Load the relevant project-scoped skills** for the side(s) you are entering, per the precedence model in [core §5](../core/SKILL.md). Their conventions define what "correct" means here.
3. **Determine repo topology** — which repository/repositories the change touches. A change spanning two repos is a coordinated change, and that fact belongs in the findings.
4. **Recover prior decisions** — `git log`, `git log -p <path>`, and past transcripts (`~/.claude/projects/` under Claude Code, `<appDataDir>/brain/` under Antigravity). A question the team already settled should not be reopened as an "option".
5. **Read the ticket if there is one** — work item / issue description and acceptance criteria are primary sources.

### Step 2 — Find the Prior Art (the highest-leverage step)

In a codebase with established conventions, the best design is usually *the one already used for the nearest analogous feature*.

- Locate the **closest existing implementation** of the same shape (a sibling endpoint, an existing form, a comparable job, a parallel migration).
- Read it end-to-end, across every layer it touches.
- Record it in the artifact as the **reference implementation**, with file links — this is what `/plan` will pattern-match against.
- Note where the codebase is **inconsistent** (two competing patterns for the same thing). Which one is newer? Which does the rulebook endorse? An unflagged inconsistency becomes an arbitrary coin-flip during implementation.

### Step 3 — Trace the Real Code (no guesswork)

Follow the [core §4 investigation protocol](../core/SKILL.md). Never infer a signature, type, or behaviour from a name.

- **Enclosing scope over isolated lines** — read the whole method, class, component, or lifecycle.
- **Cross-layer mapping** — for each touched concern, walk the full path:
  - Backend ↔ Frontend: DTO shape, route path, serialization, client hooks/generated types.
  - Domain ↔ Persistence: entity mappings, migrations, keys, constraints, seeded data.
  - Runtime ↔ Config: feature flags, environment settings, DI registration, background schedules.
- **Map the blast radius** — enumerate every call site and consumer of what would change. Grep for the symbol; don't assume the list.
- **Locate the tests** — which existing tests cover this area, and what do they assert? Their absence is itself a finding.

### Step 4 — Surface Constraints & Contracts

Explicitly hunt for the things that turn a small change into a large one:

| Constraint class | What to look for |
|---|---|
| **Cross-repo / cross-service contracts** | Shared enums or IDs coupled by value, fixed URLs, generated clients, message schemas, anything the rulebooks flag as coupled |
| **Data & migrations** | Schema changes, backfills, nullable→non-nullable transitions, historical/temporal data |
| **Compatibility** | Existing API consumers, persisted state, in-flight jobs, cached payloads |
| **Access control & security** | Permission/role gates the change must be wired into, authorization rules |
| **Localization & conventions** | Required display text, language/culture rules, naming conventions |
| **Toolchain** | Codegen steps, snapshot files, lint/build/test gates that must pass |

### Step 5 — Frame the Options (not the plan)

Present **2–3 genuinely viable approaches**, each with:
- A one-line description of the approach.
- **Trade-offs**: complexity, blast radius, migration cost, convention fit, reversibility.
- Which existing prior art it follows.
- Why it might be rejected.

Close with a **recommendation and the reason for it**. Keep options at the level of *strategy* — where the change lives and what shape it takes. Task breakdowns, phases and file-by-file edits belong to `/plan`.

### Step 6 — Build the Confidence Ledger

Sort every material finding into exactly one bucket. This is the single most valuable output of the skill:

- ✅ **Verified** — traced to a specific `path:line`.
- 🟡 **Inferred** — reasonable deduction from convention or partial evidence; state the basis and how to confirm it.
- ❓ **Unknown** — could not be determined from the codebase; state who or what could answer it, and whether the plan is blocked without it.

Never quietly promote an inference into a fact.

---

## 3. Evidence Discipline

- **Cite everything.** Findings link to source, workspace-relative: `[UserRoleAccessRules.cs:42](source/.../UserRoleAccessRules.cs#L42)`.
- **Quote sparingly.** Short excerpts to make a point; never dump whole files into the artifact.
- **Distinguish "not found" from "does not exist."** Say *"no match for `X` across `src/`"* and name the search, rather than asserting absence.
- **Record dead ends.** A documented "this approach is blocked because …" saves the next reader the same hour.

---

## 4. Scope Control

Research expands to fill available time. Bound it:

- Answer the Step 0 questions, then **stop** — resist the adjacent-interesting-thing.
- Prefer breadth first (map the territory), then depth only where a decision actually hinges on the detail.
- When a broad sweep across many files is needed and the host offers read-only search agents, delegating that sweep is appropriate — the conclusions still need citations.
- If the investigation reveals the request rests on a false premise, **say so immediately and prominently** rather than researching around it.

---

## 5. Output Format & Deliverables

### 5.1 The Artifact — `<prefix>-investigation.md` (workspace root)

```markdown
# Investigation: <Topic>

**Goal:** <one-sentence restatement>
**Scope:** <repos / projects / domains touched>
**Status:** Complete | Blocked on open questions
**Date:** <YYYY-MM-DD>

## 1. Questions This Answers
1. <question> → <one-line answer>   <!-- the Step 0 spine, each with its verdict -->

## 2. TL;DR
<3–6 bullets. What is true, what it means, what the recommended direction is.>

## 3. How It Works Today
<Current-state map of the relevant system, with file links. Include a flow or
layer walkthrough where it aids comprehension.>

## 4. Prior Art / Reference Implementation
<The closest analogous feature and why it is the pattern to follow, with links.
Note any competing patterns and which one wins.>

## 5. Constraints & Contracts
| Constraint | Impact | Source |
|---|---|---|

## 6. Blast Radius
<Every file, consumer, test and contract a change here would touch, with links.>

## 7. Options & Trade-offs
### Option A — <name>
- **Approach:** …
- **Pros / Cons:** …
- **Follows:** <prior art>
### Option B — <name>
…
**Recommendation:** <choice + rationale>

## 8. Confidence Ledger
| Finding | Confidence | Evidence / How to confirm |
|---|---|---|
| … | ✅ Verified | `path:line` |
| … | 🟡 Inferred | basis + confirmation step |
| … | ❓ Unknown | who/what can answer; blocking? |

## 9. Open Questions for the User
<Only genuine blockers or decisions that are the user's to make. Empty is a good answer.>

## 10. Plan Seed
<The handoff: the 3–8 bullet skeleton /plan should expand — no task breakdown,
no phases, no code. Just the shape of the change and its known gotchas.>
```

Omit sections that would be empty rather than padding them.

### 5.2 The Chat Response

Keep it high-signal per [core §1.3](../core/SKILL.md) — the depth lives in the artifact:

1. **The headline** — 1–2 sentences: the single most decision-relevant finding.
2. **Clickable artifact link**, per the [artifacts](../artifacts/SKILL.md) protocol:
   - Claude Code: `📄 [claude-investigation.md](claude-investigation.md)`
   - Antigravity IDE: `📄 [antigravity-investigation.md](file://<workspace-root>/antigravity-investigation.md)`
3. **Anchor links** to key sections, using real `#L<line>` numbers read back from the written file.
4. **Recommendation** in one line.
5. **Open questions**, if any — asked directly in chat so the user can answer without opening the file.
6. **The handoff line** (below).

---

## 6. Verification & Validation

Before declaring the investigation complete, confirm:

- [ ] Every Step 0 question is answered, or listed as ❓ Unknown with a reason.
- [ ] Every factual claim carries a `path:line` citation, or sits in the Inferred/Unknown buckets.
- [ ] No claim rests on a filename or symbol name alone.
- [ ] Relevant rulebooks and project-scoped skills were read, and their constraints are reflected.
- [ ] Cross-layer and cross-repo implications were checked, not assumed absent.
- [ ] Blast radius came from an actual search, not from memory.
- [ ] **No source file was modified and no mutating command was run.**
- [ ] Anchor line numbers were read back from the written artifact:
      `grep -n '^#\{1,3\} ' <prefix>-investigation.md`

---

## 7. Handoff

End every investigation with the handoff, and then **stop**:

```markdown
**Next:** `/plan` — I'll turn §10 Plan Seed into an implementation plan.
Or `/what-am-I-missing` for a blind-spot sweep, or tell me which option to build on.
```

Never continue into `/plan` unprompted. The gate is the user's.
