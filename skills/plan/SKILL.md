---
name: plan
description: 'Opens, inspects, creates, updates, previews or reviews the active implementation plan (<prefix>-implementation_plan-<suffix>.md). Bare /plan returns links; /plan <instructions> drafts or updates, then self-reviews before presenting; /plan preview reopens in the host preview panel; /plan --review [suffix] audits a plan or design proposal before any code is written (architecture and convention fit, edge cases, security and authorization, data and migration safety, test coverage) with a READY / NEEDS REVISION / BLOCKED verdict, read-only until /proceed. Use --review for "review this plan", "does this plan make sense?", "poke holes in this design".'
argument-hint: "[--review [suffix] | preview [suffix] | suffix | instructions]"
---

# Skill: `/plan` — Implementation Plan Manager

Manages the active implementation plan (`<prefix>-implementation_plan-<suffix>.md`) for the session. This skill owns the plan's **skeleton**, its **status values**, its **link block** and its **review** (`--review`). Every other Command that writes or reads a plan (`/implement-feature`, `/problem`, `/refine`, `/pr-fix-pipeline`, `/proceed`) uses the definitions here.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-implementation_plan-<suffix>.md` at the **workspace root**
- `../_modules/project-profile.md`: base profile only (no Command profile), for the review (_Case D_); reads _Pattern skills per layer_, _Contract touchpoints_, _Sibling chain_ and an optional _Plan-review checks_ field

---

## 2. The Plan Contract

### Status values

A plan's second line carries `**Status:** <value>`, with one of:

| Value                  | Meaning                                             | Set by                         |
| ---------------------- | --------------------------------------------------- | ------------------------------ |
| `Draft`                | Being written; not ready for review                 | The writer, while drafting     |
| `Awaiting User Review` | Complete and waiting at the gate                    | The writer, when presenting it |
| `Approved`             | The user opened the gate; implementation is running | `core` › _The `/proceed` gate_ |
| `Completed`            | Every phase in scope is done and verified           | `core` › _The `/proceed` gate_ |

A short note may follow the value (`Approved — phase 2 of 3 done`). Readers match the leading value only.

### Skeleton

```markdown
<!-- artifact-owner: … -->                 <!-- artifact-protocol › Claim -->

# Implementation Plan: <title>

**Status:** Awaiting User Review
**Suffix:** `<suffix>`
**Inputs:** <investigation / review / ticket links, or "none">
**Review:** <_Case D_ verdict after folding> · <n> findings folded <!-- Case B step 4 -->

## 1. Context & Goal

## 2. Decisions <!-- table: decision · why -->

## 3. Proposed Changes <!-- per phase or per repo: [NEW|MODIFY|DELETE] <path> — what and why -->

## 4. Verification Plan <!-- exact commands, plus manual steps -->

## 5. Risks <!-- table: risk · mitigation -->

## 6. Task Checklist <!-- the live checklist: [ ] / [/] / [x] -->

## 7. Open Questions <!-- unresolved questions; always last, if any; each with a recommendation -->
```

A Command may add sections it needs (`/implement-feature` adds _User Review Required_, _Blind-spot Pass_ and _Cross-repo order_). It keeps these seven, in this order, so `/plan`, `/plan --review` and `/proceed` can find them. _Open Questions_ (unresolved questions) is always the last section; an added section goes before it.

### Style

The user's rule (`AGENTS.md` / `~/.claude/CLAUDE.md` › _Plans_), verbatim:

> - Make the plan extremely concise. Sacrifice grammar for the sake of concision.
> - At the end of each plan, give me a list of unresolved questions to answer, if any.

Every plan writer applies it to the whole file **and to the chat response that presents the plan**:

- Fragments, not prose: no paragraphs, no full-sentence explanations.
- About 15 words per bullet at most; split a longer one into sub-bullets.
- _Decisions_ and _Risks_ as tables.
- Every open question carries **Rec:** with the recommended answer.
- Nothing after _Open Questions_. If there are no unresolved questions, note "None" (or omit).

### Link block

Every chat response that presents a plan starts with this block. Take the line numbers from the file after writing it (`grep -n '^#\{1,3\} ' <file>`); never copy numbers from an example:

```markdown
📄 **[<file>](link)**

- 📄 [Context & Goal](<link>#L<n>)
- 📄 [Proposed Changes](<link>#L<n>)
- 📄 [Verification Plan](<link>#L<n>)
- 📄 [Open Questions](<link>#L<n>)

**Status:** <value>
```

`<link>` follows `artifact-protocol` › _Host-Specific Link Formats_: `file://<workspace-root>/<file>` under Antigravity, the bare workspace-relative `<file>` in the Claude Code IDE extension, and `antigravity-ide://file/<workspace-root>/<file>` in the Claude Code terminal CLI, where section links end in `:<n>` instead of `#L<n>`. A Command may append a one-line summary after each section link (`/plan --review` does).

---

## 3. Core Behaviors

Pick the case from the arguments, first match wins:

| Arguments            | Case               |
| -------------------- | ------------------ |
| Contain `--review`   | D: review a plan   |
| Start with `preview` | C: preview         |
| None                 | A: bare            |
| Anything else        | B: draft or update |

### Case A: Bare Command (`/plan` with no arguments or message)

1. **Locate the plan:**
   - Scan for `<prefix>-implementation_plan-*.md` at the **workspace root**. Treat `<name>.md`, `<name>-2.md`, … as one family (`artifact-protocol` › _Claim_).
   - If only one family exists, use it.
   - If several families exist, **ask the user which one** before rendering anything: under Claude Code with `AskUserQuestion`, under Antigravity with `ask_question`, otherwise with a numbered list. Do not auto-select, even when one matches the branch or topic.
     - One option per family, labelled by its suffix, with the latest revision's `Status` and modification time as the description.
     - Put the family matching the current git branch or active topic first and mark it `(Recommended)`; order the rest newest first.
     - `AskUserQuestion` takes at most 4 options: show the top 4 and name the rest in the question text, so the user can type one under _Other_.
     - Tell the user they can skip the question next time with `/plan <suffix>`.
   - If none exists, say so and offer to create one from the user's next prompt.
2. **Render the link block** (_§2 Link block_) for the chosen plan, with its current `Status`. Do not edit anything or run background commands.

### Case B: Command With Instructions (`/plan <instructions>`)

1. **Resolve the contextual suffix** (`artifact-protocol` › rule 2):
   - Priority 1: work item / PR / ticket id + slug (e.g. `18176-verksamhetsobjekt`).
   - Priority 2: git branch slug (e.g. `new-users-audit`).
   - Priority 3: a 2–4 word kebab-case topic (e.g. `draft-close-dialog`).
2. **Plan, without changing code:**
   - **Check for an existing investigation first.** If `<prefix>-investigation-<suffix>.md` exists at the workspace root and covers this topic, build on it: its _Plan Seed_, _Options & Trade-offs_ and _Confidence Ledger_. Do not re-run research it already documents; do resolve any ❓ Unknown the plan depends on.
   - Otherwise research the relevant code read-only. If the topic is large or the unknowns are substantial, run [`/investigate`](../investigate/SKILL.md) first.
   - Design to the project's own conventions: its workspace rulebooks, project-scoped References and Profile (`core` › _Precedence_).
3. **Write the plan** in the _§2 Skeleton_, at the **workspace root**:
   - **New plan:** draft it in a session-private path, then publish it with _Claim_ (`artifact-protocol` › rule 4). If the base name is taken, Claim writes `…-2.md`; use the path it printed and say so in chat.
   - **Existing plan:** update it only if its owner marker names this session, or if the user named that file and asked for it to be updated (`artifact-protocol` › rule 3). Otherwise write a new revision through _Claim_, and link the one it supersedes in **Inputs**.
   - Set `Status` to `Awaiting User Review` when it is complete.
4. **Self-review before presenting:** run _Case D_ steps 2–3 on the plan just written, in the main context. Use its pillars and severities. Do not print its report or its gate: this is part of drafting, and the user reviews the folded plan.
   - Fold every finding into the plan before presenting:

     | Finding                                   | Goes into                                                                                              |
     | ----------------------------------------- | ------------------------------------------------------------------------------------------------------ |
     | 🔴 / 🟡, verified (`path:line` re-opened) | **Proposed Changes**, **Task Checklist**, and a **Verification Plan** check that fails without the fix |
     | 🔴 / 🟡 needing a user decision           | **Open Questions**, with **Rec:**                                                                      |
     | 🟢                                        | Apply if one line; else drop                                                                           |
     | Rejected finding                          | **Risks**, one row with the reason                                                                     |

   - Re-read the plan once for anything a fix contradicts (an earlier step, a test, a decision row), and fix it.
   - Run the review **once**. Fill the **Review:** header line with the verdict the folded plan would get.
   - Run it on every new plan, and on every update that changes _Proposed Changes_ or _Verification Plan_. Skip it for an update that only ticks the checklist or changes `Status`.
5. **Present the plan:** the link block, the review verdict and the findings that changed the design (one bullet each), the key decisions as at most ~5 fragment bullets, then the open questions last, each with its **Rec:** (_§2 Style_ applies to this chat text too: no paragraphs, no full sentences). Wait for the user to open the gate (`core` › _The `/proceed` gate_) before any code change.

### Case C: Preview Command (`/plan preview [target]`)

Shows an existing plan in the host's planning preview panel (using `ExitPlanMode` when available), so the user can read, comment on, and approve it interactively.

1. **Resolve plan:** Use argument (path or suffix), the session's active plan file, or the latest workspace-root plan family (Case A).
2. **Host capability check:** If the host lacks `ExitPlanMode` (such as Antigravity IDE), output the plan's link block (Case A) and explain that the host renders plans directly via markdown links.
3. **Enter plan mode & copy:** Call `EnterPlanMode`, read the host plan-file path from the system message, and copy the source plan into it (omitting the leading `<!-- artifact-owner: … -->` comment).
4. **Open preview:** Call `ExitPlanMode`.
5. **Handle decision:**
   - _Approve_: User authorized implementation (`core` › _The `/proceed` gate_). Begin execution.
   - _Keep planning / Feedback_: Stay in plan mode, pass feedback to Case B to update the plan, and reopen preview.
   - _Closed / Error_: Report status and provide the file link.

### Case D: Review Command (`/plan --review [target]`)

Strict, read-only audit of an implementation plan, architectural proposal or change design, before any code is written. Read-only until `/proceed` (`core` › _The `/proceed` gate_):

- Never edit files, run modifying commands (migrations, commits, scaffolding) or start implementing, even when the plan is flawless.
- Every response under `--review`, follow-ups included, starts with the link block: the user often closes the plan tab and reopens it from chat.
- Implementation starts only on the user's explicit `/proceed`.

Wrong tool:

| Situation                                        | Use instead                                             |
| ------------------------------------------------ | ------------------------------------------------------- |
| A code diff, branch or PR rather than a plan     | [`/code-review`](../code-review/SKILL.md)               |
| Reviewer comments and votes on a PR              | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| Research before a plan exists                    | [`/investigate`](../investigate/SKILL.md)               |
| Hidden assumptions and failure modes of a design | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md)   |

1. **Locate the plan:** the argument names it (`/plan --review 18176`, `/plan --review begar-prefix`); otherwise follow _Case A_ step 1. For a proposal that is not a plan artifact (a branch, PR or design doc), locate its files or work items.
2. **Read the project's rules** (`core` › _Precedence_): the workspace rulebooks (`CLAUDE.md`, or `GEMINI.md` under Antigravity, and any rulebook they point to, such as `.github/copilot-instructions.md`), the project-scoped References for the layers the plan touches, and the base profile when one matches the workspace (`project-profile` › _Discovery_). Its _Pattern skills per layer_, _Contract touchpoints_ and _Plan-review checks_ fields name the concrete conventions to check.
3. **Evaluate against five pillars**, plus every item of the profile's _Plan-review checks_ under the pillar it names:
   1. **Architecture & domain modeling**
      - Aggregate and module boundaries respected; domain logic in the domain layer, not endpoints, controllers or DTOs.
      - Follows the nearest existing feature of the same kind (profile's _Sibling chain_), or says why not.
      - No antipatterns: inheritance where composition fits, bypassing an entity's invariants.
   2. **Project conventions**
      - Every new endpoint, query, component, form and test follows its layer's pattern skills and the rulebook's language idioms (e.g. `modern-csharp`).
      - New abstractions justified: an interface for real I/O or a library boundary, not per class.
      - A cross-repo contract (profile's _Contract touchpoints_) is updated on both sides.
      - Follows _§2 Style_: _Open Questions_ not last, or a question without **Rec:**, is 🟡; prose instead of fragments is 🟢.
   3. **Security, authorization & access rules**
      - Every new endpoint or write path carries the project's authorization; data scoped to the caller (tenant, owner, role).
      - No privilege escalation or unprotected write paths.
   4. **Edge cases, resilience & invariants**
      - Validation failures handled; messages follow the project's language and locale.
      - Constraints, cascades and foreign keys satisfied; migration safe for existing data.
      - Cancellation tokens threaded through async calls.
      - Multi-table mutations transactional; retried requests idempotent.
   5. **Verification & testing**
      - Concrete automated test strategy in the project's framework and fixtures.
      - Covers authorized, forbidden and unauthenticated paths, not only the happy path.
4. **Report:** the link block (_§2 Link block_) with the plan's real line numbers and a one-sentence summary after each section link (what the context decides, what the changes touch, how it is verified), then:

   ````markdown
   # 🔍 Plan Review: [Feature / Topic Name]

   ## 🚦 Verdict

   > **[READY FOR /proceed | NEEDS REVISION | BLOCKED]**
   > _One-sentence summary of overall readiness._

   ## 💡 Key Strengths

   - What the plan gets right (architecture, conventions, scoping).

   ## ⚠️ Findings & Concerns

   ### 🔴 Critical (must resolve before proceeding)

   - Breaks the build, violates security or authorization, or fails at runtime.

   ### 🟡 Important (should address or clarify)

   - Convention deviations, performance risks, missing edge cases, test gaps.

   ### 🟢 Minor / Suggestions

   - Naming, documentation clarity, small cleanup.

   ## 📋 Recommended Action Items

   1. [Actionable change to the plan]

   ## 🔒 Next Step Gate

   > [!IMPORTANT]
   > **Execution is locked.** No code changes or commands have been executed.
   > To implement this plan, reply with:
   >
   > ```text
   > /proceed
   > ```
   ````

5. **Stop.** No editing or file-writing tools until the user's `/proceed`.
