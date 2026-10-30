---
name: proceed
description: "Authorizes and executes the next step of a gated read-only command."
disable-model-invocation: true
argument-hint: "[option | phase | step | extra instructions]"
---

# Skill: `/proceed` — Open the Execution Gate

The user's explicit authorization for the work a read-only Command stopped in front of (see `core` › _The `/proceed` gate_). It finds what is waiting, does the next step the gated Command named, verifies it and reports back — nothing beyond that.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — updates the `Status` of the plan it executes
- `../_modules/git-worktrees.md`

The rules of the gate are `core` › _The `/proceed` gate_: one item only, no outward-facing actions by implication, `Status` follows reality, verify, never edit a snapshot. They apply whether the user typed `/proceed` or a plain "go ahead". This Command adds the explicit resolution and reporting steps below. `disable-model-invocation` keeps the model from calling it.

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the pending item

Look back through this session for the most recent gated handoff that has not yet been executed. **Any** Command whose `## Modules` section marks `core` read-only until `/proceed` leaves one: the next step its output named. The table lists the common ones as examples; for a Command not listed, do exactly the next step it named.

| Gated by                            | What it left waiting                                 | Next step `/proceed` authorizes                                                                                                                                                                                                              |
| ----------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `code-review`, `squash-code-review` | A verified review                                    | Fix the findings the user picks (all 🔴 by default): through `/plan` when non-trivial, otherwise directly. Posting them to the PR is `/pr-post-comments`, a separate request                                                                 |
| `pr-feedback-review`                | A thread triage with resolutions and draft replies   | Apply the agreed code resolutions. Sending replies is `/pr-post-comments`, a separate request                                                                                                                                                |
| `spec-verification`                 | A traceability ledger with gaps                      | Close the _missing_ / _partial_ requirements the user picks                                                                                                                                                                                  |
| `what-am-I-missing`                 | One blind spot with an _Immediate Fix_               | Apply that fix                                                                                                                                                                                                                               |
| `verify-assumptions`                | _Proposed edits (after /proceed)_                    | Apply exactly those edits to the plan, ADR or doc                                                                                                                                                                                            |
| `explain`, `manual-testing`         | An explanation or a test plan                        | Only the follow-up step their output named, if any; otherwise _Nothing pending_                                                                                                                                                              |
| `create-prompt`                     | Paste-ready prompt variants                          | Run the variant the arguments pick (default: the recommended one) by invoking its target skill; that skill's own gates still apply. Opens **only** on a literal `/proceed`, never on a plain "go ahead" (`create-prompt` › _Execution Gate_) |
| `plan --review`                     | A plan or proposal with a verdict                    | Implement the reviewed plan, applying its 🔴 findings first                                                                                                                                                                                  |
| `pr-fix-pipeline`                   | An investigation and an `implementation_plan`        | Implement the fix plan, run local verification, push/re-queue, and iterate until the pipeline is verified passed by the agent                                                                                                                |
| `implement-feature`                 | The plan gate                                        | Resume `implement-feature` at its implementation phase                                                                                                                                                                                       |
| `suggestion`                        | Numbered approaches with a recommendation (option 1) | Act on option 1, or the option a bare number in the arguments picks (`/proceed 2`): through `/plan` when the change is non-trivial, otherwise directly                                                                                       |
| `investigate`                       | Findings with a handoff                              | Draft the plan with `/plan`; implementing it needs a further `/proceed`                                                                                                                                                                      |
| `plan`                              | A plan in `Awaiting User Review`                     | Implement the plan                                                                                                                                                                                                                           |

Then:

- **Nothing pending** → say so in one line and stop. Do not invent work.
- **More than one pending item** → list them (Command, artifact link, one line each) and ask which one. Do not guess.
- **Verdict `NEEDS REVISION` or `BLOCKED`** → name the blocking findings in one line each and ask whether to proceed anyway, fix them first, or stop — unless the arguments already say.
- **Arguments** (`option 2`, `phase 1 only`, `skip the refactor`, extra constraints) narrow or pick the scope. If they conflict with the plan, ask.

Re-read the plan artifact from disk before acting; the user may have edited it after the gate closed.

### Step 2: Mark it approved

If the item is a plan artifact with a `Status` line, set it to `Approved`.

### Step 3: Execute

- Follow the plan's phases in order. Stay inside its scope; anything the plan did not foresee that changes scope is a question, not a decision.
- Apply the project's References and Profiles for the code being touched (`core` › _Precedence_).
- When the next step belongs to another Command (`/plan`, `implement-feature`), invoke it and let it run under this authorization.
- Honour an active `[worktree-context]` and `core` › _Worktree opt-in_.
- Before the first edit, resolve the base profile's **Implementation mode** (`git-worktrees` › _Modes_); `workspace` → edit in a workspace worktree, not the main checkout.

### Step 4: Verify

Run `core` › _Post-edit verification_: the plan's own verification commands first, then the targeted build, type-check and tests for what changed. Fix failures before reporting; if one cannot be fixed within scope, stop and report it with its output.

### Step 5: Close out

Set the plan's `Status` to `Completed` when every phase in scope is done and verified; leave it `Approved` and note what remains when only part of the scope ran.

When the item came from a review artifact (`pr_feedback_review`, `code_review`), recording the work there means updating every **status field** that artifact's Command declares (`artifact-protocol` rule 7), not only its checklist. A fix that is not yet pushed is 🕓 Fixed, not pushed (`<sha>`); a fix becomes ✅ only once it is at the PR head. Before reporting, `grep` the artifact for the old markers (`⏸`, `Not addressed`, `uncommitted`) and resolve every stale hit.

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
- [ ] Only the authorized scope was changed; no commit, push, PR or tracker write happened without its own request.
- [ ] No edit landed in a snapshot worktree.
- [ ] Verification commands ran and their results are reported faithfully.
- [ ] The plan's `Status` reflects what actually ran.
- [ ] A review artifact the work came from shows the same state in every status field: the header, the matrix, the per-item lines and the checklist.
