---
name: plan
description: "Opens, inspects, creates, updates, or previews the active implementation plan (<prefix>-implementation_plan-<suffix>.md). Bare /plan returns links; /plan <instructions> drafts or updates, then self-reviews with /plan-review before presenting; /plan preview reopens in the host preview panel."
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
| --- | --- | --- |
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
**Review:** <`/plan-review` verdict after folding> · <n> findings folded   <!-- Case B step 4 -->

## 1. Context & Goal
## 2. Decisions                  <!-- table: decision · why -->
## 3. Proposed Changes           <!-- per phase or per repo: [NEW|MODIFY|DELETE] <path> — what and why -->
## 4. Verification Plan          <!-- exact commands, plus manual steps -->
## 5. Risks                      <!-- table: risk · mitigation -->
## 6. Task Checklist             <!-- the live checklist: [ ] / [/] / [x] -->
## 7. Open Questions             <!-- unresolved questions; always last, if any; each with a recommendation -->
```

A Command may add sections it needs (`/implement-feature` adds *User Review Required*, *Blind-spot Pass* and *Cross-repo order*). It keeps these seven, in this order, so `/plan`, `/plan-review` and `/proceed` can find them. *Open Questions* (unresolved questions) is always the last section; an added section goes before it.

### Style

The user's rule (`AGENTS.md` / `~/.claude/CLAUDE.md` › *Plans*), verbatim:

> - Make the plan extremely concise. Sacrifice grammar for the sake of concision.
> - At the end of each plan, give me a list of unresolved questions to answer, if any.

Every plan writer applies it to the whole file **and to the chat response that presents the plan**:

- Fragments, not prose: no paragraphs, no full-sentence explanations.
- About 15 words per bullet at most; split a longer one into sub-bullets.
- *Decisions* and *Risks* as tables.
- Every open question carries **Rec:** with the recommended answer.
- Nothing after *Open Questions*. If there are no unresolved questions, note "None" (or omit).

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
4. **Self-review before presenting:** run [`/plan-review`](../plan-review/SKILL.md) › *Step 1–2* on the plan just written, in the main context. Use its pillars and severities. Do not print its report or its gate: this is part of drafting, and the user reviews the folded plan.
   - Fold every finding into the plan before presenting:

     | Finding | Goes into |
     | --- | --- |
     | 🔴 / 🟡, verified (`path:line` re-opened) | **Proposed Changes**, **Task Checklist**, and a **Verification Plan** check that fails without the fix |
     | 🔴 / 🟡 needing a user decision | **Open Questions**, with **Rec:** |
     | 🟢 | Apply if one line; else drop |
     | Rejected finding | **Risks**, one row with the reason |

   - Re-read the plan once for anything a fix contradicts (an earlier step, a test, a decision row), and fix it.
   - Run the review **once**. Fill the **Review:** header line with the verdict the folded plan would get.
   - Run it on every new plan, and on every update that changes *Proposed Changes* or *Verification Plan*. Skip it for an update that only ticks the checklist or changes `Status`.
5. **Present the plan:** the link block, the review verdict and the findings that changed the design (one bullet each), the key decisions as at most ~5 fragment bullets, then the open questions last, each with its **Rec:** (*§2 Style* applies to this chat text too: no paragraphs, no full sentences). Wait for the user to open the gate (`core` › *The `/proceed` gate*) before any code change.

### Case C: Preview Command (`/plan preview [target]`)

Shows an existing plan in the host's planning preview panel (using `ExitPlanMode` when available), so the user can read, comment on, and approve it interactively.

1. **Resolve plan:** Use argument (path or suffix), the session's active plan file, or the latest workspace-root plan family (Case A).
2. **Host capability check:** If the host lacks `ExitPlanMode` (such as Antigravity IDE), output the plan's link block (Case A) and explain that the host renders plans directly via markdown links.
3. **Enter plan mode & copy:** Call `EnterPlanMode`, read the host plan-file path from the system message, and copy the source plan into it (omitting the leading `<!-- artifact-owner: … -->` comment).
4. **Open preview:** Call `ExitPlanMode`.
5. **Handle decision:**
   - *Approve*: User authorized implementation (`core` › *The `/proceed` gate*). Begin execution.
   - *Keep planning / Feedback*: Stay in plan mode, pass feedback to Case B to update the plan, and reopen preview.
   - *Closed / Error*: Report status and provide the file link.
