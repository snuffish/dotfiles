---
name: pr-feedback-review
description: "Triages the discussion on a pull request: every reviewer thread, comment and vote, checked against the code at the PR head, with a triage category, its state at head, a recommendation and a ready-to-send reply per thread, in `<prefix>-pr_feedback_review-<suffix>.md`. Also triages the counterpart PR in a sibling repo, where a comment's fix often lands. `--deep` runs Verification, Merit and Impact as parallel sub-agents; `--ui` opens a localhost page to edit, accept or skip replies; reads from a detached snapshot (`live` opts out). Use for /pr-feedback-review, \"triage the PR comments\", \"what did the reviewers say?\", \"draft replies to the threads\"."
argument-hint: "[--deep] [--ui] [live] [<target>]"
---

# PR Feedback Review Skill

Triages pull request reviewer comments, threads, and votes against the code at the PR head, evaluates technical merit and downstream impact, and drafts actionable fix paths and replies.

---

## Invariants

1. **Artifact and summary:** every `/pr-feedback-review` writes `<prefix>-pr_feedback_review-<suffix>.md` in the artifact dir (`artifact-protocol`) and opens its chat response with the `artifact-protocol` › *Chat link block*. Never substitute `<prefix>-implementation_plan-<suffix>.md` for the feedback review artifact.
2. **Read-only:** never edit code, stage commits, run migrations, post replies, or modify the main checkout; the only files written are the artifact and its `--ui` siblings (`core` › *The `/proceed` gate*, `git-worktrees` › *Snapshot Lifecycle*).

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-pr_feedback_review-<suffix>.md`
- `../_modules/git-worktrees.md`: snapshot by default
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`
- `../_modules/project-profile.md`: base profile only (`<project>-profile`); reads *Tracker*, *PR tooling*, *References per layer*, *Contract touchpoints*, *Report language*, and *Known drift*
- `../_modules/fan-out.md`
- `../_modules/outward-writes.md`: *Voice pass* only for drafted replies

- Without an incoming `[worktree-context]` block, `repo-root` is the snapshot created in *Step 2.3*.

---

## Project profile

Load `<project>-profile` before Step 1 when the workspace matches its gate (`project-profile` › *Discovery*) and resolve the fields listed in *Modules*:
- **Tracker** and **PR tooling** select `<org-url>`, repo IDs, and the thread-fetch tool.
- **References per layer**, **Contract touchpoints**, and **Known drift** guide Step 3 technical evaluation.
- **Report language** sets the language of the artifact and drafted replies.

Record the loaded profile (or `none`) in the artifact header's **Profile** line.

---

## Modes

| Invocation | Mode | How the axes run |
|---|---|---|
| `/pr-feedback-review [target]` | **Standard** (default) | Single pass covering Verification, Merit, and Impact (Steps 3–5) |
| `/pr-feedback-review --deep [target]` | **Deep** | Verification, Merit, and Impact run in parallel sub-agents ([deep-mode.md](references/deep-mode.md)), then aggregate |
| `/pr-feedback-review live [target]` | Standard or deep, **no snapshot** | Reads the main checkout directly (same as `/no-wt`) |
| `/pr-feedback-review --ui [target]` | Any mode, plus a **review page** | After publish, a localhost page edits, accepts or skips each reply ([ui-mode.md](references/ui-mode.md)); combinable with `--deep` and `live` |

Every thread is assessed on three axes:
- **Verification**: what does the code at *head* do about this thread (addressed, partial, not addressed, superseded; commit, `path:line`, and test)?
- **Merit**: is the reviewer right, and is their proposed fix sound against the code and framework semantics?
- **Impact**: what else does acting on it touch (stacked branches, linked work items, cross-repo contracts, other callers, competing threads, prior decisions)?

Suggest `--deep` (`fan-out` › *Bare vs deep*) when there are >10 active threads, threads anchored to older iterations, or complex alternative implementations proposed by reviewers.

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Reviewing the PR's code yourself | [`/code-review`](../code-review/SKILL.md) |
| The PR's build validation is red | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |
| Writing or refreshing the PR description | [`/pr-desc`](../pr-desc/SKILL.md) |
| How to try the change by hand | [`/manual-testing`](../manual-testing/SKILL.md) |

---

## Step 1 — Determine the Target PR & Counterpart

1. **Resolve the target PR** from a URL, bare ID, or current branch per `pr-host` › *Parse a PR or work-item URL*, *Organization URL*, and *Resolve the PR from a branch*.
2. **Counterpart lookup**: run `pr-counterpart` › *Counterpart discovery* for every resolved PR:
   - **Found** → joins the scope automatically; Steps 2–5 run for every PR in scope, and cross-repo threads are assessed against both snapshots.
   - **Found, excluded** → triage only the named PR; record the counterpart, its head, and open-thread count in the header, and flag contract-touching threads.
   - **Expected but missing** → add an action-checklist item noting the missing repo PR.
   - **None** → record `single-repo change` in the header.

---

## Step 2 — Fetch PR Metadata, Reviewers & Discussion Threads

### 2.1 — PR Details, Reviewer Votes & Threads
1. Fetch PR metadata, linked work items, reviewer votes (`10` Approved, `5` Approved w/ suggestions, `0` No vote, `-5` Waiting, `-10` Rejected), and discussion threads per `pr-host` › *Fetch the PR, its work items and acceptance criteria* and *Fetch discussion threads* ([pr-host-threads.md](../_modules/references/pr-host-threads.md)).
2. **Save the dump**: write the raw JSON and filtered human threads to `<scratchpad>` (`threads.json`, `threads-human.txt`), recording each thread's status, `file:line`, and `iterationContext`.
3. **Capture the selected code**: quote the lines the reviewer selected at the iteration commit per [selected-code.md](references/selected-code.md).

### 2.3 — Pin the Head in a Snapshot

Follow `git-worktrees` › *Snapshot Lifecycle* ([git-worktrees-snapshot.md](../_modules/references/git-worktrees-snapshot.md), `<skill>=pr-feedback-review`) to snapshot the remote PR head per repo:

```bash
git -C <repo> fetch origin <sourceBranch> <targetBranch>
git -C <repo> rev-parse origin/<sourceBranch>                 # <head-sha>, the source ref
git -C <repo> rev-parse --abbrev-ref HEAD                      # main checkout's branch
git -C <repo> rev-list --left-right --count <head-sha>...HEAD  # "<behind> <ahead>"
```

Compare `HEAD_SHA` with the PR's `lastMergeSourceCommit` from Step 2.1; if they differ, the PR moved during the fetch — re-fetch.

---

## Step 3 — Investigate Codebase Context & Related PRs

1. **Inspect targeted code**: use the host's file-reading and search tools (`Read`/`Grep` or `codegraph`) to inspect the cited files, classes, queries, and callers inside `$SNAP_DIR`, not the main checkout.
2. **Check downstream & stacked dependencies**:
   - Check for stacked branches branching off this PR.
   - Check linked work items (`az repos pr work-item list --id <prId> --org <org-url>` and `az boards work-item show --id <id> --org <org-url>`).
   - Check the counterpart PR snapshot when a thread touches a shared contract.
3. **Assess technical & architectural constraints**: database/migration safety, layer conventions (*References per layer*), authorization/query filters, and API contract compatibility (*Contract touchpoints*).

**Verification lanes (Standard mode).** With more than 2 active human threads, or a counterpart PR in scope, group them by the file they anchor to (general threads join the group whose code they discuss; a counterpart PR's threads form their own group against its snapshot; at most 4 groups) and run the Verification axis per group as `Explore` lanes per `fan-out` › *Speed fan-out*. Each lane gets the snapshot `[worktree-context]`, the paths of `threads-human.txt` and the selected-code quotes from Step 2, and its thread IDs, and returns per thread its *State at head* value (6.4) with commit and `path:line`. Merit, Impact and the replies stay in the lead. Run inline with 2 or fewer threads and no counterpart.

---

## Step 4 — Triage & Technical Assessment

Assign each thread one triage category (distinct from `/code-review` 🔴/🟡/🟢 severities):
- ⛔ **Blocking**: a real defect (data integrity, race condition, security gap, broken requirement) that blocks merge on its merits.
- 💡 **Proposal**: an alternative pattern, simplification, refactoring, or design question requiring trade-off evaluation.
- ✏️ **Polish**: naming, style, docstring, or a small test addition.
- ⚪ **Info**: rationale questions, converged discussions, or automated notices.

Record the reviewer's vote (`-5`, `-10`, etc.) in the **Vote** column rather than inflating the category (a `-5` on a naming nit stays ✏️ Polish).

---

## Step 5 — Formulate Actionable Paths & Draft Replies

For every non-trivial thread:
1. **State the underlying motivation** (what risk or smell the reviewer is targeting).
2. **Evaluate trade-offs** (pros vs. migration/rebase/contract risks).
3. **Provide concrete decision options**:
   - **Path A (Direct Fix / Refactor Now)**: exact steps and `diff` block.
   - **Path B (Clarify / Defer to Follow-up)**: rationale for keeping current code or deferring to a follow-up work item.
4. **Draft a ready-to-send reply** in the PR conversation's language (unless overridden by the profile's *Report language* field), then run it through `outward-writes` › *Voice pass* and mark it `Voice pass: done`.

---

## Step 6 — Artifact Management & Output Format

1. Publish `<prefix>-pr_feedback_review-<suffix>.md` in the artifact dir (`artifact-protocol`) via `artifact-protocol` › *Claim*, following the template in [artifact-template.md](references/artifact-template.md), then remove the snapshot(s).
2. Begin the chat response with the `artifact-protocol` › *Chat link block*, followed by a concise summary of reviewer votes, blocking/open thread counts, and the closing gate line (`core` › *The `/proceed` gate*).

3. **`--ui`**: after publish, follow [ui-mode.md](references/ui-mode.md) before the chat summary; the chat link block adds the `.answers.json` sibling.

### 6.4 — Status fields

The artifact tracks thread progress across five **status fields** (`artifact-protocol` › *Rules* › rule 3 & rule 7):
1. Header **Status:** line (votes, active/resolved counts);
2. **Executive Summary** opening claim;
3. Triage matrix **State at head** column (`✅ Fixed (<sha>)` · `🕓 Fixed, not pushed (<sha>)` · `◐ Partial` · `⏸ Not addressed` · `↩ Superseded` · `⚪ n/a`);
4. Each thread's **Status:** line;
5. **Action Checklist** items.

Update all five together whenever a later step (`/proceed`, push, `/pr-post-comments`) changes thread state. Preserve historical *Technical Analysis* by appending a dated `Update <date>:` line under *State at head (iteration <n>)*.

---

## Deep Mode

For `/pr-feedback-review --deep`, read [deep-mode.md](references/deep-mode.md) before spawning sub-agents.

---

## Heuristics & Common Pitfalls

- **Map every thread to head, not its iteration**: re-find moved code at head before judging whether a thread is addressed.
- **Verify "addressed" in code, not commit messages**: confirm the exact requested test, overload, or guard exists.
- **Evaluate the reviewer's proposed fix independently**: if the branch solved the concern differently or the reviewer's snippet introduces a bug, explain the concrete sequence in the draft reply.
- **Flag stacked-branch rebase impact** whenever a thread asks for a broad rename or refactor.
