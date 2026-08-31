---
name: review
description: Conducts a thorough, read-only architectural and technical review of an implementation plan, design proposal, or PR without executing or modifying code. STRICT INVARIANT: NEVER proceeds or implements changes without an explicit /proceed command.
---

# Skill: `/review` — Strict Plan & Design Review

Conducts a deep, systematic, read-only technical audit and review of an implementation plan (`<prefix>-implementation_plan.md`), architectural proposal, or change design.

---

## Artifact Filename — Host Prefix

> [!IMPORTANT]
> Claude Code and Antigravity IDE share one workspace root. An unprefixed filename means
> whichever host runs second silently overwrites the other's work. **Resolve a prefix once,
> before writing**, from your own identity in the system prompt:
>
> | Running as | Prefix | This skill writes |
> |---|---|---|
> | Claude Code — *"You are Claude"* | `claude-` | `claude-implementation_plan.md` |
> | Antigravity IDE — *"You are Antigravity"* | `antigravity-` | `antigravity-implementation_plan.md` |
> | Any other host | *(none)* | `implementation_plan.md` |
>
> This is the same signal that already decides `file://` vs relative links, so resolve it
> once and reuse it. Use the resolved name in the file you write **and** in every link you
> emit. Never write both names, and never read or overwrite the other host's file — if
> `antigravity-implementation_plan.md` exists while you are Claude, leave it alone.
>
> Below, `<prefix>-` stands for the resolved prefix.

## ⛔ The Golden Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR DEVIATION:**
>
> 1. **MANDATORY PLAN.MD REFERENCE (NO EXCUSES):** Every single `/review` response MUST ALWAYS include a clickable link to the active plan file, built exactly as *Plan Artifact Reference* below specifies (`[claude-implementation_plan.md](claude-implementation_plan.md)`). The user frequently needs to click and open it in the IDE. This applies to ALL review responses, including follow-up reviews and questions asked under `/review`.
> 2. **DO NOT MODIFY CODE:** You must **NEVER** edit files, create new source files, run modifying CLI commands (e.g. migrations, git commits, code scaffolding), or begin implementation during or immediately after a `/review`.
> 3. **DO NOT AUTO-PROCEED:** Even if the plan is completely sound, verified, flawless, or approved, you must **NEVER** start implementing it automatically.
> 4. **MANDATORY GATE:** Implementation of any plan must **ALWAYS and ONLY** begin when the user explicitly issues the command:
>    ```text
>    /proceed
>    ```
>    **NEVER proceed without an explicit `/proceed` command from the user.**

---

## 1. When to Use

Invoke this skill whenever:
- The user issues `/review` or asks for a plan/design review.
- An `<prefix>-implementation_plan.md` has been drafted and needs a rigorous sanity check before execution.
- The user asks: *"Does this plan make sense?"*, *"Review this approach"*, or *"Check for design flaws"*.

---

## 2. Review Workflow

### Step 1: Locate the Target Plan & Context
1. Check `<prefix>-implementation_plan.md` at the **workspace root**, or any active proposal artifacts.
2. If reviewing a branch, PR, or code diff, locate the relevant files or work items (composing with `code-review` principles if reviewing already-written code).
3. Read the relevant project rulebooks and conventions:
   - Root rulebook: [CLAUDE.md](CLAUDE.md) (or [GEMINI.md](GEMINI.md) under Antigravity)
   - Backend guidelines: [copilot-instructions.md](GR.PRIIS.Backend/.github/copilot-instructions.md)
   - Frontend guidelines: [copilot-instructions.md](GR.PRIIS.Frontend/.github/copilot-instructions.md)

### Step 2: Evaluate Against Core Pillars

Examine the proposal across five core evaluation dimensions:

#### 1. Architecture & Domain Modeling (DDD)
- Are aggregate boundaries and entities respected?
- Is domain logic housed within entities or nested `AsyncMutations` domain services rather than leaking into API endpoints or DTOs?
- Does the design avoid antipatterns (e.g. improper inheritance where composition is needed, or bypassing private invariants)?

#### 2. Project Rulebook & Code Standards
- **Classes:** Are classes marked `sealed` by default?
- **Interfaces:** Are interfaces strictly reserved for external I/O (SMS, Email, third-party clients) or Library boundary decoupling, avoiding unnecessary domain-layer interfaces?
- **FastEndpoints:** Are endpoints inheriting from `ExtendedEndpoint`, using `Policy(SystemAction...)`, returning `SystemResult`, and using `SendAndSaveChangesAsync`?
- **EF Core:** Do read queries use `.Select()` projections rather than eager `.Include()` chains? Are temporal tables, change tracking, and concurrency handled properly?
- **Frontend:** Does it follow Radix UI themes, React Hook Form + Zod v4 (`zod/v4`), TanStack Router file-based conventions, and centralized test IDs?

#### 3. Security, Authorization & Access Rules
- Are appropriate `SystemAction` policies assigned to endpoints?
- Does data access route through `.ApplyAccessRules()` or delegation rules where tenant/user scoping is required?
- Are there any privilege escalation risks or unprotected write paths?

#### 4. Edge Cases, Resilience & Invariants
- What happens on validation failure? Are error messages in Swedish (`sv-SE`)?
- Are database constraints, cascade deletes, or foreign key restrictions satisfied?
- Are cancellation tokens (`CancellationToken ct`) threaded through all asynchronous calls?
- Are mutations idempotent or safely handled in transactions if multiple tables are updated?

#### 5. Verification & Testing Completeness
- Does the plan have a concrete automated test strategy?
- Are backend endpoints covered by integration tests (TUnit/xUnit with TestContainers and `AutoRollback`)?
- Does it verify authorized, forbidden, and unauthorized flows?

---

## 3. Output Format

Produce a concise, structured review report using this template:

> [!IMPORTANT]
> **Plan Artifact Reference Requirement:**
> Always begin the review response with the target plan artifact reference and clickable key sections header. The user frequently closes the artifact tab in the IDE; this provides an immediate, one-click way to reopen the plan and navigate to specific sections directly from chat.

> [!IMPORTANT]
> **Host-Specific Link Formats (Antigravity IDE vs Claude Code):**
> - **Antigravity IDE**: Chat requires absolute paths with `file://` scheme:
>   `[antigravity-implementation_plan.md](file://<workspace-root>/antigravity-implementation_plan.md#L8)`
>   *(Relative links without `file://` render as dead/unclickable text in Antigravity).*
> - **Claude Code**: Chat requires workspace-relative paths without scheme:
>   `[claude-implementation_plan.md](claude-implementation_plan.md#L8)`
>   *(Absolute `file:///...` URIs render as dead text in Claude Code).*
> - **Fragment format for CHAT links (both hosts)**: Always use `#L<line>` (e.g. `#L8` or `#L8-L20`), **never** heading slugs (`#context--goal` does not work in Claude Code). Read the numbers off the file after writing it:
>   `grep -n '^#\{1,3\} ' <prefix>-implementation_plan.md`
> - **Intra-document links inside markdown files**: For internal links within a markdown file itself, use HTML anchor tags `<a id="..."></a>` and semantic `#anchor` targets, never line numbers `#L<line>`.

**Under Antigravity IDE:**
```markdown
📄 [antigravity-implementation_plan.md](file://<workspace-root>/antigravity-implementation_plan.md)

Key Sections:
- 📄 [Context & Goal](file://<workspace-root>/antigravity-implementation_plan.md#L8): [1-sentence summary of context/decisions]
- 📄 [Proposed Changes](file://<workspace-root>/antigravity-implementation_plan.md#L24): [1-sentence summary of touched files/components]
- 📄 [Verification Plan](file://<workspace-root>/antigravity-implementation_plan.md#L61): [1-sentence summary of test & build verification]
```

**Under Claude Code:**
```markdown
📄 [claude-implementation_plan.md](claude-implementation_plan.md)

Key Sections:
- 📄 [Context & Goal](claude-implementation_plan.md#L8): [1-sentence summary of context/decisions]
- 📄 [Proposed Changes](claude-implementation_plan.md#L24): [1-sentence summary of touched files/components]
- 📄 [Verification Plan](claude-implementation_plan.md#L61): [1-sentence summary of test & build verification]
```

---

# 🔍 Plan Review: [Feature / Topic Name]

## 🚦 Verdict
> **[READY FOR /proceed | NEEDS REVISION | BLOCKED]**
> *One-sentence summary of overall readiness.*

---

## 💡 Key Strengths
- Bullet points highlighting what the plan gets right (architecture alignment, conventions, clean scoping).

---

## ⚠️ Findings & Concerns

### 🔴 Critical (Must resolve before proceeding)
- Issues that will break the build, violate security/authorization, or cause runtime failures.

### 🟡 Important (Should address or clarify)
- Convention deviations, potential performance bottlenecks, missing edge cases, or test gaps.

### 🟢 Minor / Suggestions (Nice-to-have)
- Naming refinements, documentation clarity, or minor cleanup suggestions.

---

## 📋 Recommended Action Items
1. [Actionable change to the plan if needed]
2. ...

---

## 🔒 Next Step Gate
> [!IMPORTANT]
> **Execution is locked.** No code changes or commands have been executed.
> To proceed with implementing this plan, reply with:
> ```text
> /proceed
> ```
```

---

## 4. End-of-Turn Behavior

After delivering the review:
1. **STOP IMMEDIATELY.** Do not call any code-editing or file-writing tools.
2. Wait for the user's explicit `/proceed` command before taking any implementation action.
