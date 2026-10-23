---
name: plan
description: Opens, inspects, creates, or updates the active, host-prefixed implementation plan (<prefix>-implementation_plan-<suffix>.md). When invoked without arguments (/plan), immediately returns a direct, clickable file link to open the active plan in the IDE along with its status and section anchors; when several plans exist, it first asks which one. When invoked with instructions, drafts or updates the plan with a mandatory contextual suffix.
---

# Skill: `/plan` — Implementation Plan Manager

Manages the active implementation plan (`<prefix>-implementation_plan-<suffix>.md`) for the session. This skill owns the plan's **skeleton**, its **status values** and its **link block**. Every other Command that writes or reads a plan (`/implement-feature`, `/problem`, `/refine`, `/pr-fix-pipeline`, `/plan-review`, `/proceed`) uses the definitions here.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-implementation_plan-<suffix>.md` at the **workspace root**

---

## 2. The Plan Contract

### Status values

A plan's second line carries `**Status:** <value>`, with one of:

| Value | Meaning | Set by |
|---|---|---|
| `Draft` | Being written; not ready for review | The writer, while drafting |
| `Awaiting User Review` | Complete and waiting at the gate | The writer, when presenting it |
| `Approved` | The user opened the gate; implementation is running | `core` › *The `/proceed` gate* |
| `Completed` | Every phase in scope is done and verified | `core` › *The `/proceed` gate* |

A short note may follow the value (`Approved — phase 2 of 3 done`). Readers match the leading value only.

### Skeleton

```markdown
<!-- artifact-owner: … -->                 <!-- artifact-protocol › Claim -->
# Implementation Plan: <title>

**Status:** Awaiting User Review
**Suffix:** `<suffix>`
**Inputs:** <investigation / review / ticket links, or "none">

## 1. Context & Goal
## 2. Decisions                  <!-- table: decision · why -->
## 3. Proposed Changes           <!-- per phase or per repo: [NEW|MODIFY|DELETE] <path> — what and why -->
## 4. Verification Plan          <!-- exact commands, plus manual steps -->
## 5. Risks                      <!-- table: risk · mitigation -->
## 6. Open Questions             <!-- each with a recommendation -->
## 7. Task Checklist             <!-- the live checklist: [ ] / [/] / [x] -->
```

A Command may add sections it needs (`/implement-feature` adds *User Review Required*, *Blind-spot Pass* and *Cross-repo order*). It keeps these seven, in this order, so `/plan`, `/plan-review` and `/proceed` can find them.

### Link block

Every chat response that presents a plan starts with this block. Take the line numbers from the file after writing it (`grep -n '^#\{1,3\} ' <file>`); never copy numbers from an example:

```markdown
📄 **[<file>](<link>)**
- 📄 [Context & Goal](<link>#L<n>)
- 📄 [Proposed Changes](<link>#L<n>)
- 📄 [Verification Plan](<link>#L<n>)
- 📄 [Open Questions](<link>#L<n>)

**Status:** <value>
```

`<link>` follows `artifact-protocol` › *Host-Specific Link Formats*: `file://<workspace-root>/<file>` under Antigravity, the bare workspace-relative `<file>` in the Claude Code IDE extension, and `antigravity-ide://file/<workspace-root>/<file>` in the Claude Code terminal CLI, where section links end in `:<n>` instead of `#L<n>`. A Command may append a one-line summary after each section link (`/plan-review` does).

---

## 3. Core Behaviors

### Case A: Bare Command (`/plan` with no arguments or message)

1. **Locate the plan:**
   - Scan for `<prefix>-implementation_plan-*.md` at the **workspace root**. Treat `<name>.md`, `<name>-2.md`, … as one family (`artifact-protocol` › *Claim*).
   - If only one family exists, use it.
   - If several families exist, **ask the user which one** before rendering anything: under Claude Code with `AskUserQuestion`, under Antigravity with `ask_question`, otherwise with a numbered list. Do not auto-select, even when one matches the branch or topic.
     - One option per family, labelled by its suffix, with the latest revision's `Status` and modification time as the description.
     - Put the family matching the current git branch or active topic first and mark it `(Recommended)`; order the rest newest first.
     - `AskUserQuestion` takes at most 4 options: show the top 4 and name the rest in the question text, so the user can type one under *Other*.
     - Tell the user they can skip the question next time with `/plan <suffix>`.
   - If none exists, say so and offer to create one from the user's next prompt.
2. **Render the link block** (*§2 Link block*) for the chosen plan, with its current `Status`. Do not edit anything or run background commands.

### Case B: Command With Instructions (`/plan <instructions>`)

1. **Resolve the contextual suffix** (`artifact-protocol` › rule 2):
   - Priority 1: work item / PR / ticket id + slug (e.g. `18176-verksamhetsobjekt`).
   - Priority 2: git branch slug (e.g. `new-users-audit`).
   - Priority 3: a 2–4 word kebab-case topic (e.g. `draft-close-dialog`).
2. **Plan, without changing code:**
   - **Check for an existing investigation first.** If `<prefix>-investigation-<suffix>.md` exists at the workspace root and covers this topic, build on it: its *Plan Seed*, *Options & Trade-offs* and *Confidence Ledger*. Do not re-run research it already documents; do resolve any ❓ Unknown the plan depends on.
   - Otherwise research the relevant code read-only. If the topic is large or the unknowns are substantial, run [`/investigate`](../investigate/SKILL.md) first.
   - Design to the project's own conventions: its workspace rulebooks, project-scoped References and Profile (`core` › *Precedence*).
3. **Write the plan** in the *§2 Skeleton*, at the **workspace root**:
   - **New plan:** draft it in a session-private path, then publish it with *Claim* (`artifact-protocol` › rule 4). If the base name is taken, Claim writes `…-2.md`; use the path it printed and say so in chat.
   - **Existing plan:** update it only if its owner marker names this session, or if the user named that file and asked for it to be updated (`artifact-protocol` › rule 3). Otherwise write a new revision through *Claim*, and link the one it supersedes in **Inputs**.
   - Set `Status` to `Awaiting User Review` when it is complete.
4. **Present the plan:** the link block, then the key decisions and open questions in a few lines. Wait for the user to open the gate (`core` › *The `/proceed` gate*) before any code change.
