---
name: squash-code-review
description: Squashes two or more code reviews of the same change into one new, verified code review. Typical inputs are /code-review artifacts written by different models or hosts, or by earlier runs. Matches findings across reviews by root cause, not by title. Settles every disagreement (a finding only one review raised, conflicting claims, different severities) by re-checking the code at the current PR head instead of voting or taking the maximum. Also pulls in the PR's discussion threads, through an existing /pr-feedback-review artifact or the same read-only thread fetch, so findings that reviewers already raised, fixed or decided on are linked rather than repeated. Writes a single `<prefix>-squashed_code_review-<suffix>.md` with a reconciliation table that accounts for every source finding. Read-only; never edits the source reviews. Trigger on /squash-code-review, "squash these reviews", "merge the code reviews", "combine both reviews into one", "reconcile the Fable and Opus reviews", "consolidate the review findings".
---

# Skill: `/squash-code-review` — Squash Code Reviews

Takes two or more code reviews of the same change and produces one new review that holds only what survives a re-check against the code. Disagreements between the sources are settled in code and recorded, and the PR's own discussion threads are folded in so the result does not repeat what reviewers already said or decided.

---

## ⛔ Mandatory Invariants

> [!CAUTION]
> 1. **MANDATORY ARTIFACT:** Every run writes or updates `<prefix>-squashed_code_review-<suffix>.md` **at the workspace root** and opens the chat response with links to it, built as `/code-review` › *Artifact Links* specifies.
> 2. **NEVER EDIT A SOURCE REVIEW.** The source artifacts, including one written by the running model, stay byte-for-byte intact. The squash is a new file.
> 3. **SOURCES ARE EVIDENCE, NOT VERDICTS.** No 🔴/🟡 enters the squash because a source said so. Each one passes `/code-review` › *Step 6 — Verify Every 🔴 and 🟡* at the head this run pins, whether one source raised it or all of them did.
> 4. **CONSERVATION.** Every finding of every source ends up in exactly one place: a squashed finding, a minor finding, or a *Refuted / dropped* row with the reason. Nothing disappears silently.
> 5. **READ-ONLY.** No code edits, checkouts, stashes, commits, posting, voting or thread resolution. The only git writes are the ones `git-worktrees` snapshot mode allows.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-squashed_code_review-<suffix>.md` (suffix: the sources' shared suffix, e.g. `-18715-18716-rtk-api-domains`)
- `../_modules/git-worktrees.md`: snapshot by default
- `../_modules/pr-counterpart.md`

- Also read [`code-review`](../code-review/SKILL.md). Severity, axes, verification, artifact structure, *In Plain Terms* and the link format all come from there. This skill adds only what is specific to squashing.
- Read [`pr-feedback-review`](../pr-feedback-review/SKILL.md) › *2.2 — Discussion Threads & Comments* for the thread fetch, and its *State at head* vocabulary.
- `/code-review` normally forbids reading another model's review. Here the user has asked for exactly that comparison, so reading every source is the job.

---

## Modes

| Invocation | Mode | What happens |
|---|---|---|
| `/squash-code-review [sources]` | **Standard** | One pass: match, verify, reconcile, fold in threads |
| `/squash-code-review deep [sources]` | **Deep** | Contested clusters are verified by parallel read-only sub-agents (see *Deep Mode*); the aggregator re-checks each verdict |
| `/squash-code-review feedback [sources]` | Standard or deep, **full thread triage** | Runs `/pr-feedback-review` first, which writes its own artifact, and then squashes against that |
| `… live …` | **No snapshot** | Reads the main checkout instead of a pinned head, as in `/code-review` › *Modes* |

Modifiers combine: `/squash-code-review deep feedback @a.md @b.md`.

### When *not* to use

| Situation | Use instead |
|---|---|
| Only one review exists, or you want a fresh review | `/code-review` |
| You want to triage what human reviewers wrote on the PR | `/pr-feedback-review` |
| The squashed findings are ready to go on the PR | `/pr-post-comments` (point it at the squashed artifact) |

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/squash-code-review`.
- The user asks to squash, merge, combine, reconcile or consolidate two or more code reviews.
- The user asks which of two reviews is right about a finding they disagree on, across the whole review.

---

## 2. Core Protocol & Workflow

### Step 1 — Resolve the sources

| User passes | Sources |
|---|---|
| Two or more `@file` paths | Those files |
| A PR id, PR URL or suffix | Every `*code_review-<suffix>*.md` at the workspace root for that PR, across hosts and models |
| Nothing | The current branch's PR (`/code-review` › *No URL given — resolve the PR from the branch*), then as above |

- Fewer than two sources is a stop: say which one was found and suggest `/code-review`.
- Include an earlier `squashed_code_review` for the same suffix only when the user names it. It is never a source by default. This run updates it only if this session owns it (`artifact-protocol` › *Ownership*); otherwise the squash goes to the next counter (`artifact-protocol` › *Claim*).
- Give each source a one-letter key in discovery order (`A`, `B`, …) and record for each: file, host and model (from the prefix), mode, date, and the **head it reviewed** (its *Review Context*). A source with no recorded head is still usable, but every finding from it counts as single-source until verified.
- Sources about different PRs or different changes are a stop. Say what each one reviewed.

### Step 2 — Pin the head and measure drift

- Resolve the PR(s) and counterpart(s) the sources reviewed (`/code-review` › *Pull-Request References*, `pr-counterpart` › *Counterpart discovery*). Fetch and pin the **current** head per repo (`/code-review` › *Step 1b — Review Snapshot*).
- For each source, compare its head with the pinned head: `git -C <repo> diff --stat <source-head> <pinned-head>`. Record `same head` or `N commits since`, and list the files that changed under any finding the source cites. Those findings must be re-located before they are judged.
- Targeted re-checks may read the pinned tree straight from the object store (`git -C <repo> show <sha>:<path>`, `git -C <repo> grep <pattern> <sha> -- <path>`). Create a snapshot worktree only when whole files must be navigated. Either way, record which one you used in *Review Context*.

### Step 3 — Fold in the PR discussion

1. Look for `*pr_feedback_review-<suffix>*.md` at the workspace root. If one exists and its *Head reviewed* equals the pinned head, read its triage matrix and use it.
2. Otherwise fetch the threads read-only, as in `pr-feedback-review` › *2.2 — Discussion Threads & Comments*, for every PR in scope. Keep the dump in the scratchpad and drop bots, system comments and deleted threads. Do not write a `pr_feedback_review` artifact unless the run is `feedback`.
3. Read each source's *Posted to PR* row as well. A thread that `/pr-post-comments` created from a source finding belongs to that finding.
4. Record, per thread: id, file and line, author, status, and *State at head*. Use the `pr-feedback-review` vocabulary: ✅ Fixed · ◐ Partial · ⏸ Not addressed · ↩ Superseded · ⚪ n/a.

If the fetch fails (auth, CLI missing), continue without threads, and say so in *Review Context* and in chat. Never guess what a thread said.

### Step 4 — Match findings into clusters

Put every finding from every source (🔴, 🟡, 🟢 and the Refuted lines a source may already carry) into **clusters by root cause**:

- **Same cluster:** the same defect at the same place, even when worded or titled differently, or rated differently. A finding that is half of another (one source calls it a stale comment, the other calls it the behaviour change that made the comment stale) joins that cluster and is merged.
- **Different clusters:** the same file or line but a different claim. Two claims about the same code that contradict each other form one *conflicting* cluster.
- Attach every PR thread that discusses the same root cause to its cluster. A thread that matches no cluster becomes its own cluster, sourced `T#<id>`, but only when it raises a code defect still open at head.

Classify each cluster: **agreed** (every source that looked at the area raised it), **single-source**, **conflicting** (claims or facts contradict each other), or **severity split** (same claim, different ratings).

### Step 5 — Settle every cluster in code

For each cluster, at the pinned head:

1. **Re-open the cited code** and re-locate it if the file moved since the source's head.
2. **Settle facts, not opinions.** When sources state different facts (a symbol exists or doesn't, a count is 87 or 88, a call happens or doesn't), check the fact itself: `git show`, `git grep`, the backend or the counterpart repo. The answer goes in the reconciliation table with what proves it.
3. **Try to refute the strongest version.** For a single-source finding, look for the guard, caller or config the other sources may have seen. For an agreed finding, still run the refutation step. Two reviews can share one wrong assumption.
4. **Set severity on the merits**, as `/code-review` › *Severity* defines it. Never take the maximum, the minimum or an average. When the squash changes a source's rating, the reconciliation row says why: which premise the source got wrong, or what new evidence decided it.
5. **Pick the fix.** When sources propose different fixes, keep the one that holds up against the code and the repo's own rules. Drop options that only work by gaming a check, such as a name chosen to pass a lint rule. Name the dropped option in the reconciliation row.
6. **Apply the thread state:**
   - ✅ Fixed at head → the finding is resolved. It goes to *Refuted / dropped* as "fixed at head (thread #id, commit)", not into the findings.
   - A recorded decision from the author or a reviewer ("intentional", "follow-up story #123") → keep the finding only if the code contradicts that decision or the decision leaves a defect in place. Quote the decision either way.
   - ⏸ / ◐ → keep the finding, and link the thread in its *Where* line so `/pr-post-comments` replies there instead of opening a duplicate.
7. **Classify the outcome:** Verified · Plausible (say what would confirm it) · Refuted (moves to *Refuted / dropped*).

---

## 3. Output Format & Deliverables

### Artifact

`<prefix>-squashed_code_review-<suffix>.md` at the workspace root. Its structure is `/code-review` › *Artifact Structure*, in the same section order, with these additions:

1. **Review Context** gains:
   - **Sources squashed**: one row per source, as `A` · file link · host/model · mode · head reviewed · `same head` / `N commits since`.
   - **PR threads**: the source (`pr_feedback_review` artifact / live fetch / unavailable), the count of human threads, and the count attached to findings.
   - **Read from**: snapshot / object reads at `<sha>` / live checkout.
2. **Findings Summary** gains a **Sources** column on the main table, e.g. `A B`, `B`, `A T#110776`. It is followed by:
   - **Reconciliation**: one row per cluster that was not unanimous on both claim and severity. Columns: *Point* · one column per source (its claim and rating, or "not raised") · *Verdict* (outcome, and the fact or line that settled it).
   - **Refuted / dropped**: one line per source finding that did not survive. Give its source key and number, why it was dropped (refuted with evidence, fixed at head, duplicate of N, or decided in thread #id), and where its substance went, if anywhere.
3. **Detailed Review Findings** follow `/code-review` › *Detailed Findings*. Each heading ends with `· Verified|Plausible`. The *Where* line names its sources and any linked thread with the dual link from `artifact-protocol` › *PR Discussion Thread Links*. Write the text fresh from the verified code. Do not paste a source's paragraph; quote it only when its wording is the point.
4. **Minor Findings** keep the cap of 8 and carry source keys.
5. **Posted to PR**: carry over every source's *Posted to PR* entries verbatim, each tagged with its source key, and map each thread id to its squashed finding number. This lets `/pr-post-comments` skip what is already posted.
6. **In Plain Terms**: as `/code-review` specifies, for every squashed 🔴/🟡.

Numbering restarts at 1 in the squash. A source's own numbers appear only as `A3`, `B1`, … in the Sources column, the Reconciliation table and the Refuted list.

### Chat response

Open with the artifact links exactly as `/code-review` › *Artifact Links* specifies, with the `squashed_code_review` file name. Then give:
- Counts: clusters agreed / single-source / conflicting / severity split, and source findings refuted or dropped.
- The worst finding per axis, one line each, or "clean".
- What the sources got wrong, one line per settled fact or changed severity, naming the source.
- The threads folded in, or why they weren't (fetch failed, no PR).
- Which head was pinned, and whether a snapshot was removed or object reads were used.

---

## Deep Mode

1. Do Steps 1–4 yourself. Sub-agents never resolve PRs, fetch threads or touch worktrees.
2. Spawn one read-only sub-agent per **contested** cluster (single-source, conflicting or severity split), batched in one message. Agreed clusters stay with the aggregator. Merge small clusters so there are at most about 8 agents. Each prompt carries: the cluster's source excerpts verbatim, the attached thread text, the pinned SHA and the read commands (`git -C <repo> show <sha>:<path>`, or the snapshot's `[worktree-context]` block), and this brief:
   > "Settle this cluster at `<sha>`. For each factual claim: true or false, with the `path:line` or command output that proves it. Then try to refute the finding outright. Propose severity per the attached definitions and the better of the proposed fixes, or a third. Read-only: no edits, no checkouts, no builds or tests. Under 400 words."
3. Aggregate: re-open every `path:line` a sub-agent cites before accepting its verdict, then write the artifact as in standard mode.

---

## 4. Verification & Validation

Before emitting the chat response, check:

- **Conservation:** count source findings (🔴 + 🟡 + 🟢 per source). Every one is accounted for in a squashed finding's Sources column, a minor finding, or the *Refuted / dropped* list.
- **Every 🔴/🟡** carries `Verified` or `Plausible`, and was re-opened at the pinned head in this run.
- **Every rating change** against a source has a Reconciliation row that says why.
- **No source file was modified:** `git status` / `ls -l` timestamps on the source artifacts are unchanged. No `<scratchpad>` path appears in the artifact.
- **Anchors:** every `[N](#finding-N)` and `[plain](#finding-N-plain)` in the table resolves, and the chat links use line numbers read from the written file (`grep -n '^#\{1,3\} '`).
- **Threads:** every attached thread id links both inside the document and to the PR host.
