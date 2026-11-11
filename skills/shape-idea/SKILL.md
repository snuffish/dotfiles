---
name: shape-idea
description: "Turns a vague idea into an approved plan: gathers earlier decisions (artifacts, work state, PR threads on the target), checks claims against the code, grills the what and why, writes a short design doc, drafts it with /plan, grills the plan's open questions, and stops at /proceed. Use for /shape-idea, \"I have a rough idea\", \"help me think this through\". Not for clear instructions (use /plan), research (use /investigate), one decision (use /suggestion) or an explicit brainstorm (use /brainstorming)."
disable-model-invocation: true
argument-hint: "<vague idea> [--dry-run]"
---

# Skill: `/shape-idea` — Vague Idea → Approved Plan

Chains the steps that turn "I want to do something like X" into a plan the user has approved: earlier decisions, grounding, grilling, approaches, design doc, plan, and a last grilling round on the plan's gaps. It decides nothing the user does not see, and builds nothing.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`; used here: *Codebase investigation* (item 3, memory lookup) and *The `/proceed` gate*
- `../_modules/artifact-protocol.md`: writes `<prefix>-design-<suffix>.md`; used here: *Artifact directory*, *Rules* 1–4 (prefix, suffix, owner marker, Claim) and *Chat link block*. The plan itself is written by [`/plan`](../plan/SKILL.md)

On-demand references (`references/`):
- [`references/blind-replay.md`](references/blind-replay.md) — load when the idea changes what a review skill finds or how (passes, agents, rules, modes), not its wording

---

## Rules

- **Questions go through `AskUserQuestion`**: at most 4 per call, recommended option first, as [`/grill-me`](../grill-me/SKILL.md) asks. More open items → several calls. Approach picks and doc approvals are questions too.
- **Show your own calls.** Choices the user handed you are marked `(my call)` in the design doc and listed in the final reply, so they can be overruled.
- **The user's call beats an earlier decision.** When an answer contradicts an earlier decision (an artifact, a PR thread, a reviewer), say so once with its source; then follow the answer and record the override in the design doc.
- **Never ask what Step 1 or Step 2 answered.** Ask about consequences: "two members joined mid-round; do they vote?"
- **Explain a term before asking about it.** When an option names a concept the user has not used (a pass, a replay, an axis), give it one plain sentence first.
- **Redirect early.** If the change already fits one sentence naming its target file, stop and suggest [`/plan`](../plan/SKILL.md) with that sentence.

### `--dry-run`

For testing the skill:
- Answers come from the scripted user in the invoking prompt; a question the script does not cover takes the recommended option, marked `(dry-run default)`.
- Every file goes to `<scratchpad>/shape-idea-dry-run/` (the session scratchpad, or the folder the prompt names), named per `artifact-protocol` › *Rules* 1–2, with the owner marker but without *Claim*. The line after **Status:** reads `**Dry run** — scripted answers`.
- Sources the run skips are marked `skipped (dry run)`. Each grilling step runs one round unless the script raises more.
- No work-state or memory writes; nested skills run inline, `/plan`'s self-review included (no sub-agents).

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| The user already gave clear instructions for the change | [`/plan`](../plan/SKILL.md) |
| Only research: how something works, what a change would touch | [`/investigate`](../investigate/SKILL.md) |
| One decision with nameable options | [`/suggestion`](../suggestion/SKILL.md) |
| Surfacing the user's principles without a concrete idea | [`/grill-me`](../grill-me/SKILL.md) |
| A sharper prompt for another skill | [`/create-prompt`](../create-prompt/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Earlier decisions

Collect what is already decided about the idea's topic. This step satisfies `/grill-me`'s own earlier-work lookup.

1. **Artifact dir** (`artifact-protocol` › *Artifact directory*): `grep -il '<topic keyword>' <artifact-dir>/*.md` over contents, not only names; read design, plan, handoff and investigation hits.
2. **Work state and memory** (`core` › *Codebase investigation*, item 3): the claude-mem project the workspace rulebook names for where the session started; search both when it names two.
3. **PR threads on the target**: `git -C <repo> log --format='%h %s' -- <target paths>`; read the threads of the latest 5 PRs it names, per `pr-host` › *Fetch discussion threads*. Decisions often live in a resolved thread.

Done when each source is marked `read`, `n/a (<why>)` (a new feature has no target; a repo with no PRs) or `unreachable (<why>)`. List what each read source settled, one line each.

### Step 2: Ground the current state

Read the target and what it connects to until you can say how it works today and what the idea would touch.

- **Check every claim about the current state against the files before using it.** A gap claimed from memory ("X is not covered anywhere") is the most common wrong claim.
- **Look for what already does part of the idea**: a rule, check or step the idea would duplicate.
- **Evidence:** a presence claim carries `path:line`; an absence claim carries the grep and its scope, searching every file of the target (its skill folder, rules and references, not one file).

Done when each claim the design will rely on has its evidence.

### Step 3: Grill the what and why

Run [`/grill-me`](../grill-me/SKILL.md) rounds on the idea: what it is for, what success looks like, what it must not become, and the choices where the answer changes what gets built. Build each round on the last answers. When [`references/blind-replay.md`](references/blind-replay.md) applies, also settle the proof bar and what happens if it is missed.

Done when no open choice would still change the design, or the user says stop.

### Step 4: Approaches and design doc

1. Lay out two or three ways to build it, grounded in Step 2, with what each trades off and your pick, then ask the user to pick with `AskUserQuestion`.
2. Write `<prefix>-design-<suffix>.md` (`artifact-protocol` › *Claim*), never in the repository, at most ~80 lines:

   ```markdown
   <!-- artifact-owner: … -->
   # Design: <title>
   **Status:** Draft | Approved (<date>) · **Inputs:** <Step 1 sources>
   ## Intent            <why, in 2–3 lines>
   ## Goals, non-goals, anti-goals
   ## Constraints
   ## Approaches        <table: approach · trade-off · outcome>
   ## Decided design    <(my call) marks>
   ## Proof             <how it is shown to work, the bar, what happens if missed>
   ## Overrides         <earlier decision → user's call, with source; or "none">
   ## Left to the builder
   ```

3. Ask for approval with `AskUserQuestion` (approve / change <part>). After changes, ask again. Set **Status:** Approved.

### Step 5: Plan

Run [`/plan`](../plan/SKILL.md) with the design doc in its **Inputs**; its skeleton, style lint and self-review apply.

- Its *Verification Plan* says how the change is proven, not only written. When blind replay applies, plan it as its own phase.
- Before the most expensive phase (a long run, a replay, a migration), add a *Proposed Changes* line `Hand off before this phase`. No expensive phase → none.
- *Left to the builder* items are not *Open Questions*.

### Step 6: Grill the plan's open questions

Turn every item under the plan's *Open Questions* into `AskUserQuestion` rounds. Fold the answers into *Decisions* and *Proposed Changes*, then set *Open Questions* to "None". Done when it says "None".

### Step 7: Stop at the gate

List the principles behind the user's answers in Steps 3–6: the rule each choice follows, phrased so it applies next time ("prove before publishing", not "replay !18785"). Attach the design doc and plan to a work-state item as `work_product`, then end with `core` › *The `/proceed` gate* line.

---

## 3. Output Format & Deliverables

- `<prefix>-design-<suffix>.md` and the `/plan` artifact, both in the artifact dir.
- Final chat reply:

```markdown
<design doc chat link block>        (artifact-protocol › *Chat link block*)
<plan chat link block, with its Status>

**Principles you chose:**
1. <principle> — <one line why>

**My calls:** <each, one line> (or: none)
**Overrides:** <earlier decision> → <user's call> (or: none)

> **Next Step Gate:** Reply `/proceed` (or "go ahead") to run phases <n–m>, or specify scope/changes.
```

---

## 4. Verification & Validation

- Step 1 marks every source `read`, `n/a` or `unreachable`.
- Every claim the design relies on carries its evidence (Step 2).
- The design doc has *Approaches* with the user's pick and **Status:** Approved.
- The plan's *Open Questions* says "None", and its *Verification Plan* says how the change is proven.
- No file was edited outside the artifact dir (the scratchpad under `--dry-run`), and nothing was committed.
