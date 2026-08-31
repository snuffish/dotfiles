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
   - Look for `implementation_plan.md` at the **workspace root**.
   - If not found there, check the most recent session from conversation history.

2. **Render Direct Link & Navigation Immediately:**
   - **DO NOT** edit code or execute background commands.
   - Output a clickable markdown link built exactly as the *Link format* box below specifies, so the user can open it with a single click in the IDE.
   - Provide clickable anchor links to the key sections of the plan:
     - 📄 Context & Goal
     - 📄 Proposed Changes
     - 📄 Verification Plan
   - Display the current status of the plan (e.g., `Drafting`, `Awaiting Review`, `Approved`, or `Completed`).

#### Output Template for Bare `/plan`:
> [!IMPORTANT]
> **Link format — links only resolve one way.** Use a **workspace-relative** path with no
> scheme; an absolute `file:///...` URI renders as dead text, as does any path outside the
> workspace root. Section anchors must be **line numbers** (`#L42`), never heading slugs
> (`#context--goal` does not work). Read the numbers off the file *after* writing it:
> `grep -n '^#\{1,3\} ' <artifact>.md`, and re-read them if you edit it afterwards.

The `#L` numbers are placeholders — replace them with the real ones from `grep -n`.

```markdown
Here is the active implementation plan:

📄 **[implementation_plan.md](implementation_plan.md)**

### Key Sections:
- 📄 [Context & Goal](implementation_plan.md#L8)
- 📄 [Proposed Changes](implementation_plan.md#L24)
- 📄 [Verification Plan](implementation_plan.md#L61)

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
   - Write the plan to `implementation_plan.md` at the **workspace root**. That location is
     what makes the link clickable, so do not put it elsewhere.

3. **Present the Plan:**
   - Provide the direct clickable link to the plan.
   - Highlight key architectural decisions or open questions.
   - Wait for explicit user approval before executing any code changes.
