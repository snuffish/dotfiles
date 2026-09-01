---
name: plan
description: Opens, inspects, creates, or updates the active, host-prefixed implementation plan (claude-implementation_plan.md under Claude Code, antigravity-implementation_plan.md under Antigravity IDE). When invoked without arguments (/plan), immediately returns a direct, clickable file link to open the active plan in the IDE along with its status and section anchors. When invoked with instructions, drafts or updates the plan.
---

# Skill: `/plan` — Implementation Plan Manager

Manages the active implementation plan (`<prefix>-implementation_plan.md`) for the session.

---

## Artifact Delivery Protocol

Adhere strictly to the **[artifacts](../artifacts/SKILL.md)** protocol for host prefix resolution (`claude-` vs `antigravity-`), clickability rules, link formatting (`file://` vs relative), and `#L<line>` section anchors.
- **Target Artifact**: `<prefix>-implementation_plan.md` at the **workspace root**.

---

## 1. When to Use

Invoke this skill whenever:
- The user types `/plan` (either bare or followed by instructions).
- The user asks to *"open the plan"*, *"show me the plan"*, *"view the implementation plan"*, or *"link to the plan"*.
- The user asks to draft a new plan or update the existing plan for a feature or task.

---

## 2. Core Behaviors

### Case A: Bare Command (`/plan` with no arguments or message)

When the user runs `/plan` without any arguments (or simply says "open plan"):

1. **Locate the Plan Artifact:**
   - Look for `<prefix>-implementation_plan.md` at the **workspace root**.
   - If not found there, check the most recent session from conversation history.

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

📄 **[antigravity-implementation_plan.md](file://<workspace-root>/antigravity-implementation_plan.md)**

### Key Sections:
- 📄 [Context & Goal](file://<workspace-root>/antigravity-implementation_plan.md#L8)
- 📄 [Proposed Changes](file://<workspace-root>/antigravity-implementation_plan.md#L24)
- 📄 [Verification Plan](file://<workspace-root>/antigravity-implementation_plan.md#L61)

**Status:** [Draft | Awaiting User Review | Approved | Completed]
```

**Under Claude Code:**
```markdown
Here is the active implementation plan:

📄 **[claude-implementation_plan.md](claude-implementation_plan.md)**

### Key Sections:
- 📄 [Context & Goal](claude-implementation_plan.md#L8)
- 📄 [Proposed Changes](claude-implementation_plan.md#L24)
- 📄 [Verification Plan](claude-implementation_plan.md#L61)

**Status:** [Draft | Awaiting User Review | Approved | Completed]
```

3. If no `<prefix>-implementation_plan.md` exists yet:
   - Inform the user that no active plan exists in the current session.
   - Offer to create one based on their next prompt or goal.

---

### Case B: Command With Instructions (`/plan <instructions>`)

When the user supplies instructions (e.g., `/plan refactor user authentication`):

1. **Enter Planning Mode:**
   - Research the relevant codebase areas without making code changes.
   - Formulate a clean, structured design adhering to project conventions (DDD, FastEndpoints, Radix UI, sealed classes, etc.).

2. **Create or Update `<prefix>-implementation_plan.md`:**
   - Write the plan to `<prefix>-implementation_plan.md` at the **workspace root**. That location is
     what makes the link clickable, so do not put it elsewhere.

3. **Present the Plan:**
   - Provide the direct clickable link to the plan.
   - Highlight key architectural decisions or open questions.
   - Wait for explicit user approval before executing any code changes.
