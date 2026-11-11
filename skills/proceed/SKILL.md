---
name: proceed
description: "Authorizes and executes the next step of a gated read-only command."
disable-model-invocation: true
argument-hint: "[artifact | all | option | phase | step | extra instructions]"
model: sonnet
effort: low
---

# Skill: `/proceed` — Open the Execution Gate

The user's explicit authorization for the work a read-only Command stopped in front of (see `core` › _The `/proceed` gate_). It finds what is waiting, does the next step the gated Command named, verifies it and reports back — nothing beyond that.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/git-worktrees.md`: whenever the pending item implements a plan (Step 2 › _Plan implementation runs in a worktree_), and when `/wt`, a `[worktree-context]` block, `/implement-feature`, or a base profile with `Implementation mode: workspace` applies (`core` › _Worktree opt-in_). Skip it only under `/no-wt`

Follow `core` › _The `/proceed` gate_ for all gate invariants; `disable-model-invocation` keeps the model from calling this Command itself.

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the pending item

Look back through this session for the most recent gated handoff that has not yet been executed. **Any** Command whose `## Modules` section marks `core` read-only until `/proceed` leaves one: the next step its output named. The table lists the common ones as examples; for a Command not listed, do exactly the next step it named.

| Gated by                            | What it left waiting                                 | Next step `/proceed` authorizes                                                                                                                                                                                                                                  |
| ----------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `code-review`, `squash-code-review` | A verified review                                    | Fix the findings the user picks (all 🔴 by default): through `/plan` when non-trivial, otherwise directly. Posting them to the PR is `/pr-post-comments`, a separate request                                                                                     |
| `pr-feedback-review`                | A thread triage with resolutions and draft replies   | Apply the agreed code resolutions. Sending replies is `/pr-post-comments`, a separate request                                                                                                                                                                    |
| `spec-verification`                 | A traceability ledger with gaps                      | Close the _missing_ / _partial_ requirements the user picks                                                                                                                                                                                                      |
| `what-am-I-missing`                 | One blind spot with an _Immediate Fix_               | Apply that fix                                                                                                                                                                                                                                                   |
| `verify-assumptions`                | _Proposed edits (after /proceed)_                    | Apply exactly those edits to the plan, ADR or doc                                                                                                                                                                                                                |
| `explain`, `manual-testing`         | An explanation or a test plan                        | Only the follow-up step their output named, if any; otherwise _Nothing pending_                                                                                                                                                                                  |
| `create-prompt`                     | Paste-ready prompt                                   | Run the printed prompt (with `--variants`: the one the arguments pick, default the recommended) by invoking its target skill; that skill's own gates still apply. Opens **only** on a literal `/proceed`, never on a plain "go ahead" (`create-prompt` › _Gate_) |
| `plan --review`                     | A plan or proposal with a verdict                    | Implement the reviewed plan, applying its 🔴 findings first                                                                                                                                                                                                      |
| `implement-feature`                 | The plan gate                                        | Resume `implement-feature` at its implementation phase                                                                                                                                                                                                           |
| `suggestion`                        | Numbered approaches with a recommendation (option 1) | Act on option 1, or the option a bare number in the arguments picks (`/proceed 2`): through `/plan` when the change is non-trivial, otherwise directly                                                                                                           |
| `investigate`                       | Findings with a handoff                              | Draft the plan with `/plan`; implementing it needs a further `/proceed`                                                                                                                                                                                          |
| `plan`                              | A plan in `Awaiting User Review`                     | Implement the plan                                                                                                                                                                                                                                               |
| `handoff`                           | A handoff artifact (`<prefix>-handoff-<suffix>.md`)  | Execute the pending next steps named in the handoff                                                                                                                                                                                                              |
| `simplify-branch`                   | A matrix of simplify candidates (rows `A`, `B`, …)   | Run `/simplify` on the rows the arguments pick (the ✓ rows by default; `/proceed A,C`, `/proceed all`), each scoped to its files. Never commits                                                                                                                  |

Then:

- **Named artifact in arguments**: when the user provides an artifact (e.g. `/proceed <prefix>-handoff-<suffix>.md` or `/proceed <prefix>-implementation_plan-<suffix>.md`), resolve the pending item directly from the named artifact file on disk without requiring prior in-session transcript context. A bare filename resolves per `artifact-protocol` › *Artifact directory* (artifact dir first, then cwd).
- **Nothing pending** → say so in one line and stop. Do not invent work.
- **More than one pending item** → list them (Command, artifact link, one line each) and ask which one. Do not guess.
- **Verdict `NEEDS REVISION` or `BLOCKED`** → name the blocking findings in one line each and ask whether to proceed anyway, fix them first, or stop — unless the arguments already say.
- **Arguments** (`option 2`, `phase 1 only`, `skip the refactor`, extra constraints) narrow or pick the scope. If they conflict with the plan, ask.

Re-read the plan artifact from disk before acting; the user may have edited it after the gate closed.

Work inline: start no subagents unless the plan names one, or Step 2 qualifies for *Edit lanes*.

### Step 2: Execute & Verify

1. **Mark approved**: set the plan's `Status` to `Approved` (`core` › _The `/proceed` gate_).
2. **Execute**: follow the plan's phases in order, staying inside its scope and applying the project's References and Profiles (`core` › _Precedence*). Honour an active `[worktree-context]`, `core` › _Worktree opt-in_, and the base profile's **Implementation mode** (`git-worktrees` › _Modes_).
   - **Plan implementation runs in a worktree**: when the pending item implements a plan (the `plan`, `plan --review` and `implement-feature` rows, a handoff whose next steps are plan phases, or a fix routed through `/plan`), run it in a **workspace** worktree (`git-worktrees` › _Workspace Lifecycle_) as if `/wt` were given. Only `/no-wt` in the arguments runs it in place. A plan or handoff that names a kept worktree continues in that worktree, and the handoff's **Worktree:** line records its path.
   - **One phase per run**: when the pending item has several phases or numbered next steps (a plan, a handoff), do only the first unfinished one. Verify it (step 3), close out (step 4), then stop and wait; never start the next phase in the same turn. Edit lanes and a `/suggestion` option are one item, not phases.
   - **`/proceed all`** bypasses that halt: do every remaining phase in order in this run, with no stop and no handoff between phases, even when the source artifact's working rules say one phase per run. Verify once at the end (step 3) and close out once (step 4). `/proceed phases 3-4` does the same for the phases it names. Stop early only for a failed verification or a decision that is the user's.
   - **Edit lanes**: when the approved items are independent fixes (a review's findings, a fix list, a thread triage's resolutions) that meet the threshold in [`fan-out`](../_modules/fan-out.md) › _Edit lanes_, apply them as edit lanes per that section, then continue with step 3. Never for a plan whose phases build on each other, and never when resuming `implement-feature` (its Phase 3 forbids fan-out).
3. **Verify once, at the end**: run the plan's own verification commands. Only when the plan names none, run one targeted build/type-check and the tests covering the changed files. Never re-run a suite that already passed on the same code, and don't verify per phase unless the plan says so. When the commands cover independent parts (backend and frontend, two repos), start the slowest with `run_in_background` and run the rest meanwhile; draft the close-out while they run.
4. **Close out**: update the plan's `Status` (`Completed` or `Approved` with remaining items per `core` › _The `/proceed` gate_) and, in the same edit, every status field the source artifact's Command declares (header `Status:`, summary matrix, per-item status, checklist); then `grep` for `⏸`, `Not addressed`, `uncommitted` and resolve every hit.
5. **Hand off when the run stops with phases remaining** (not under `/proceed all`, unless context runs low): first offer the commit for the finished phase and wait for the answer, so each commit holds one phase and the handoff names final SHAs. Then run [`/handoff`](../handoff/SKILL.md) so a fresh session can do the next phase. Update the handoff this run started from in place when there is one, else write a new one. The output's `Next:` line is then `/proceed <handoff path>`.

---

## 3. Output Format & Deliverables

Chat response, short:

```markdown
✅ Proceeded: <what was approved> — 📄 [<plan>](link)

- <phase / change>: <file links> · verified by `<command>` ✅/❌
- Not done: <out-of-scope or user-owned items, e.g. re-queue run, commit, push>

Next: <the single next action, usually a commit/push or ship command for the user to request>.
```

---

## 4. Verification & Validation

- [ ] The pending item was resolved from this session, not guessed; ambiguity was asked about.
- [ ] Only the authorized scope was changed; no commit, push, PR or tracker write happened without its own request, and no edit landed in a snapshot worktree.
- [ ] A plan implementation ran in a workspace worktree, unless the arguments held `/no-wt`.
- [ ] Verification commands ran and their results are reported faithfully.
- [ ] With phases remaining: only one phase ran (unless `/proceed all` or a phase range widened it), the commit for it was offered before the handoff, and a handoff naming the next phase was written or updated.
- [ ] Under `/proceed all`: every remaining phase ran without a halt or a handoff in between.
- [ ] The plan's `Status` and every status field in any source review artifact match reality (Step 2.4).
