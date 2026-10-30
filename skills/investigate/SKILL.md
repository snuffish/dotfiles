---
name: investigate
description: 'Deep read-only research before designing a change: traces symbols, maps call flows and blast radius, uncovers prior art and conventions, surfaces cross-layer constraints, weighs options, audits critical blind spots (integrating /what-am-I-missing), and writes an evidence-backed `<prefix>-investigation-<suffix>.md` that /plan builds on. Use for /investigate, "research this", "how does X work before we change it?", "what would it take to add Y?", "scope this out", "is this feasible?".'
---

# Skill: `/investigate` — Pre-Plan Research & Discovery

The dedicated reconnaissance pass executed **before** `/plan`. It replaces speculation with verifiable evidence, answering: _"What is actually true in this codebase today, what are our viable options, and what critical traps are we missing?"_

A plan built on assumptions breaks down during implementation. This skill guarantees that every assertion is anchored to real code or explicitly quarantined as an unverified inference, performs an adversarial blind-spot audit (incorporating the `/what-am-I-missing` flow), and hands `/plan` a battle-tested evidence foundation instead of a blank page.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-investigation-<suffix>.md` at the **workspace root** (suffix e.g. `-draft-close-dialog`, `-municipality-sync`)

---

## ⛔ Golden Operational Invariants

> [!CAUTION]
> **ZERO-TOLERANCE RULES — READ-ONLY DISCIPLINE:**
>
> 1. **STRICTLY READ-ONLY**: Never edit source code, scaffold files, stage git changes, run database migrations, or execute mutating commands. The only file this skill creates or modifies is its own workspace artifact: `<prefix>-investigation-<suffix>.md`.
> 2. **DO NOT WRITE THE PLAN**: Deliver current-state findings, architectural options, trade-offs, and a seed outline. Never draft task phases, step-by-step checklists, or `<prefix>-implementation_plan-<suffix>.md`. Solution architecture belongs to `/plan`.
> 3. **NO UNCITED CLAIMS**: Every factual claim about codebase behavior, interfaces, or types must carry a precise `path:line` citation. Deductions must be explicitly marked **Inferred** or **Unknown**.
> 4. **NO AUTO-PROCEED**: Never roll directly from research into planning or implementation without explicit user authorization. Present findings and hand off control.

---

## 1. When to Use

### Skill Neighborhood & Routing

| Objective / Context                                                                               | Correct Skill                                                                                          |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Deep-dive research, ground truth, options, and critical blind spots **before** designing a change | **`/investigate`** (this skill — includes the `/what-am-I-missing` audit)                              |
| Synthesizing gathered evidence into a phased task plan                                            | [`/plan`](../plan/SKILL.md)                                                                            |
| Explaining an isolated symbol, expression, error, or PR comment                                   | [`/explain`](../explain/SKILL.md)                                                                      |
| Diagnosing an active regression, failing test, or runtime crash                                   | [`/problem`](../problem/SKILL.md)                                                                      |
| Auditing an existing plan or pull request diff                                                    | [`/plan-review`](../plan-review/SKILL.md) (plans) or [`/code-review`](../code-review/SKILL.md) (diffs) |
| Standalone blind-spot audit of an already-chosen approach, plan, or diff                          | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md)                                                  |
| Another visual angle on a finished investigation (a different diagram, a diff, an HTML view)      | `/show-me` (user-invoked only; see §4 _Visuals_)                                                       |

---

## 2. Invocation Modes

### Case A: Bare Command (`/investigate` with no arguments)

When the user runs `/investigate` without instructions:

1. **Locate Existing Investigation**:
   - Check for `<prefix>-investigation-*.md` at the **workspace root**.
2. **If Found**:
   - Immediately output a direct clickable IDE link and key section anchors (`#L<line>`):
     ```markdown
     Here is the active investigation:

     📄 **[<prefix>-investigation-<suffix>.md](file://<workspace-root>/<prefix>-investigation-<suffix>.md)** (or the Claude Code link format from `artifact-protocol`)

     ### Key Sections:

     - 📄 [TL;DR](file://<workspace-root>/<prefix>-investigation-<suffix>.md#L16)
     - 📄 [Current-State Architecture](file://<workspace-root>/<prefix>-investigation-<suffix>.md#L32)
     - 📄 [Options & Trade-offs](file://<workspace-root>/<prefix>-investigation-<suffix>.md#L78)
     - 📄 [Blind Spots (What Am I Missing?)](file://<workspace-root>/<prefix>-investigation-<suffix>.md#L95)
     - 📄 [Confidence Ledger](file://<workspace-root>/<prefix>-investigation-<suffix>.md#L120)
     - 📄 [Plan Seed](file://<workspace-root>/<prefix>-investigation-<suffix>.md#L145)

     **Status:** Complete | Blocked on open questions
     ```
3. **If Not Found**:
   - Inform the user that no active investigation exists for this workspace.
   - Prompt them for the topic, module, or feature they would like to investigate.

---

### Case B: Command With Instructions (`/investigate <topic>`)

When the user supplies a topic or goal (e.g. `/investigate multi-tenant webhook dispatching`):
Execute the complete **Investigation Protocol** below.

---

## 3. The 8-Step Investigation Protocol

```mermaid
flowchart TD
    S0["Step 0: Frame Scope & Questions"] --> S1["Step 1: Orient & Workspace Context"]
    S1 --> S2["Step 2: Locate Prior Art & Analogous Flows"]
    S2 --> S3["Step 3: Trace Real Code Cross-Layer"]
    S3 --> S4["Step 4: Surface Contracts, Constraints & Blast Radius"]
    S4 --> S5["Step 5: Frame Architectural Options & Trade-offs"]
    S5 --> S6["Step 6: Audit Blind Spots (What Am I Missing?)"]
    S6 --> S7["Step 7: Assemble Confidence Ledger"]
    S7 --> Art["Write & Deliver <prefix>-investigation-<suffix>.md"]
```

### Step 0 — Frame the Scope & Questions

Before reading code, establish strict research boundaries to avoid sprawling:

1. **Goal**: Restate the inquiry in one concise, unambiguous sentence.
2. **Core Questions**: Define 3–7 precise questions that must be resolved before a plan can be drafted.
3. **Done Condition**: Specify the clear boundary where investigation ends (e.g., "Identified exact database schema, call flow from controller to worker, and existing test patterns").

### Step 1 — Orient & Recover Context

1. **Workspace Rulebooks**: Check `CLAUDE.md`, `GEMINI.md`, and `.agents/rules/` for global architectural patterns, forbidden libraries, or repository constraints.
2. **Project-Scoped Skills**: Identify and load relevant domain skills per `core` › _Precedence_ (e.g. `Projects/GR.PRIIS/priis-backend-fastendpoints`, `priis-frontend-rtk-query`).
3. **Repository Topology**: Determine if the change crosses repository or package boundaries (e.g., Backend API, Frontend SPA, Shared Contracts, Shared Worker).
4. **Historical Decisions**: Inspect recent commits (`git log -n 5 -p`) and search past conversational transcripts (`<appDataDir>/brain/` or `~/.claude/projects/`) to honor established decisions and avoid relitigating resolved debates.

### Step 2 — Locate Prior Art & Reference Patterns

Codebases thrive on consistency. The most reliable pattern is usually the one already proven in a sibling feature:

- Locate the nearest analogous implementation (e.g., sibling endpoint, existing form, matching domain event, existing migration).
- Read the reference flow across every layer it touches.
- Identify competing or inconsistent patterns in the codebase. Clearly document which one represents modern repository consensus and why.

### Step 3 — Trace Real Code Cross-Layer (No Guesswork)

Inspect actual source code definitions rather than making assumptions based on file or variable names:

- **Enclosing Scope**: Inspect full class definitions, lifecycles, and middlewares—not just isolated snippets.
- **Cross-Layer Mapping**:
  - _API ↔ UI_: Route path, query params, DTO payload schemas, serialization settings, and client state/queries.
  - _Domain ↔ Storage_: Entity definitions, database contexts, foreign keys, cascade configurations, and migrations.
  - _Runtime ↔ Config_: Environment settings, dependency injection registrations, and background schedulers.
- **Existing Test Coverage**: Locate unit and integration tests covering this flow. If tests do not exist, document that absence as a critical finding.

### Step 4 — Surface Contracts, Constraints & Blast Radius

Map out what could break:

- **Blast Radius**: Enumerate all direct callers, downstream subscribers, consumers, and external webhooks.
- **Data & Migration Risks**: Identify schema locks, breaking column drops, data backfill requirements, or nullable transitions.
- **Third-Party & Network Boundaries**: Identify external APIs, timeouts, fallback policies, and retry behaviors.
- **Auth & Access Control**: Check role-based or tenant authorization gates protecting the target pathways.

### Step 5 — Frame Architectural Options (Not the Plan)

Present 2–3 viable, contrasting implementation approaches:

- **Approach Summary**: High-level structural description (where state lives, how events flow).
- **Trade-offs**: Complexity, performance, blast radius, migration burden, and reversibility.
- **Prior Art Reference**: Which existing pattern or file each option resembles.
- **Recommendation & Rationale**: Explicitly designate the recommended option and justify why it wins.

### Step 6 — Audit Blind Spots & Critical Omissions (What Am I Missing?)

Audit the leading/recommended option against the **7 Universal Blindspot Vectors**:

1. **💾 Persistence, Transactions & Data Integrity**: Engine invariants, partial failure atomicity, schema locks, migration backfill.
2. **⚡ Concurrency, State Drift & Lifecycles**: Race conditions, cache invalidation, terminal/archived lifecycle states.
3. **🌐 Boundaries, Contracts & Blast Radius**: Downstream breaking changes, polymorphic coverage, third-party timeouts/fallbacks.
4. **🔒 Security, Authorization & Tenancy**: Tenant isolation/IDOR, permission revocation, token/secret leakage.
5. **🚀 Operational Realities & Performance**: Scale traps ($O(N)$ / N+1), resource leaks, observability/debuggability.
6. **🧪 Testing Realities & False Confidence**: Mocks that lie, negative/asymmetric paths, idempotency under retry.
7. **🧩 Leaky Abstractions & Design Consistency**: Developer traps, single source of domain truth.

Identify and record:

- 🎯 **The #1 Primary Blind Spot**: The single most critical unstated assumption or hidden invariant.
- 💥 **Blast Radius / Failure Scenario**: Trigger condition, concrete impact, and why it went unnoticed.
- 🔍 **Secondary Blind Spots**: 1–2 additional high-probability edge cases.
- 🛠️ **Actionable Fix & Prevention**: Immediate fix for the plan seed plus structural/type-level prevention.

### Step 7 — Assemble the Confidence Ledger

Classify every key finding into one of three strict categories:

- ✅ **Verified**: Confirmed by inspecting specific code (`path/to/file.ext:L12-L34`).
- 🟡 **Inferred**: Plausible deduction based on convention or partial evidence. Include explicit instructions on how to verify before implementation.
- ❓ **Unknown**: Information missing from the codebase (e.g. business logic decisions, external service credentials). Document who owns the decision and whether it blocks planning.

---

## 4. Workspace Artifact Specification

Save the investigation artifact directly to the **workspace root** using the host and model prefix:

- **Antigravity IDE**: `<workspace-root>/antigravity-<model>-investigation-<suffix>.md`
- **Claude Code**: `<workspace-root>/claude-<model>-investigation-<suffix>.md`

### Artifact Template

```markdown
# Investigation: <Topic Name>

**Goal:** <One-sentence restatement of user goal>  
**Scope:** <Repositories, microservices, domains, or directories touched>  
**Status:** Complete | Blocked on open questions  
**Date:** <YYYY-MM-DD>

---

## 1. Questions Answered

1. **<Question 1>?** → <Direct, concise answer with source citation>
2. **<Question 2>?** → <Direct, concise answer with source citation>

---

## 2. Executive Summary (TL;DR)

- <Key finding 1: current state truth>
- <Key finding 2: primary constraint or contract>
- <Key finding 3: recommended architectural direction>

---

## 3. Current-State Architecture & Code Map

<Walkthrough of the active implementation, including data flow, call sequences, and file links.>

<One visual of the flow, per _Visuals_: a Mermaid sequenceDiagram or a call tree.>

| Component / Layer     | Source Location          | Responsibilities                             |
| --------------------- | ------------------------ | -------------------------------------------- |
| Controller / Endpoint | `path/to/File.cs:L20`    | Handles request dispatch and validation      |
| Domain Service        | `path/to/Service.cs:L45` | Business invariants and transaction boundary |

---

## 4. Prior Art & Reference Patterns

- **Primary Reference**: `path/to/SiblingFeature.cs:L30` — cleanest pattern to mirror.
- **Pattern Inconsistencies**: <Notes on legacy vs modern patterns if both exist in the repo.>

---

## 5. Constraints & Contracts

| Constraint Category | Impact / Requirement                          | Source Evidence             |
| ------------------- | --------------------------------------------- | --------------------------- |
| Schema & Migration  | Requires non-nullable column backfill         | `src/Db/Migration.cs:L12`   |
| Cross-Service API   | Downstream consumer expects fixed JSON format | `src/Contracts/Event.cs:L8` |

---

## 6. Blast Radius

- **Direct Callers**: <List of calling methods/components with file links>
- **Shared State / Persistence**: <Tables, caches, or stores affected>
- **Existing Test Coverage**: <Paths to unit/integration test suites, or "None found">

---

## 7. Options & Trade-offs

### Option A: <Name> (Recommended)

- **Concept:** <One-sentence summary>
- **Pros:** ...
- **Cons:** ...
- **Follows:** `path/to/Reference.cs`

<A `diff` of the call tree, state flow, or file tree this option changes, per _Visuals_.>

### Option B: <Name>

- **Concept:** <One-sentence summary>
- **Pros:** ...
- **Cons:** ...
- **Follows:** ...

**Recommendation:** <Why Option A is selected over alternatives.>

---

## 8. Blind Spots & Critical Omission Analysis (What Am I Missing?)

### 🎯 The #1 Most Important Thing You Are Missing

> **[One bold, unambiguous sentence identifying the primary blind spot or hidden invariant]**

[Direct technical explanation: What is the unstated assumption or hidden invariant, why does it exist, and why is it easy to overlook?]

#### 💥 The Failure Scenario

- **Trigger:** [Exact condition, user action, edge case, or production event]
- **Impact:** [Precise exception, data corruption, security vulnerability, or performance cliff]
- **Why it went unnoticed:** [Why surface-level code inspection or existing tests didn't catch it]

#### 🔍 Secondary Blind Spots & Nuances

1. **[Secondary Risk 1]:** [Concise explanation of related implication]
2. **[Secondary Risk 2]:** [Concise explanation of related implication]

#### 🛠️ Actionable Recommendation

1. **Immediate Fix:** [Concrete step to eliminate the #1 blind spot in the plan seed]
2. **Structural Prevention:** [How to make this impossible to get wrong via types, architecture, or invariants]

---

## 9. Confidence Ledger

| Finding / Assumption                     | Level       | Evidence / Verification Method                            |
| ---------------------------------------- | ----------- | --------------------------------------------------------- |
| Existing handler uses optimistic locking | ✅ Verified | `src/Handlers/OrderHandler.cs:L55`                        |
| Legacy background job runs every 15 mins | 🟡 Inferred | Cron schedule in `appsettings.json`, needs runtime check  |
| Third-party API rate limits for webhook  | ❓ Unknown  | External vendor docs needed; non-blocking for scaffolding |

---

## 10. Open Questions for User

<Decisions that belong exclusively to the user, or genuine blockers. Leave empty if none.>

---

## 11. Plan Seed

<High-level structural outline for /plan to build upon. No phases, no task lists, no code snippets.>

- 1. Define domain contracts and event schemas adhering to Option A.
- 2. Add database schema migration with backward-compatible defaults.
- 3. Implement business handler mirroring prior art in `SiblingFeature.cs`.
- 4. Wire client state hook and update frontend component.
```

### Visuals

Apply the `/show-me` view rules (`~/.agents/skills/show-me/SKILL.md`) inside the artifact. That skill sets `disable-model-invocation: true`, so this skill cannot load it; only the user can run it, which the handoff offers.

Pick the smallest view that makes each point clear, at most three per artifact:

| Section               | Point to make                                                                                                          | View                                                   |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| §3 Current-State      | Interaction across components, threads, or processes, or anything where order matters (races, retries, async handoffs) | Mermaid `sequenceDiagram`                              |
| §3 Current-State      | Control flow within one process                                                                                        | Call tree in a `text` block                            |
| §7 Recommended option | What the option changes                                                                                                | `diff` of that call tree, state flow, or file tree     |
| §8 Failure scenario   | The trigger, when it depends on timing and the §3 visual does not already show it                                      | Mermaid `sequenceDiagram` with a `Note` at the failure |

- Every node in a visual is a symbol from the §3 code map table, so each one traces to a `path:line`. A visual never carries a claim that the text does not cite.
- Keep only the calls, files, and boundaries needed for the point. Use real names, not placeholders.
- The §7 `diff` shows shape (calls, states, files), not implementation code. The Plan Seed stays free of code.
- Skip visuals when the answer is a single fact that one cited sentence already states.

---

## 5. Chat Response Protocol

Per `core` › _Golden invariants_ (3), chat output must remain concise and high-signal, pointing directly to the artifact:

1. **Headline**: 1–2 sentences summarizing the most critical finding and primary direction. Below it, repeat the single artifact visual that best carries the headline (usually the §3 diagram). Show only that one; the rest stay in the artifact.
2. **Clickable Artifact Link**:
   - **Antigravity IDE**: `📄 [antigravity-<model>-investigation-<suffix>.md](file://<workspace-root>/antigravity-<model>-investigation-<suffix>.md)`
   - **Claude Code**: `📄 [claude-<model>-investigation-<suffix>.md](claude-<model>-investigation-<suffix>.md)`
3. **Section Anchors**: Read exact line numbers (`grep -n '^#\{1,3\} ' <prefix>-investigation-<suffix>.md`) and output clickable links to:
   - `[Executive Summary]`
   - `[Options & Trade-offs]`
   - `[Blind Spots & Critical Omissions]`
   - `[Confidence Ledger]`
   - `[Plan Seed]`
4. **Primary Recommendation & #1 Blind Spot**: State the winning approach and highlight the bold #1 blind spot directly in chat.
5. **Open Questions**: Surface blocking user decisions directly in chat.
6. **Standard Handoff Line**:
   ```markdown
   **Next Step:** Type `/plan <suffix>` to convert the Plan Seed into a detailed implementation plan, or `/show-me <aspect>` for another view of the findings.
   ```

---

## 6. Pre-Handoff Quality Checklist

Confirm every item before finalizing the response:

- [ ] Strictly read-only: zero modifications to application source code or repository configuration.
- [ ] No implementation plan was written: options and architecture seeds provided, no task phases.
- [ ] Every factual statement contains a workspace-relative `path:line` citation.
- [ ] Blind-spot audit across the 7 universal vectors completed and documented in Section 8.
- [ ] Inferred assertions and unknown dependencies are documented in the Confidence Ledger.
- [ ] Visuals follow §4 _Visuals_: at most three, every node is a cited symbol, one repeated in chat.
- [ ] Rulebooks (`CLAUDE.md`/`GEMINI.md`) and project-scoped skills were verified.
- [ ] Target artifact was written directly to the workspace root using the correct host prefix.
- [ ] Chat links and section anchors (`#L<line>`) were verified via grep.
- [ ] Explicit handoff presented without auto-proceeding.
