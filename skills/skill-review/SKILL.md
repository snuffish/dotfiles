---
name: skill-review
description: 'Audits one skill (its SKILL.md and references/) against the code and the writing standard, folds in findings from an earlier code review or handoff after re-checking each at HEAD, and writes a fix list ordered by what to apply first. Use for /skill-review, "review this skill", "audit the skill", "is this skill still right?", "fix list for the skill". Not for a diff (use /code-review), claim drift alone (use /skill-drift), logged gaps (use /skill-gap) or a plan (use /plan --review).'
argument-hint: "<skill folder> [--inputs <review|handoff>…] [--ref <sha|branch>] [/worktrees]"
---

# Skill: `/skill-review` — Skill Audit & Fix List

Reviews one skill as a document an agent consumes: do its pointers fire, are its claims true in the code, is it structured and sized right. It re-checks every finding handed in against the code at HEAD, runs the lenses those findings missed, and writes a fix list ordered by what to apply first. The fixes are a separate step.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-skill_review-<suffix>.md` (suffix: the skill name, e.g. `-priis-backend-review`)
- `../_modules/git-worktrees.md`: snapshot by default; the target skill is read at a pinned ref

Read this only when an input is a pull request or work item:

- `../_modules/pr-host.md`: read-only, to resolve the PR, its threads and the work item

On-demand references (`references/`):

- [`references/lenses.md`](references/lenses.md) — step 3: the check, evidence command and example for each lens
- [`references/report-template.md`](references/report-template.md) — step 5: the artifact skeleton, status key and matrix columns

Load the writing standard before step 2: the `writing-for-agents` skill and its `SKILL-MECHANICS.md`. A project profile may add a `Skill-review checks` field (drift script, size budget, CI gate, text that repo skills must not name); read it when one exists.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Reviewing a code diff or PR | [`/code-review`](../code-review/SKILL.md) |
| Only claim drift (FAIL / STALE rows) | [`/skill-drift`](../skill-drift/SKILL.md) |
| Working through logged skill gaps | [`/skill-gap`](../skill-gap/SKILL.md) |
| Auditing a plan before code is written | [`/plan --review`](../plan/SKILL.md) |
| Applying the fixes | `/proceed` after this run |

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the target and its inputs

1. Name the **target**: a skill folder (`SKILL.md` plus `references/*.md`). Pin the **ref** to review: `--ref`, else the current `HEAD` SHA. Read it from a snapshot (`git-worktrees` › *Snapshot Lifecycle*) when the user may be editing the checkout.
2. List the **inputs**: code reviews, handoffs, PR threads or a user list of findings for this skill, from `--inputs`, the artifact dir (`artifact-protocol`) or the conversation. Do not open them yet. Inputs may be none.
3. Name the **source heads**: when an input depends on a PR that has not merged, record its head SHA. Read it with `git show <sha>:<path>`.
4. Note the **change scope** the user set (which repos and files fixes may touch). Without one, ask.

Done when the target, ref, input list, source heads and change scope are each written down.

### Step 2: Independent pass first

Run the lenses in [`references/lenses.md`](references/lenses.md) on the target **before** reading any input. This keeps the audit independent (`artifact-protocol`, *Independence rule*); skip that order only when the user asks to reconcile.

Done when every lens has either findings with `path:line` evidence or a *Checked, no finding* line saying what was checked.

### Step 3: Re-check every input finding at HEAD

Open the inputs now. Give each finding one status, proven with a command at the pinned ref:

| Status | Meaning |
|---|---|
| **confirmed** | True at HEAD |
| **latent** | True at HEAD, wrong once a source PR merges |
| **stale** | Already fixed |
| **wrong** | The finding or its proposed fix does not hold |

Test a proposed fix as well as the finding: a rename, move or merge is checked against every consumer (`git grep` for the names and section anchors involved, in this skill and in sibling skills) before it is accepted. A finding the independent pass also made keeps one row, marked with both sources.

Done when every input finding has a status and evidence, and every *wrong* one names what breaks.

### Step 4: Run the lenses the inputs missed

Re-read [`references/lenses.md`](references/lenses.md) against the inputs' coverage. A lens no input touched gets a fresh look at the target, with fresh `path:line` evidence. New findings carry source `new (<lens>)`.

### Step 5: Self plan-review the fix list

Before writing, check the list the way `/plan --review` would:

1. **Scope**: every fix lands inside the change scope from step 1; one that cannot goes to *Drop* with the reason.
2. **Single source of truth**: each fact ends up written in one place; a fix that adds a second copy is rewritten.
3. **Verification**: a command per fix class, including the drift re-extract when a fix moves text that claims cite by line.
4. **Decisions**: each open question carries a **Rec**. Resolve those the user's earlier answers already settle.
5. **Size**: estimate the body bytes after the fixes against the budget.

Done when the list passes all five or each failure is a written finding.

### Step 6: Write the artifact

Fill [`references/report-template.md`](references/report-template.md). Order fixes by what to apply first: mechanical and load-point fixes, then wrong claims, then triggers, then minor structure; `later` and `drop` last. Draft in the scratchpad, publish with the claim step in `artifact-protocol`, then print the chat summary and the link block (`artifact-protocol` › *Chat link block*).

---

## 3. Output Format & Deliverables

Chat, short: scope and ref, counts by decision (now / later / drop), the two or three fixes that matter most, any open Decision, then the gate.

Artifact: `<prefix>-skill_review-<suffix>.md`, laid out by the report template.

> **Next Step Gate:** Reply `/proceed` (or "go ahead") to apply the `now` fixes, or specify scope/changes. Posting findings to a PR is `/pr-post-comments`, a separate request.

---

## 4. Verification & Validation

- [ ] Every finding has `path:line` evidence from the pinned ref; no finding rests on a name alone.
- [ ] The independent pass ran before the inputs were opened.
- [ ] Every input finding has a status; every *wrong* one names what breaks.
- [ ] Every fix has a decision and an effort; the artifact has *Verification* and *Decisions* sections.
- [ ] Shell: `git grep` and `git ls-files` for searches (`ls` and `g`/`gg` may be aliases: use `command ls`, and don't name shell functions `g` or `gg`); no file was edited, nothing committed or posted.
