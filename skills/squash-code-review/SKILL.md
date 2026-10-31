---
name: squash-code-review
description: "Squashes and reconciles multiple code review artifacts for the same change into a single verified report. Resolves conflicting findings by verifying against code at the PR head, integrates active PR comment threads, and produces a deduplicated findings matrix."
---

# Skill: `/squash-code-review` — Squash Code Reviews

Reconciles two or more code reviews of the same change into one verified review (`<prefix>-squashed_code_review-<suffix>.md`), settling disagreements against the code at the pinned head and folding in PR discussion threads.

---

## Invariants

1. **Mandatory artifact:** writes `<prefix>-squashed_code_review-<suffix>.md` at the workspace root and opens chat with the `artifact-protocol` › *Chat link block*.
2. **Never edit a source review:** source artifacts stay byte-for-byte intact.
3. **Sources are evidence, not verdicts:** every 🔴/🟡 passes [`/code-review`](../code-review/SKILL.md) › *Step 6 — Verify Every 🔴 and 🟡* at the pinned head.
4. **Conservation:** every source finding is accounted for in a squashed finding, a minor finding, or a *Refuted / dropped* row.
5. **Read-only:** no code edits, commits, posting, voting, or thread resolution (`core` › *The `/proceed` gate*, `git-worktrees` › *Snapshot Lifecycle*).

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-squashed_code_review-<suffix>.md` (suffix: the sources' shared suffix)
- `../_modules/git-worktrees.md`: snapshot by default
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`
- `../_modules/fan-out.md`

- Also read [`code-review`](../code-review/SKILL.md) and its [review-artifact-template.md](../code-review/references/review-artifact-template.md) for axes, severities, verification, and section order.
- Reading multiple models' reviews is the purpose of this Command (`artifact-protocol` › *Claim* › *Independence rule* exception).

---

## Modes

| Invocation | Mode | What happens |
|---|---|---|
| `/squash-code-review [sources]` | **Standard** | One pass: match, verify, reconcile, fold in threads |
| `/squash-code-review deep [sources]` | **Deep** | Contested clusters are verified by parallel read-only sub-agents (*Deep Mode*), then aggregated |
| `/squash-code-review feedback [sources]` | Standard or deep, **full thread triage** | Runs [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) first, then squashes against its triage matrix |
| `… live …` | **No snapshot** | Reads the main checkout instead of a pinned snapshot |

### When *not* to use

| Situation | Use instead |
|---|---|
| Only one review exists, or you want a fresh review | [`/code-review`](../code-review/SKILL.md) |
| You want to triage what human reviewers wrote on the PR | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| The squashed findings are ready to go on the PR | [`/pr-post-comments`](../pr-post-comments/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1 — Resolve the sources

| User passes | Sources |
|---|---|
| Two or more `@file` paths | Those files |
| A PR id, PR URL or suffix | Every `*code_review-<suffix>*.md` at the workspace root for that PR, across hosts and models |
| Nothing | The current branch's PR (`pr-host` › *Resolve the PR from a branch*), then as above |

- Fewer than two sources, or sources for different PRs/changes → stop and report what was found.
- Exclude earlier `squashed_code_review` files as inputs unless explicitly named by the user.
- Assign each source a letter key in discovery order (`A`, `B`, …) and record file, host/model, mode, date, and **head reviewed**.

### Step 2 — Pin the head and measure drift

- Resolve the PR(s) and counterpart(s) (`pr-host` › *Resolve the PR from a branch* and *Fetch the PR, its work items and acceptance criteria*, `pr-counterpart` › *Counterpart discovery*). Pin the current head per repo (`git-worktrees` › *Snapshot Lifecycle*, or object-store reads `git -C <repo> show <sha>:<path>` when only targeted lines are checked).
- Compare each source's head to the pinned head (`git -C <repo> diff --stat <source-head> <pinned-head>`): record `same head` or `N commits since`, and re-locate findings in changed files.

### Step 3 — Fold in the PR discussion

1. If a `*pr_feedback_review-<suffix>*.md` at the workspace root matches the pinned head, reuse its triage matrix.
2. Otherwise fetch threads read-only per `pr-host` › *Fetch discussion threads* ([pr-host-threads.md](../_modules/references/pr-host-threads.md)) for every PR in scope.
3. Also read each source's *Posted to PR* row to map posted thread IDs back to their source findings.
4. Record per thread: ID, `file:line`, author, status, and *State at head* (`✅ Fixed` · `◐ Partial` · `⏸ Not addressed` · `↩ Superseded` · `⚪ n/a`). If fetching fails, continue without threads and say so.

### Step 4 — Match findings into clusters

Group every source finding (🔴, 🟡, 🟢, and Refuted rows) into **clusters by root cause**:
- **Same cluster**: same defect at the same place (even if worded or rated differently).
- **Conflicting cluster**: contradictory claims about the same code.
- Attach matching PR threads; an open defect-raising thread that matches no source finding becomes cluster `T#<id>`.
- Classify each cluster: **agreed**, **single-source**, **conflicting**, or **severity split**.

### Step 5 — Settle every cluster in code

Apply [`/code-review`](../code-review/SKILL.md) › *Step 6 — Verify Every 🔴 and 🟡* and *Step 6b — Fold In PR Feedback* at the pinned head:
1. Re-open the cited code at the pinned head and settle factual disagreements via `git show` / `git grep` across both repos.
2. Try to refute even unanimously agreed findings; set severity on the merits (`/code-review` › *Severity*), never by averaging or taking max/min.
3. Pick the fix that holds up against the code and repo conventions; record dropped fixes and changed ratings in the Reconciliation table.
4. Apply thread state: `✅ Fixed` moves to *Refuted / dropped* as `fixed at head (thread #id, commit)`; recorded team decisions lower to 🟢 (`decided in thread #id`); open `⏸`/`◐` threads attach via dual links ([pr-host-threads.md](../_modules/references/pr-host-threads.md)).

---

## 3. Output Format & Deliverables

Write `<prefix>-squashed_code_review-<suffix>.md` at the workspace root following [review-artifact-template.md](../code-review/references/review-artifact-template.md), with these additions:
1. **Review Context** adds **Sources squashed** (`A` · file link · host/model · mode · head reviewed · `same head` / `N commits since`), **PR threads** (source, human thread count, attached count), and **Read from** (snapshot / object reads at `<sha>` / live checkout).
2. **Findings Summary** adds a **Sources** column (`A B`, `B`, `A T#110776`), followed by:
   - **Reconciliation**: one row per non-unanimous cluster (*Point* · per-source claim/rating · *Verdict* with proof).
   - **Refuted / dropped**: one bullet per dropped source finding (`A3`: reason and proof).
3. **Detailed Review Findings**: numbered from 1; *Where* lists source keys and dual thread links; write prose fresh from the verified code.
4. **Posted to PR**: carry over every source's *Posted to PR* entries tagged by source key and mapped to squashed finding numbers.

Open the chat response with the `artifact-protocol` › *Chat link block*, followed by cluster counts, worst finding per axis, settled disagreements, thread summary, pinned head/snapshot cleanup status, and the closing gate line (`core` › *The `/proceed` gate*).

---

## Deep Mode

Follow `fan-out` › *Brief contract* and *Aggregation*: complete Steps 1–4 in the lead agent, spawn up to 5 read-only sub-agents across contested clusters (single-source, conflicting, severity split) with the pinned SHA / `[worktree-context]` block and source excerpts, then re-open every cited `path:line` yourself before writing the artifact.

---

## 4. Verification & Validation

- **Conservation**: every source finding (🔴 + 🟡 + 🟢) appears in the Sources column, Minor Findings, or *Refuted / dropped*.
- **Verified**: every surviving 🔴/🟡 was re-opened at the pinned head and every rating change has a Reconciliation row.
- **Intact sources & clean links**: source artifacts are untouched; no `<scratchpad>` path appears; intra-document `<a id>` anchors and dual thread links resolve.
