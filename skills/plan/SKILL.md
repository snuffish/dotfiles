---
name: plan
description: Opens, inspects, creates, or updates the active implementation plan (implementation_plan.md). When invoked without arguments (/plan), immediately returns a direct, clickable file link to open the active plan in the IDE along with its status and section anchors. When invoked with instructions, drafts or updates the plan.
---

# Skill: `/plan` — Implementation Plan Manager

Manages the active implementation plan (`implementation_plan.md`) for the session.

---

## 1. When to Use

Invoke this skill whenever:
- The user types `/plan` (either bare or followed by instructions).
- The user asks to *"open the plan"*, *"show me the plan"*, *"view implementation_plan.md"*, or *"link to the plan"*.
- The user asks to draft a new plan or update the existing plan for a feature or task.

---

## 2. Core Behaviors

### Case A: Bare Command (`/plan` with no arguments or message)

When the user runs `/plan` without any arguments (or simply says "open plan"):

1. **Locate the Plan Artifact:**
   - Look for `implementation_plan.md` in the active conversation directory:
     `<appDataDir>/brain/<conversation-id>/implementation_plan.md`
   - If not found in the current session, check the most recent session from conversation history.

2. **Render Direct Link & Navigation Immediately:**
   - **DO NOT** edit code or execute background commands.
   - Output a clear, direct, clickable markdown file link using the `file://` scheme so the user can open it with a single click in the IDE.
   - Provide direct clickable anchor links to the key sections of the plan:
     - 📄 Context & Goal
     - 📄 Proposed Changes
     - 📄 Verification Plan
   - Display the current status of the plan (e.g., `Drafting`, `Awaiting Review`, `Approved`, or `Completed`).

#### Output Template for Bare `/plan`:
```markdown
Here is the active implementation plan:

📄 **[implementation_plan.md](file://<appDataDir>/brain/<conversation-id>/implementation_plan.md)**

### Key Sections:
- 📄 [Context & Goal](file://<appDataDir>/brain/<conversation-id>/implementation_plan.md#context--goal)
- 📄 [Proposed Changes](file://<appDataDir>/brain/<conversation-id>/implementation_plan.md#proposed-changes)
- 📄 [Verification Plan](file://<appDataDir>/brain/<conversation-id>/implementation_plan.md#verification-plan)

**Status:** [Draft | Awaiting User Review | Approved | Completed]
```

3. If no `implementation_plan.md` exists yet:
   - Inform the user that no active plan exists in the current session.
   - Offer to create one based on their next prompt or goal.

---

### Case B: Command With Instructions (`/plan <instructions>`)

When the user supplies instructions (e.g., `/plan refactor user authentication`):

1. **Enter Planning Mode:**
   - Research the relevant codebase areas without making code changes.
   - Formulate a clean, structured design adhering to project conventions (DDD, FastEndpoints, Radix UI, sealed classes, etc.).

2. **Create or Update `implementation_plan.md`:**
   - Write the plan to `<appDataDir>/brain/<conversation-id>/implementation_plan.md`.
   - Set `RequestFeedback: true` and `UserFacing: true` in `ArtifactMetadata`.

3. **Present the Plan:**
   - Provide the direct clickable link to the plan.
   - Highlight key architectural decisions or open questions.
   - Wait for explicit user approval before executing any code changes.
