---
name: pr-feedback-review
description: "Triages the discussion on a pull request: every reviewer thread, comment and vote, checked against the code at the PR head, with a triage category, its state at head, a recommendation and a ready-to-send reply per thread, in `<prefix>-pr_feedback_review-<suffix>.md`. Also triages the counterpart PR in a sibling repo, where a comment's fix often lands. `deep` runs Verification, Merit and Impact as parallel sub-agents; reads from a detached snapshot (`live` opts out). Use for /pr-feedback-review, \"triage the PR comments\", \"what did the reviewers say?\", \"draft replies to the threads\". Not for reviewing the code yourself (/code-review) or posting the replies (/pr-post-comments)."
---

# PR Feedback Review Skill

Use this skill whenever the user asks to review pull request feedback, triage review comments, assess reviewer objections or suggestions, or plan responses/actions for PR comments.

---

## ⛔ Mandatory Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR DEVIATION:**
>
> 1. **MANDATORY .MD ARTIFACT & SUMMARY (NO EXCUSES):** Every single `/pr-feedback-review` response MUST ALWAYS write or update the complete feedback review report as `<prefix>-pr_feedback_review-<suffix>.md` **at the workspace root**, and begin the response with a clickable link to it plus clickable section anchors, built exactly as *Artifact Links* below specifies. The user frequently needs to click and open it in the IDE.
> 2. **DO NOT MODIFY CODE OR THE MAIN WORKING TREE:** You must **NEVER** edit code files, stage commits, run migrations, check out branches, `git stash push`/`pop`, or execute modifying commands during or immediately after a `/pr-feedback-review`. The **only** git writes allowed are `git fetch` and the ones `git-worktrees` snapshot mode performs (*Step 2.3*): `git worktree add --detach` / `remove` / `prune` on a snapshot directory **outside** the repo.
> 3. **DO NOT AUTO-PROCEED:** Never begin implementing fixes or refactorings automatically. Present clear decision paths, code diffs, and draft replies, then wait for explicit user instruction.
> 4. **DO NOT GENERATE AN IMPLEMENTATION PLAN INSTEAD:** Do not substitute `<prefix>-implementation_plan-<suffix>.md` for the feedback review document. The feedback review document *is* `<prefix>-pr_feedback_review-<suffix>.md`.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-pr_feedback_review-<suffix>.md` (suffix e.g. `-18176-backend`, `-18176-18177-verksamhetsobjekt`)
- `../_modules/git-worktrees.md`: snapshot by default
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`
- `../_modules/project-profile.md`: base profile only (no Command profile); reads *Tracker*, *PR tooling*, *Pattern skills per layer*, *Contract touchpoints*, *Report language* and *Known drift*

- Without a handed-in `[worktree-context]` block, the repo root is the snapshot this skill creates in *Step 2.3*.

---

## Project profile

Before Step 1, load the project's base profile `<project>-profile` with the Skill tool when the workspace matches its `[Project: …]` gate (`project-profile` › *Discovery*; e.g. `priis-profile` in the GR workspace). There is no `pr-feedback-review-<project>-profile`. Resolve the fields named in *Modules* per `project-profile` › *Resolution order*:

- **Tracker** and **PR tooling** pick the org URL, repository ids and the thread-fetch tool for Steps 1–2, ahead of `pr-host`'s generic order.
- **Pattern skills per layer** names the skills to load for the layer a thread is about (Step 3).
- **Contract touchpoints** is the list Step 3 and the *Impact* axis check a suggested change against.
- **Report language** sets the language of the artifact and the drafted replies (*Heuristics* › *Match the language*).
- **Known drift** tells which rulebook or skill claims to distrust when a thread cites them.

A profile adds facts; it never relaxes this skill's invariants (read-only, snapshot, no posting). Name the loaded profile in the artifact header's **Profile** line, or write "none" when no profile matches.

---

## Modes

| Invocation | Mode | How the axes run |
|---|---|---|
| `/pr-feedback-review [target]` | **Standard** (default) | One pass; the reviewer covers all three axes itself (Steps 3–5) |
| `/pr-feedback-review deep [target]` | **Deep** | Verification, Merit and Impact each run in an isolated parallel sub-agent (see *Deep Mode*), then aggregate |
| `/pr-feedback-review live [target]` | Standard or deep, **no snapshot** | Reads the main checkout directly instead of the snapshot from *Step 2.3*. Only when no snapshot is possible, or the user wants threads checked against unpushed local commits |

`live` is a modifier, not a mode: `/pr-feedback-review deep live <target>` is valid. The token `/worktrees` in the arguments is accepted and changes nothing, because the snapshot is already the default. The token `/no-worktrees` means `live`.

The three axes every thread is assessed on:

- **Verification** — what does the code at *head* do about this thread? Addressed, partially, not at all, or superseded; the commit and `path:line` that prove it; whether a test pins it.
- **Merit** — is the reviewer right, and is the proposed fix the right fix? Evaluated independently against the code and framework semantics, trying to refute both the reviewer and the current implementation.
- **Impact** — what else does acting on it touch? Stacked branches, linked work items, cross-repo contracts, other callers, conflicts between threads, decisions already taken in earlier artifacts.

Suggest `deep` in the chat response (do not switch silently) when there are more than ~10 active threads, when threads are anchored to an iteration older than head (the code has moved since they were written), or when reviewers propose concrete alternative implementations whose correctness needs checking rather than just adopting.

---

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Reviewing the PR's code yourself | [`/code-review`](../code-review/SKILL.md) |
| The PR's build validation is red | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |
| Writing or refreshing the PR description | [`pr-summary`](../pr-summary/SKILL.md) |
| How to try the change by hand | [`/manual-testing`](../manual-testing/SKILL.md) |

---

## Step 1 — Determine the Target PR

Parse the arguments or current workspace context to identify the target PR:

| Input | Resolution |
| --- | --- |
| Full PR URL | Parse `{org}`, `{project}`, `{repo}`, `{prId}` directly |
| Bare PR ID (e.g. `18170`, `#18170`) | Use current repo remote to infer host/org/project |
| No argument | Detect open PR for current git branch |

Parsing a URL, resolving a bare id or the current branch to a PR, and choosing the organization URL are **`pr-host`** › *Parse a PR or work-item URL*, *Resolve the PR from a branch* and *Organization URL*.

### Counterpart PRs — every resolved PR, every time

After the target PR is resolved, run the counterpart lookup in **`pr-counterpart` › *Counterpart discovery***. That section owns the signals, the commands and the classification. One pasted link is one half of a change that may span repos. What the result means here:

- **Found** → the counterpart joins the scope without asking. Steps 2–5 run for **every PR in scope**: its metadata and votes, its thread dump (kept per PR: `threads-<repo>.json`), its own snapshot (*2.3*, one per PR), and its rows in the triage matrix. A thread on one PR whose fix lands in the other repo, or must land in both (an API shape, a shared enum, a generated client snapshot), is assessed against **both** snapshots. Its *Concrete Code Solution* names both files, and its reply says the counterpart PR carries the other half.
- **Found, excluded** (the user named one PR "only") → triage only that PR. Still name the counterpart, its head and its open-thread count in the header, and flag any thread whose fix would change the shared contract.
- **Expected but missing** → an action-checklist item: the fix a thread asks for needs a change in a repo that has no PR.
- **None** → say "single-repo change" in the header.

---

## Step 2 — Fetch PR Metadata, Reviewers & Discussion Threads

Gather complete PR information including status, reviewers, vote states, and discussion comments.

### 2.1 — PR Details & Reviewer Votes

```bash
# Azure DevOps — Details & Reviewers
az repos pr show --id <prId> --org <org-url> -o json   # <org-url>: pr-host › Organization URL
```

Key reviewer vote values in Azure DevOps:

- `10`: Approved
- `5`: Approved with suggestions
- `0`: No vote / reset
- `-5`: Waiting for the author / Changes requested
- `-10`: Rejected

```bash
# GitHub — Details & Reviewers
gh pr view <prId> --json title,body,state,headRefName,baseRefName,reviewDecision,reviews
```

### 2.2 — Discussion Threads & Comments

Fetch every thread per **`pr-host`** › *Fetch discussion threads*: the Azure DevOps `az devops invoke` dump with human comments filtered from bots and system notices, or GitHub's inline and general comments (paginated) plus each thread's resolved/outdated state from GraphQL. Run it for every PR in scope.

#### Keep the dump

Save the raw JSON and the filtered human-readable dump to the scratchpad (e.g. `threads.json`, `threads-human.txt`) rather than only printing them. The dump is the single source for Steps 3–5, and in deep mode the sub-agents read it from there instead of re-fetching. Record for each thread its **status**, **file/line**, and the **iteration** it was written against (`pullRequestThreadContext.iterationContext`) — the iteration tells you how far the code may have moved since.

#### Capture the selected code

An inline thread is anchored to the lines the reviewer selected. Quote that selection in the artifact (*6.3* › **Selected code**), so the reader sees what the comment is about without opening the PR. Take it from the commit the reviewer saw, not from head: head shows what the code is *now*, which is the job of *State at head*.

- **Azure DevOps:** the selection is `threadContext.rightFileStart.line` … `rightFileEnd.line` (new side). When only `leftFileStart`/`leftFileEnd` are set, the reviewer selected removed lines on the base side. The commit is the iteration's: map `iterationContext.secondComparingIteration` to that iteration's `sourceRefCommit.commitId` (left side: `commonRefCommit.commitId`). Fetch the iterations once per PR:

  ```bash
  az devops invoke --org <org-url> --area git --resource pullRequestIterations \
    --route-parameters project=<project> repositoryId=<repo> pullRequestId=<prId> --api-version 7.1 -o json > iterations.json
  # filePath starts with '/': strip it
  git -C <repo> show <iteration-commit>:<filePath-without-leading-slash> | sed -n '<start>,<end>p'
  ```

- **GitHub:** a review comment carries `path`, `original_commit_id`, `original_start_line` (null for a one-line selection) and `original_line`, plus `side` (`LEFT` = removed lines). Read `git -C <repo> show <original_commit_id>:<path> | sed -n '<start>,<end>p'`. When the commit cannot be read, use the tail of the comment's `diff_hunk`.
- **Commit unreachable** (the branch was force-pushed and `git fetch origin <sha>` fails): quote the same range at head, and label it `(at head — iteration commit no longer reachable)`.
- Keep the snippet next to the thread in the dump, so deep-mode sub-agents get it too. Quote up to 20 lines. A longer selection shows its first 20 lines and then `// … <n> more lines`. General threads (no file) have no snippet: omit the field.

### 2.3 — Pin the head in a snapshot

Threads are assessed against the PR's **remote head** — what reviewers see — never against the iteration they were written on, and never against whatever happens to be checked out locally. That head is materialised in a **detached `git worktree` outside the repo** and everything in Steps 3–5 reads from there, so the user can keep editing the main checkout the whole run. `/pr-feedback-review live …` skips the snapshot and reads the main checkout as-is.

The lifecycle — create, read, map paths back, remove, fallback — is **`git-worktrees` › *Snapshot Lifecycle* (snapshot mode)** with `<skill>=pr-feedback-review`; follow it for the mechanics. What is specific here:

- **Repo:** the workspace repo whose `origin` matches the PR's `{repo}` (*Repo Resolution*; in a multi-repo workspace, e.g. the `Shop.Api` checkout for a `_git/Shop.Api/pullrequest/…` URL). One snapshot per PR in scope.
- **Head and source ref** (*Snapshot Lifecycle* a, *PR whose branch is not checked out* row — used even when it is checked out, since local commits are not what reviewers see):

  `<sourceBranch>` / `<targetBranch>` are the PR's `sourceRefName` / `targetRefName` from Step 2.1 with `refs/heads/` stripped (GitHub: `headRefName` / `baseRefName`, already bare):

  ```bash
  git -C <repo> fetch origin <sourceBranch> <targetBranch>
  HEAD_SHA=$(git -C <repo> rev-parse origin/<sourceBranch>)    # source ref: origin/<sourceBranch>
  git -C <repo> rev-parse --abbrev-ref HEAD                      # main checkout's branch
  git -C <repo> rev-list --left-right --count "$HEAD_SHA"...HEAD # "<behind> <ahead>" when that branch is the PR branch
  ```

  Also compare `HEAD_SHA` with the PR's `lastMergeSourceCommit` from Step 2.1; a mismatch means the PR moved during the fetch — re-fetch.
- **Create** (*Snapshot Lifecycle* b): `SNAP_DIR=<scratchpad>/pr-feedback-review/<repo-dirname>/<ref-slug>@<short-sha>`, then `git -C <repo> worktree add --detach "$SNAP_DIR" "$HEAD_SHA"`.
- **Read** (*Snapshot Lifecycle* c): inside the snapshot `HEAD` **is** the PR head and remote refs are shared, so

  ```bash
  git -C "$SNAP_DIR" log --oneline origin/<targetBranch>..HEAD
  git -C "$SNAP_DIR" diff origin/<targetBranch>...HEAD
  ```

  CodeGraph indexes the main checkout: navigate with it, open the same file under `$SNAP_DIR` for the citation (exact only when the main checkout's `HEAD` equals the snapshot head and is clean — say which case applied).
- **No `<scratchpad>` path reaches the artifact or the chat** (*Snapshot Lifecycle* d): map every `path:line` to `<repo-dirname>/…` first.
- **Remove** (*Snapshot Lifecycle* e) after the artifact is written and its links emitted — in deep mode, after every sub-agent has returned — and say in chat that the snapshot of `origin/<sourceBranch> @ <short-sha>` was removed, or why it was kept.
- **Fallback** (*Snapshot Lifecycle* f): when `worktree add` fails, read live, record `live checkout` in the artifact header, and warn that edits during the run invalidate line numbers.

---

## Step 3 — Investigate Codebase Context & Related PRs

Do not analyze comments in a vacuum. Cross-reference each comment with the actual codebase. In standard mode you cover all three axes (*Verification*, *Merit*, *Impact*) yourself here and in Step 4; in deep mode this step is what the sub-agents do, and you aggregate (see *Deep Mode*).

1. **Inspect Targeted Code**:
   - Use `view_file` or `grep_search` to view the specific lines, classes, queries, or configs mentioned in the feedback — under the snapshot (`$SNAP_DIR`), not the main checkout.
2. **Check Downstream & Stacked Dependencies**:
   - Check if other PRs or branches branch off this PR (e.g. feature branch stacking).
   - Check linked work items (`az repos pr work-item list --id <prId>` or `az boards work-item show --id <id>`).
   - Check the counterpart PR (*Counterpart PRs*, Step 1): does the thread's suggestion change something the other repo consumes, and is the other half already there, or contradicted, at the counterpart's head?
3. **Assess Technical & Architectural Constraints**:
   - **Database & Migrations**: Temporal tables, data preservation (`sp_rename` vs drop/create), indexes, foreign keys.
   - **Framework & Conventions**: the project's pattern skills for the layer the thread is about (the Profile's *Pattern skills per layer*): endpoint, data access, UI, forms, validation.
   - **Security & Authorization**: the project's access rules, global query filters and role permissions.
   - **API Contracts & Breaking Changes**: Does the suggestion alter client/frontend request/response contracts?

---

## Step 4 — Triage & Technical Assessment

Put each thread in one triage category. These are **not** `/code-review` severities, so they use their own markers. `/code-review` *Step 6b* and `/squash-code-review` read this matrix next to their own 🔴/🟡/🟢, and shared emoji would read as the same scale:

- ⛔ **Blocking**: a defect the thread points out (data integrity, race condition, security leak, broken requirement) that would block the merge on its merits.
- 💡 **Proposal**: an alternative pattern, simplification, refactoring or question of intent. Needs deliberate evaluation of the trade-offs (effort, blast radius, downstream impact).
- ✏️ **Polish**: naming, code style, a docstring, or a test to add.
- ⚪ **Info**: questions about rationale, discussions already converged, automated notices.

Judge the category from what the thread says, checked against the code. A reviewer's vote (`-5` waiting for author, `-10` rejected) is recorded in the matrix's **Vote** column, not used as the category. A `-5` on a naming nit is still ✏️ Polish, and the vote column shows why the PR is held.

---

## Step 5 — Formulate Actionable Paths & Draft Replies

For every non-trivial thread:

1. **State the Underlying Motivation**: What is the reviewer actually concerned about? (e.g. avoiding unnecessary join tables, preventing N+1 queries, making code cleaner, ensuring temporal data is safe).
2. **Evaluate Tradeoffs**:
   - **Pros**: Cleaner API, less boilerplate, better performance.
   - **Cons / Risks**: Migration risks, rebase conflicts with stacked PRs, breaking public contracts, temporal table complications.
3. **Provide Concrete Decision Options**:
   - **Path A (Direct Fix / Refactor Now)**: Exact steps and code diffs required if adopting the feedback immediately.
   - **Path B (Clarify / Defer to Follow-up)**: Rationale for keeping current scope (e.g. minimal blast radius, prerequisite rename for stacked PR) and handling in a dedicated follow-up task.
4. **Draft Ready-to-Send Responses**:
   - Provide a clear, respectful, well-reasoned comment draft (in the language of the PR conversation) that the author can copy and paste directly into the PR thread.

---

## Step 6 — Artifact Management & Output Format

### 6.1 — Write the Markdown Artifact

Always write the complete PR feedback review report to `<prefix>-pr_feedback_review-<suffix>.md` **at the workspace root** (never inside the snapshot) before returning the response, then remove the snapshot (*Step 2.3*).
- **Name**: `<prefix>` and the rules for it are `artifact-protocol`'s. Derive `<suffix>` from PR ID and topic (e.g. `-18176-backend`, `-18176-18177-verksamhetsobjekt`).
- **Ownership**: a new artifact is published through *Claim*, with its owner marker. "Update" means updating an artifact **this session** created (`artifact-protocol` › rule 3); a re-run in a new session writes `…-2.md` and links the earlier one, never overwriting another session's file.

### 6.2 — Artifact Links

Format all chat links and section anchors according to the **`artifact-protocol`** protocol (`file://` absolute for Antigravity IDE, workspace-relative in the Claude Code IDE extension, an `antigravity-ide://` editor URL in the Claude Code terminal CLI).

Always start your response with a clickable link to `<prefix>-pr_feedback_review-<suffix>.md` and direct anchors to its main sections.

### 6.3 — Structure of `<prefix>-pr_feedback_review-<suffix>.md`

```markdown
# PR Feedback Review: <PR Title>

> **PR:** [<Title>](<url>) (`<source>` → `<target>`)  
> **Counterpart:** [<repo> !<id>](<url>) @ `<short-sha>` — triaged / found, not triaged / expected but missing / single-repo change (`pr-counterpart` › *Classification*)  
> **Head reviewed:** `origin/<source>` @ `<short-sha>` (iteration <n>)  
> **Read from:** snapshot of `origin/<source>` @ `<short-sha>` (removed) / (kept at <path>) / live checkout of `<branch>`  
> **Local checkout:** on `<branch>` — same commit / local ahead <n> / behind <n> / PR branch not checked out  
> **Mode:** standard / deep  
> **Profile:** `<project>-profile` / none (*Project profile*)  
> **Status:** Active / Needs Attention — <votes>, <n> threads active, <n> resolved  
> **Reviewers:**  
> - **<Reviewer Name>:** `<Vote / Status>`

---

## Executive Summary & Triage Matrix

| Thread | PR | File | Reviewer | Vote | Category | State at head | Recommendation |
|---|---|---|---|---|---|---|---|
| [#106735](#thread-106735) ([devops](https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<prId>?discussionId=106735)) | Backend !18707 | PriisDbContext.cs | Nebojsa | 0 | 💡 Proposal: optimization | ⏸ Not addressed | Refactor cascade loop to Queue worklist |
| [#106740](#thread-106740) ([devops](…)) | Frontend !18708 | Foo.tsx | Daniel | −5 | ⛔ Blocking: bug | ✅ Fixed (`abc1234`) | Reply, resolve |

*State at head* is one of ✅ Fixed (commit) · ◐ Partial · ⏸ Not addressed · ↩ Superseded · ⚪ n/a. With a single PR in scope, drop the *PR* column.

---

## Detailed Thread Analysis & Actionable Solutions

### <a id="thread-<ThreadId>"></a>Thread [#<ThreadId>](https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<prId>?discussionId=<ThreadId>): <File / Topic Summary>
- **Author:** <Name> (<Timestamp>)
- **Status:** Active / Closed
- **Location:** `[<file>:<line>]`
- **Selected code** (`<file>:<start>-<end>` @ `<short-sha>`, iteration <n>; omit for general threads):
  ```<lang>
  <the lines the reviewer selected, from Step 2.2 › Capture the selected code>
  ```
- **Reviewer Comment:**
  > <Quote of reviewer's comment>

#### Technical Analysis
- **Core Concern:** <What the reviewer is pointing out>
- **State at head:** <Addressed / partial / not — commit and `path:line` at head; the test that pins it>
- **Architectural Assessment:** <Is the reviewer right? Is the proposed fix right? How this fits the codebase, EF Core / API conventions, constraints>
- **Tradeoffs & Risks:** <Pros/cons of changing vs keeping as-is, downstream impact>

#### Concrete Code Solution
```diff
- old code
+ new code
```

#### Ready-to-Send Reply (in the PR's language)
> <Draft reply ready to copy-paste directly into the PR thread>

---

## Action Checklist & Next Steps
- [ ] Task 1
- [ ] Task 2
```

---

## Deep Mode

`/pr-feedback-review deep` runs each axis in its own sub-agent so one axis's context cannot mask another: a thread can be "fixed" at head while the reviewer's underlying claim was wrong, or the reviewer's proposed fix can be the one that introduces a defect, or a fix that satisfies one thread can undo another.

1. **Do Steps 1–2 yourself first** — PR resolved, votes and threads fetched, the dump saved to the scratchpad, snapshot created and compared with the local tree. Sub-agents must not re-fetch the PR or the threads, or create, remove, lock or unlock worktrees (`git-worktrees` invariant 5).
2. **Spawn the three sub-agents in parallel** (one message, three calls). Each prompt includes: the snapshot's **`[worktree-context]` block** (`repo-root` = the snapshot path, **never the main checkout**; `workspace-path` = what every cited path maps back to; `source-ref` = `origin/<source>`), the exact diff command (`git -C <snapshot> diff origin/<target>...HEAD`), the commit list, the path to the thread dump, and its axis brief. Each report is **per thread**, keyed by thread id, so the aggregator can join them.
   - **Verification** — "For every thread in the dump: what does the code at head do about it? Classify as fixed / partial / not addressed / superseded. Cite the commit and `path:line` at head (line numbers in the thread are from an older iteration — re-find the code), and name the test that pins it, or say there is none. Where the reviewer asked for something specific (a test, a doc line, an overload), check that exact thing exists. Under 600 words."
   - **Merit** — "For every thread: is the reviewer's claim correct, and is their proposed fix the right fix? Judge independently against the code and the framework's real semantics (EF Core change tracker, transactions, FastEndpoints, etc.). Try to refute both the reviewer and the current implementation. Flag proposals that would introduce a defect, claims the code already handles, and things the comment implies but does not say (a reviewer who names four endpoints may be describing six statements). Under 600 words."
   - **Impact** — include the list of workspace-root artifacts for this PR (earlier reviews, plans, description drafts). "For every thread that proposes a change: what else does it touch? Stacked branches off this PR, linked work items, cross-repo contracts (list them), other callers of the changed members, conflicts between threads (one thread's fix undoing another's), and decisions already recorded in the listed artifacts. Also compare the live PR description with the threads and the diff and flag stale claims. Under 500 words."
   - All sub-agents are **read-only**: no edits, no checkouts, no worktree commands, no installs, builds or tests, no posting. They read only under `repo-root` and report `path:line` already mapped to `workspace-path`.
3. **Aggregate** into the single artifact, then remove the snapshot: re-check that no citation points into the snapshot directory, join the three reports per thread, assign the Step 4 category, set *State at head* from Verification **only after re-opening the cited `path:line` yourself** — sub-agent output is evidence, not a verdict — decide Path A/B using Merit and Impact, and draft the reply. Any thread Merit marks as "reviewer is wrong" or "proposed fix introduces a defect" gets its reply written as a respectful explanation with the concrete failing sequence, never a bare refusal.
4. **Name the mode** in the artifact header and in the chat response.

---

## Heuristics & Common Pitfalls

- **Do not ignore reviewer votes**: A `-5` or `-10` vote blocks PR completion in most CI/CD branch policies. Highlight blocking feedback prominently.
- **Map every thread to head, not to its iteration**: thread anchors (`file:line`, iteration) point at the code the reviewer saw. Re-find the code at head before deciding anything; a thread can be fixed, moved, or made moot by later commits, and a "fixed" reply that cites the wrong line erodes trust.
- **Verify "addressed" by reading, not by commit message**: a commit titled after the thread is not proof. Open the code, and check that the *specific* ask (a test, a doc line, an overload, an exception type) exists.
- **Check the reviewer's fix, not only the reviewer's claim**: a correct diagnosis can come with a fix that breaks something else. When the branch chose a different mechanism than the one proposed, the reply must say why the proposed one was not taken.
- **Check for stacked branches**: If another active feature branch branches off this PR, major refactoring in this PR will require rebasing the downstream branch. Mention this tradeoff explicitly.
- **Differentiate opinion vs defect**: A suggestion to use implicit relationships or rename a variable is an architectural preference or cleanup; a missing authorization filter or data loss migration is a defect. Make the distinction crisp.
- **Match the language of the PR conversation**: draft replies in the language the reviewers write in, with an English technical summary when that language is not English. The project Profile's *Report language* field overrides this when it says otherwise.
