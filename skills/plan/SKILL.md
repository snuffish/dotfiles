---
name: plan
description: Opens, inspects, creates, or updates the active, host-prefixed implementation plan (<prefix>-implementation_plan-<suffix>.md). When invoked without arguments (/plan), immediately returns a direct, clickable file link to open the active plan in the IDE along with its status and section anchors. When invoked with instructions, drafts or updates the plan with a mandatory contextual suffix.
---

# Skill: `/plan` — Implementation Plan Manager

Manages the active implementation plan (`<prefix>-implementation_plan-<suffix>.md`) for the session.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **Target Artifact**: `<prefix>-implementation_plan-<suffix>.md` at the **workspace root**.
- **Anti-Overwrite Rule**: Always append a descriptive kebab-case `<suffix>` derived from the Work Item ID, PR ID, branch, or topic. Never emit unsuffixed generic plan files.

---

## 1. When to Use

Invoke this skill whenever:
- The user types `/plan` (either bare or followed by instructions / suffix).
- The user asks to *"open the plan"*, *"show me the plan"*, *"view the implementation plan"*, or *"link to the plan"*.
- The user asks to draft a new plan or update the existing plan for a feature or task.

---

## 2. Core Behaviors

### Case A: Bare Command (`/plan` with no arguments or message)

When the user runs `/plan` without arguments (or simply says "open plan"):

1. **Locate the Plan Artifact:**
   - Scan for `<prefix>-implementation_plan-*.md` at the **workspace root**.
   - If an artifact matching the current git branch or active topic exists, select it.
   - If multiple candidate plans exist, present a numbered list allowing the user to select one or target it via `/plan <suffix>`.
   - If only one plan exists, target it immediately.

2. **Render Direct Link & Navigation Immediately:**
   - **DO NOT** edit code or execute background commands.
   - Output a clickable markdown link built exactly as the **[artifacts](../artifacts/SKILL.md)** protocol specifies, so the user can open it with a single click in the IDE.
   - Provide clickable anchor links (`#L<line>`) to the key sections of the plan:
     - 📄 Context & Goal
     - 📄 Proposed Changes
     - 📄 Verification Plan
   - Display the current status of the plan (e.g., `Drafting`, `Awaiting Review`, `Approved`, or `Completed`).

#### Output Template for Bare `/plan`:

**Under Antigravity IDE:**
```markdown
Here is the active implementation plan:

📄 **[antigravity-implementation_plan-<suffix>.md](file://<workspace-root>/antigravity-implementation_plan-<suffix>.md)**

### Key Sections:
- 📄 [Context & Goal](file://<workspace-root>/antigravity-implementation_plan-<suffix>.md#L8)
- 📄 [Proposed Changes](file://<workspace-root>/antigravity-implementation_plan-<suffix>.md#L24)
- 📄 [Verification Plan](file://<workspace-root>/antigravity-implementation_plan-<suffix>.md#L61)

**Status:** [Draft | Awaiting User Review | Approved | Completed]
```

**Under Claude Code:**
```markdown
Here is the active implementation plan:

📄 **[claude-implementation_plan-<suffix>.md](claude-implementation_plan-<suffix>.md)**

### Key Sections:
- 📄 [Context & Goal](claude-implementation_plan-<suffix>.md#L8)
- 📄 [Proposed Changes](claude-implementation_plan-<suffix>.md#L24)
- 📄 [Verification Plan](claude-implementation_plan-<suffix>.md#L61)

**Status:** [Draft | Awaiting User Review | Approved | Completed]
```

3. If no matching implementation plan exists yet:
   - Inform the user that no active plan exists in the workspace.
   - Offer to create one based on their next prompt or goal.

---

### Case B: Command With Instructions (`/plan <instructions>`)

When the user supplies instructions or a topic (e.g., `/plan refactor user authentication`, `/plan 18176-verksamhetsobjekt`):

1. **Resolve the Contextual Suffix:**
   - Priority 1: Work Item / PR / Ticket ID + slug (e.g. `18176-verksamhetsobjekt`, `29982-verksamhetsobjekt`).
   - Priority 2: Git branch slug (e.g. `new-users-audit`).
   - Priority 3: 2–4 word kebab-case topic descriptor (e.g. `begar-prefix`, `draft-close-dialog`).
   - Target filename: `<prefix>-implementation_plan-<suffix>.md`.

2. **Enter Planning Mode:**
   - **Check for an existing investigation first.** If `<prefix>-investigation-<suffix>.md` exists at the
     workspace root and covers this topic, read it and build the plan on its findings — especially
     its *Plan Seed*, *Options & Trade-offs*, and *Confidence Ledger*. Do not re-run research that
     is already documented; do resolve anything it flagged ❓ Unknown that the plan depends on.
   - Otherwise, research the relevant codebase areas without making code changes. If the topic is
     large or the unknowns are substantial, run [`/investigate`](../investigate/SKILL.md) first.
   - Formulate a clean, structured design adhering to project conventions (DDD, FastEndpoints, Radix UI, sealed classes, etc.).

3. **Create or Update `<prefix>-implementation_plan-<suffix>.md`:**
   - Write the plan to `<prefix>-implementation_plan-<suffix>.md` at the **workspace root**. That location is
     what makes the link clickable, so do not put it elsewhere.

4. **Present the Plan:**
   - Provide the direct clickable link to `<prefix>-implementation_plan-<suffix>.md`.
   - Highlight key architectural decisions or open questions.
   - Wait for explicit user approval before executing any code changes.
