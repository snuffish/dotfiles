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
- `../_modules/artifact-protocol.md`: writes `<prefix>-implementation_plan-<suffix>.md` in the artifact dir (`artifact-protocol`)
- `../_modules/project-profile.md`: base profile only (no Command profile), for the review (_Case D_); reads _References per layer_, _Contract touchpoints_, _Sibling chain_ and an optional _Plan-review checks_ field
- `../_modules/fan-out.md`: _Review lenses_ for the self-review (_Case B step 4_) and `--review` (_Case D step 3_)

On-demand references (`references/`):
- [`references/review.md`](references/review.md) — five review pillars (_Case D step 3_) and report template for `--review` (Case D) and self-review (Case B step 4)

---

## 1. The Plan Contract

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

The user's rule (`~/.claude/CLAUDE.md` › _Plan Mode_) applies: extremely concise, grammar sacrificed; end with **Steps**, then **Unresolved questions** (each with a recommendation, omitted when none).

Every plan writer applies it to the whole file **and to the chat response that presents the plan**:

- Fragments, not prose: no paragraphs, no full-sentence explanations.
- One idea per bullet; split a longer one into sub-bullets.
- _Decisions_ and _Risks_ as tables.
- Every open question carries **Rec:** with the recommended answer.
- Nothing after _Open Questions_. If there are no unresolved questions, note "None" (or omit).

### Link block

Every chat response that presents a plan starts with the `artifact-protocol` › _Chat link block_ (real line numbers from `grep -n '^#\{1,3\} ' <file>` after writing) linking `Context & Goal`, `Proposed Changes`, `Verification Plan` and `Open Questions`, followed by `**Status:** <value>`. A Command may append a one-line summary after each section link (`/plan --review` does).

---

## 2. Core Behaviors

Pick the case from the arguments, first match wins:

| Arguments            | Case               |
| -------------------- | ------------------ |
| Contain `--review`   | D: review a plan   |
| Start with `preview` | C: preview         |
| None                 | A: bare            |
| Anything else        | B: draft or update |

### Case A: Bare Command (`/plan` with no arguments or message)

1. **Locate the plan:** scan for `<prefix>-implementation_plan-*.md` in the artifact dir (`artifact-protocol`) and select the family per `artifact-protocol` › _Claim_ › _Readers & family selection_ (tell the user they can skip the prompt next time with `/plan <suffix>`). If none exists, say so and offer to create one from the user's next prompt.
2. **Render the link block** (_§1 Link block_) for the chosen plan, with its current `Status`. Do not edit anything or run background commands.

### Case B: Command With Instructions (`/plan <instructions>`)

1. **Resolve the contextual suffix** per `artifact-protocol` › rule 2.
2. **Plan, without changing code:**
   - **Check for an existing investigation first.** If `<prefix>-investigation-<suffix>.md` exists in the artifact dir (`artifact-protocol`) and covers this topic, build on it: its _Plan Seed_, _Options & Trade-offs_ and _Confidence Ledger_. Do not re-run research it already documents; do resolve any ❓ Unknown the plan depends on.
   - Otherwise research the relevant code read-only. If the topic is large or the unknowns are substantial, run [`/investigate`](../investigate/SKILL.md) first (or suggest `/investigate --to-plan`). When the change touches more than one file, run the research as two parallel lanes per `fan-out` › _Speed fan-out_, using [`../investigate/references/lane-briefs.md`](../investigate/references/lane-briefs.md) _Shared block_ with _Lane 2 — Prior art_ and _Lane 3 — Trace_, with the instructions in place of the Step 0 goal and questions.
   - Design to the project's own conventions: its workspace rulebooks, project-scoped References and Profile (`core` › _Precedence_).
3. **Write the plan** in the _§1 Skeleton_, in the artifact dir (`artifact-protocol`):
   - **New plan:** draft it in a session-private path, then publish it with _Claim_ (`artifact-protocol` › rule 4). If the base name is taken, Claim writes `…-2.md`; use the path it printed and say so in chat.
   - **Existing plan:** update it only if its owner marker names this session, or if the user named that file and asked for it to be updated (`artifact-protocol` › rule 3). Otherwise write a new revision through _Claim_, and link the one it supersedes in **Inputs**.
   - Set `Status` to `Awaiting User Review` when it is complete. Under Antigravity, when writing a mirrored artifact copy inside `<appDataDir>/brain/<conversation-id>/`, set `UserFacing = true` and `RequestFeedback = true` in `ArtifactMetadata` (omit `ArtifactMetadata` on the artifact dir file).
4. **Self-review before presenting:** read [`references/review.md`](references/review.md) and run _Case D_ steps 2–3 on the plan just written: step 2 in the main context, step 3 as `fan-out` › _Review lenses_ (inline below its threshold). Use its pillars and severities. Do not print its report or its gate: this is part of drafting, and the user reviews the folded plan.
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
5. **Present the plan:** the link block (_§1 Link block_), the review verdict and the findings that changed the design (one bullet each), the key decisions as fragment bullets, then the open questions last, each with its **Rec:** (_§1 Style_ applies to this chat text too: no paragraphs, no full sentences). Wait for the user to open the gate (`core` › _The `/proceed` gate_) before any code change.

### Case C: Preview Command (`/plan preview [target]`)

Shows an existing plan in the host's planning preview panel (using `ExitPlanMode` when available), so the user can read, comment on, and approve it interactively.

1. **Resolve plan:** Use argument (path or suffix), the session's active plan file, or the latest plan family in the artifact dir (Case A).
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

Wrong tool:

| Situation                                        | Use instead                                             |
| ------------------------------------------------ | ------------------------------------------------------- |
| A code diff, branch or PR rather than a plan     | [`/code-review`](../code-review/SKILL.md)               |
| Reviewer comments and votes on a PR              | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| Research before a plan exists                    | [`/investigate`](../investigate/SKILL.md)               |
| Hidden assumptions and failure modes of a design | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md)   |

Read [`references/review.md`](references/review.md) and execute _Case D_ steps 1–4 (step 1: locate plan; step 2: read project rules; _Case D step 3_: evaluate against the five pillars + profile _Plan-review checks_; step 4: render link block and review report), then wait at `core` › _The `/proceed` gate_.
