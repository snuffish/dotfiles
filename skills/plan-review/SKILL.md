---
name: plan-review
description: "\"Reviews an implementation plan or design proposal before any code is written: fit with the architecture and the project's conventions, missing edge cases, security and authorization, data and migration safety, test and verification coverage. Gives a READY / NEEDS REVISION / BLOCKED verdict with findings by severity. Use for /plan-review, \\\"review this plan\\\", \\\"does this plan make sense?\\\", \\\"poke holes in this design\\\". Read-only until /proceed.\"."
---

# Skill: `/plan-review` — Strict Plan & Design Review

Conducts a deep, systematic, read-only technical audit and review of an implementation plan (`<prefix>-implementation_plan-<suffix>.md`), architectural proposal, or change design.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: references and manages `<prefix>-implementation_plan-<suffix>.md` at the **workspace root**
- `../_modules/project-profile.md`: base profile only (no Command profile); reads *Pattern skills per layer*, *Contract touchpoints*, *Sibling chain* and an optional *Plan-review checks* field

---

## ⛔ The Golden Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR DEVIATION:**
>
> 1. **MANDATORY PLAN.MD REFERENCE (NO EXCUSES):** Every single `/plan-review` response MUST ALWAYS include a clickable link to the active plan file, built exactly as *Plan Artifact Reference* below specifies (`[<prefix>-implementation_plan-<suffix>.md](...)`). The user frequently needs to click and open it in the IDE. This applies to ALL review responses, including follow-up reviews and questions asked under `/plan-review`.
> 2. **DO NOT MODIFY CODE:** You must **NEVER** edit files, create new source files, run modifying CLI commands (e.g. migrations, git commits, code scaffolding), or begin implementation during or immediately after a `/plan-review`.
> 3. **DO NOT AUTO-PROCEED:** Even if the plan is completely sound, verified, flawless, or approved, you must **NEVER** start implementing it automatically.
> 4. **MANDATORY GATE:** Implementation of any plan must **ALWAYS and ONLY** begin when the user explicitly issues the command:
>    ```text
>    /proceed
>    ```
>    **NEVER proceed without an explicit `/proceed` command from the user.**

---

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Reviewing a code diff, branch or PR rather than a plan | [`/code-review`](../code-review/SKILL.md) |
| Reviewer comments and votes on a PR | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| Research that should happen *before* a plan exists | [`/investigate`](../investigate/SKILL.md) |
| Hidden assumptions and failure modes of a design | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |

---

## 2. Review Workflow

### Step 1: Locate the Target Plan & Context
1. Locate `<prefix>-implementation_plan-<suffix>.md` at the **workspace root**:
   - If an argument or suffix was supplied (e.g. `/plan-review 18176`, `/plan-review begar-prefix`), target that specific plan artifact.
   - If invoked bare, check for matching plans via `ls -lt <prefix>-implementation_plan-*.md` at the workspace root. If multiple exist, match against the current branch or ask the user to specify.
2. If reviewing a branch, PR, or code diff, locate the relevant files or work items (composing with `code-review` principles if reviewing already-written code).
3. Read the project's own rules, per `core` › *Precedence*: the workspace rulebooks (`CLAUDE.md`, or `GEMINI.md` under Antigravity, and any rulebook they point to, such as `.github/copilot-instructions.md`), the project-scoped References for the layers the plan touches, and the project's base profile when one matches the workspace (`project-profile` › *Discovery*). The profile's *Pattern skills per layer*, *Contract touchpoints* and *Plan-review checks* fields name the concrete conventions to check below.

### Step 2: Evaluate Against Core Pillars

Examine the proposal across five core evaluation dimensions:

#### 1. Architecture & Domain Modeling
- Are aggregate or module boundaries respected, and does domain logic live in the domain layer rather than leaking into endpoints, controllers or DTOs?
- Does the design follow the nearest existing feature of the same kind (the profile's *Sibling chain*), or explain why it departs from it?
- Does it avoid antipatterns such as inheritance where composition is needed, or bypassing an entity's own invariants?

#### 2. Project Conventions
- Does every new endpoint, query, component, form and test follow the project's pattern skills for its layer, and the rulebook's language idioms (e.g. `modern-csharp`, `typescript-conventions`)?
- Are new abstractions justified (an interface for real I/O or a library boundary, not for every class)?
- Does it touch a cross-repo contract (the profile's *Contract touchpoints*), and does it update both sides of it?

#### 3. Security, Authorization & Access Rules
- Does every new endpoint or write path carry the project's authorization mechanism, and is data scoped to the caller (tenant, owner, role)?
- Are there privilege escalation risks or unprotected write paths?

#### 4. Edge Cases, Resilience & Invariants
- What happens on validation failure, and do messages follow the project's language and locale rules?
- Are database constraints, cascades and foreign keys satisfied, and is a migration safe for existing data?
- Are cancellation tokens threaded through asynchronous calls?
- Are multi-table mutations transactional, and are retried requests idempotent?

#### 5. Verification & Testing Completeness
- Does the plan have a concrete automated test strategy, in the project's test framework and fixtures?
- Does it cover the authorized, forbidden and unauthenticated paths, not just the happy path?

When the project's profile has a *Plan-review checks* field, check every item in it as well, under the pillar it names.

---

## 3. Output Format

Produce a concise, structured review report using this template:

> [!IMPORTANT]
> **Plan Artifact Reference Requirement:**
> Always begin the review response with the target plan artifact reference and clickable key sections header. The user frequently closes the artifact tab in the IDE; this provides an immediate, one-click way to reopen the plan and navigate to specific sections directly from chat.

Use the plan link block from [`/plan`](../plan/SKILL.md) › *§2 Link block*, with the reviewed plan's real line numbers (`grep -n`) and a one-sentence summary after each section link: what the context decides, what the changes touch, how it is verified.

Then the review itself:

````markdown
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
````

---

## 4. End-of-Turn Behavior

After delivering the review:
1. **STOP IMMEDIATELY.** Do not call any code-editing or file-writing tools.
2. Wait for the user's explicit `/proceed` command before taking any implementation action.
