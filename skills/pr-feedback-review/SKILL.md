---
name: pr-feedback-review
description: Review, triage, and evaluate reviewer feedback, discussion threads, and votes on a pull request. Analyzes technical implications against the codebase and provides actionable recommendations and response options. Always looks for a counterpart PR in a sibling repo (a dual-repo change such as backend + frontend) and triages both PRs' threads, since a comment on one half often needs its fix on the other. `deep` runs the three analysis axes (Verification, Merit, Impact) as parallel sub-agents. Reads the PR head from a detached snapshot worktree by default so the user can keep editing the main checkout meanwhile; `live` opts out.
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

Read these before step 1:
- `~/.terminal/skills/_modules/core.md`: read-only until `/proceed`
- `~/.terminal/skills/_modules/artifact-protocol.md`: writes `<prefix>-pr_feedback_review-<suffix>.md` (suffix e.g. `-18176-backend`, `-18176-18177-verksamhetsobjekt`)
- `~/.terminal/skills/_modules/git-worktrees.md`: snapshot by default
- `~/.terminal/skills/_modules/pr-counterpart.md`

- Without a handed-in `[worktree-context]` block, the repo root is the snapshot this skill creates in *Step 2.3*.

---

## Modes

| Invocation | Mode | How the axes run |
|---|---|---|
| `/pr-feedback-review [target]` | **Standard** (default) | One pass; the reviewer covers all three axes itself (Steps 3–5) |
| `/pr-feedback-review deep [target]` | **Deep** | Verification, Merit and Impact each run in an isolated parallel sub-agent (see *Deep Mode*), then aggregate |
| `/pr-feedback-review live [target]` | Standard or deep, **no snapshot** | Reads the main checkout directly instead of the snapshot from *Step 2.3*. Only when no snapshot is possible, or the user wants threads checked against unpushed local commits |

`live` is a modifier, not a mode: `/pr-feedback-review deep live <target>` is valid. The words `worktree`, `worktrees` and `/git-worktrees` in the arguments are accepted and change nothing — the snapshot is already the default.

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

### Parsing PR URLs

- **Azure DevOps**:

  ```text
  https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{prId}
  https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{prId}
  ```

- **GitHub**:

  ```text
  https://github.com/{owner}/{repo}/pull/{prId}
  ```

### Branch Auto-Discovery (When No URL or ID Given)

```bash
# Azure DevOps (run inside repository)
az repos pr list --source-branch "$(git rev-parse --abbrev-ref HEAD)" \
  --status active --detect true \
  --query '[0].{id:pullRequestId,title:title,target:targetRefName}' -o json

# GitHub
gh pr view --json number,title,baseRefName,url
```

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
az repos pr show --id <prId> --detect true -o json
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

#### Azure DevOps API (using `az devops invoke`)

Azure DevOps CLI does not have a native `az repos pr thread` command. Use `az devops invoke` or REST API:

```bash
python3 -c "
import json, subprocess

cmd = ['az', 'devops', 'invoke', '--area', 'git', '--resource', 'pullRequestThreads',
       '--route-parameters', 'project=<PROJECT>', 'repositoryId=<REPO>', 'pullRequestId=<PR_ID>',
       '--detect', 'true', '-o', 'json']
res = subprocess.run(cmd, capture_output=True, text=True)
data = json.loads(res.stdout)

for thread in data.get('value', []):
    comments = thread.get('comments', [])
    status = thread.get('status') # active, fixed, closed, pending, etc.
    thread_ctx = thread.get('threadContext')
    file_path = thread_ctx.get('filePath') if thread_ctx else None
    line = thread_ctx.get('rightFileStart') if thread_ctx else None
    t_id = thread.get('id')
    
    # Filter out automated bot comments (e.g., test coverage services) unless relevant
    human_comments = [c for c in comments if c.get('author', {}).get('displayName') != 'Azure Pipelines Test Service' and c.get('commentType') != 'system']
    if human_comments:
        print(f'=== Thread ID: {t_id} | Status: {status} | File: {file_path} | Line: {line} ===')
        for c in human_comments:
            author = c.get('author', {}).get('displayName')
            content = c.get('content')
            published = c.get('publishedDate')
            print(f'[{author}] ({published}):\n{content}\n')
"
```

#### GitHub API (using `gh api`)

```bash
# PR line-level comments and review comments
gh api repos/{owner}/{repo}/pulls/{prId}/comments
# PR issue-level conversation comments
gh api repos/{owner}/{repo}/issues/{prId}/comments
```

#### Keep the dump

Save the raw JSON and the filtered human-readable dump to the scratchpad (e.g. `threads.json`, `threads-human.txt`) rather than only printing them. The dump is the single source for Steps 3–5, and in deep mode the sub-agents read it from there instead of re-fetching. Record for each thread its **status**, **file/line**, and the **iteration** it was written against (`pullRequestThreadContext.iterationContext`) — the iteration tells you how far the code may have moved since.

### 2.3 — Pin the head in a snapshot

Threads are assessed against the PR's **remote head** — what reviewers see — never against the iteration they were written on, and never against whatever happens to be checked out locally. That head is materialised in a **detached `git worktree` outside the repo** and everything in Steps 3–5 reads from there, so the user can keep editing the main checkout the whole run. `/pr-feedback-review live …` skips the snapshot and reads the main checkout as-is.

The lifecycle — create, read, map paths back, remove, fallback — is **`git-worktrees` › *Snapshot Lifecycle* (snapshot mode)** with `<skill>=pr-feedback-review`; follow it for the mechanics. What is specific here:

- **Repo:** the workspace repo whose `origin` matches the PR's `{repo}` (*Repo Resolution* — in a multi-repo workspace, e.g. `GR.PRIIS.Backend` for a `_git/GR.PRIIS.Backend/pullrequest/…` URL). One snapshot per PR in scope.
- **Head and source ref** (*Snapshot Lifecycle* a, *PR whose branch is not checked out* row — used even when it is checked out, since local commits are not what reviewers see):

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
   - **Framework & Conventions**: FastEndpoints, EF Core tracking/filters, Radix UI, Zod validation, sealed classes, etc.
   - **Security & Authorization**: Access rules, global query filters (`AddCategoryProtectionQueryFilter`), role permissions.
   - **API Contracts & Breaking Changes**: Does the suggestion alter client/frontend request/response contracts?

---

## Step 4 — Triage & Technical Assessment

Group each comment/thread into a clear severity / triage category:

- 🔴 **Blocking / Defect / Change Requested**:
  - Reviewer voted `-5` or `-10`, or pointed out a data integrity bug, race condition, security leak, or broken requirement.
- 🟡 **Design Proposal / Trade-off / Architectural Alternative**:
  - Reviewer suggested an alternative pattern, simplification, refactoring, or question of intent. Needs deliberate evaluation of tradeoffs (effort, blast radius, downstream impact).
- 🟢 **Minor / Polish / Convention**:
  - Small naming adjustment, code style, docstring clarification, or test coverage addition.
- ⚪ **Informational / Clarification / Already Answered**:
  - Questions about rationale, discussions already converged, or automated system notices.

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
   - Provide a clear, respectful, well-reasoned comment draft (in the project's working language, e.g. Swedish or English) that the author can copy and paste directly into the PR thread.

---

## Step 6 — Artifact Management & Output Format

### 6.1 — Write the Markdown Artifact

Always write the complete PR feedback review report to `<prefix>-pr_feedback_review-<suffix>.md` **at the workspace root** (never inside the snapshot) before returning the response, then remove the snapshot (*Step 2.3*).
- **Prefix Resolution**: Prefix `<prefix>-` includes both the active host and the actual AI model (`<host>-<model>-`, e.g. `antigravity-gemini-3.8-flash-` or `claude-sonnet-3.7-`).
- **Suffix Resolution**: Derive `<suffix>` from PR ID and topic (e.g. `-18176-backend`, `-18176-18177-verksamhetsobjekt`).

### 6.2 — Artifact Links

Format all chat links and section anchors according to the **`artifact-protocol`** protocol (`file://` absolute for Antigravity IDE, workspace-relative for Claude Code, `#L<line>` line fragments for chat).

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
> **Status:** Active / Needs Attention — <votes>, <n> threads active, <n> resolved  
> **Reviewers:**  
> - **<Reviewer Name>:** `<Vote / Status>`

---

## Executive Summary & Triage Matrix

| Thread | PR | File | Reviewer | Category | State at head | Recommendation |
|---|---|---|---|---|---|---|
| [#106735](#thread-106735) ([devops](https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<prId>?discussionId=106735)) | Backend !18707 | PriisDbContext.cs | Nebojsa | 🟡 Optimization | ⏸ Not addressed | Refactor cascade loop to Queue worklist |
| [#106740](#thread-106740) ([devops](…)) | Frontend !18708 | Foo.tsx | Daniel | 🔴 Bug | ✅ Fixed (`abc1234`) | Reply, resolve |

*State at head* is one of ✅ Fixed (commit) · ◐ Partial · ⏸ Not addressed · ↩ Superseded · ⚪ n/a. With a single PR in scope, drop the *PR* column.

---

## Detailed Thread Analysis & Actionable Solutions

### <a id="thread-<ThreadId>"></a>Thread [#<ThreadId>](https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<prId>?discussionId=<ThreadId>): <File / Topic Summary>
- **Author:** <Name> (<Timestamp>)
- **Status:** Active / Closed
- **Location:** `[<file>:<line>]`
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

#### Ready-to-Send Reply (Swedish / Project Language)
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
- **Match the language of the PR conversation**: If the PR thread discussions and reviewers communicate in Swedish (common in Swedish public sector / municipal projects like PRIIS), provide draft replies in Swedish, along with English technical summaries.
