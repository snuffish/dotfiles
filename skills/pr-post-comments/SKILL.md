---
name: pr-post-comments
description: Posts already-drafted pull-request feedback to the PR host — /code-review findings as new inline threads anchored to the right file and line range, the 🟢 minor findings as one standalone non-blocking comment per PR, /pr-feedback-review "ready-to-send" replies into existing threads, and general (file-less) PR comments. Routes items across several PRs when one review spans repos, and supports a clean re-post after the user deleted earlier threads. Azure DevOps and GitHub. Resolves the PR and its latest iteration/commit, verifies every anchor against the PR head (not the local checkout), skips anything already posted, dry-runs the exact payloads, posts one and verifies its anchor before the rest, and records the thread ids back into the source artifact. Never resolves threads, votes, or edits the PR description unless that is also asked. Trigger on /pr-post-comments, "post the findings to the PR", "post these review comments", "create the PR threads", "reply to the threads in the PR", "also post the new findings", "post the minor findings as one comment", "I deleted the comments, post them again clean".
---

# Skill: `/pr-post-comments` — Post Drafted Feedback to a Pull Request

Turns feedback that has already been written and read by the user — review findings, thread replies, a general comment — into real comments on the pull request, each anchored where it belongs, without duplicates, and with a record of what was posted.

---

## ⛔ Mandatory Invariants

> [!CAUTION]
> 1. **POST ONLY ON AN EXPLICIT REQUEST IN THE CURRENT MESSAGE.** `/pr-post-comments` or "post …" is that request. Approval to post one batch does not carry over to a later batch. Drafting is the default everywhere else.
> 2. **POST ONLY WHAT WAS DRAFTED AND SHOWN TO THE USER.** Reformat for the PR (see *Step 4*), never rewrite the substance, add findings, or translate unless asked.
> 3. **NEVER RESOLVE, CLOSE, VOTE, OR EDIT THE PR DESCRIPTION** unless that exact action is also asked for. New threads are posted **active**.
> 4. **A DENIED POST IS FINAL FOR THIS TURN.** If the permission system blocks the write, do not route around it (other tools, other CLIs, a test runner). Leave the dry-run payloads in place and hand the user the exact command — see *Step 6*.
> 5. **DO NOT MODIFY CODE OR THE WORKING TREE.** Read the PR head through `git show <sha>:<path>`; the only local writes are the payload files in the scratchpad and the *Posted to PR* row in the source artifact.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **No artifact of its own.** It consumes an existing artifact — typically `<prefix>-code_review-<suffix>.md` or `<prefix>-pr_feedback_review-<suffix>.md` at the workspace root — and updates only its *Posted to PR* row.
- **Payload files** live in the host's scratchpad, `<scratchpad>/pr<id>/`, never in the repo or at the workspace root.

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/pr-post-comments [what] [pr]`.
- After `/code-review`: "post the findings", "post 🟡 1–5 as threads", "also post the new findings".
- After `/pr-feedback-review`: "reply to the threads", "send the drafted replies".
- "Leave a general comment on the PR saying …" with the text already agreed.

| Situation | Use instead |
|---|---|
| Nothing drafted yet | [`/code-review`](../code-review/SKILL.md) or [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) first |
| Writing or updating the PR description | [`/pr-summary`](../pr-summary/SKILL.md) |
| Red pipeline on the PR | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1 — Resolve what to post

1. **Source.** The artifact named by the user, else the most recent matching review artifact for this PR at the workspace root written by **this model** (`claude-<model>-…`). Another model's artifact is posted only when the user points at it.
2. **Selection.** Exactly what the user asked for. Ambiguous selection → ask once with the candidate list.

   | User says | Posted as |
   |---|---|
   | "the findings" | every open 🔴/🟡, one inline thread each |
   | "the new findings" | open 🔴/🟡 not in the artifact's *Posted to PR* row |
   | "the minor findings" / "the 🟢" | **one standalone general comment per PR** holding that PR's 🟢 items, never one thread per item (see *Minor-findings block*) |
   | "the replies" | every *Ready-to-Send Reply* whose thread action includes "reply" |
   | "clean" / "again" after the user deleted the threads | the same selection, re-posted from the artifact's **current** text (findings may have been revised since the first post) |

   **Resolved findings** (✅, or marked resolved/refuted in the artifact) are never posted as threads; at most they appear as one line in the minor-findings block.
3. **PR.** From the artifact's *Review Context*, the user's link, or the branch (`az repos pr list --source-branch … --detect true` / `gh pr view`). Azure DevOps: always `--org https://dev.azure.com/<org>`; the legacy `<org>.visualstudio.com` host fails auth even when signed in.
4. **One artifact, several PRs.** When the review spans repos (e.g. backend + frontend PR), route every item to the PR whose code it cites, and keep **one spec per PR** (the script posts to one PR per spec). An item citing both sides goes to the PR that owns the defect; the other side is mentioned by PR number in the body. Take the PR set from the artifact's *Counterpart* field, and confirm it with the lookup in [`core`](../core/SKILL.md) §4.1. If the user named only one PR, post that PR's items, list the counterpart's items as held back, and offer to post them.

### Step 2 — Pin the PR head and detect drift

```bash
# Azure DevOps — latest iteration and its source commit
az devops invoke --org https://dev.azure.com/<org> --area git --resource pullRequestIterations \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<id> --api-version 7.1 \
  --query 'value[-1].{id:id,src:sourceRefCommit.commitId}' -o json
# GitHub
gh pr view <n> --json headRefOid,headRefName
```

- **Same commit as the artifact's reviewed head** → anchors carry over as cited.
- **Head moved** → for each anchored file run `git -C <repo> diff <reviewed>..<head> -- <path>`. Unchanged region: shift the lines. Code at the anchor changed: stop and ask whether to re-anchor, skip, or re-review — a thread pointing at code that no longer says what it claims erodes trust.

`git fetch origin <sourceRef>` first if the commit is not local. Never check it out.

### Step 3 — Verify every anchor at the PR head

For each inline item:

```bash
git -C <repo> show <head>:<path> | awk 'NR>=<start> && NR<=<end> {print NR": "length($0)": "$0}'
```

- The cited lines must contain the code the finding quotes. Review citations drift by a line or two (especially citations copied from another review) — correct the anchor **and** the artifact's citation.
- `end_offset` = `length(end line) + 1` (Azure DevOps offsets are 1-based, exclusive end).
- **Azure DevOps** needs the file's `changeTrackingId` in that iteration:
  ```bash
  az devops invoke … --resource pullRequestIterationChanges \
    --route-parameters project=<p> repositoryId=<r> pullRequestId=<id> iterationId=<it> --api-version 7.1 \
    --query 'changeEntries[].{ct:changeTrackingId,path:item.path}' -o tsv
  ```
  A file not in the PR's changes cannot carry an inline thread → post it as a general comment that names `path:line`.
- **GitHub** accepts `line`/`start_line` only inside a diff hunk on the `RIGHT` side; outside a hunk, use `"subject_type": "file"` or a general comment naming `path:line`.

### Step 4 — Turn each item into a PR comment

- **Title line:** `**<severity> <one-line claim>**` (e.g. `**🟡 The backfill can price an extra from a value added after the lock**`). Drop artifact-only markers: *Verified/Plausible*, finding numbers, `(from the X review)`, `[plain]` links.
- **Body:** the *What and why* (failing path as a numbered sequence), then the *Fix* code block, then *Test to add* if the finding has one. *Decision needed* findings become "Options: (a) … (b) …".
- **References:** repo-relative `File.cs:123` only. No workspace-root prefixes, no scratchpad paths, no links to local artifacts. Point at sibling threads by file ("see the thread on `SelectContractEndpoint`"), never by artifact finding number.
- **Not posted:** *In Plain Terms*, *Feature in Brief*, praise, 🟢 unless asked.
- **Language:** as drafted. A reply drafted in Swedish is posted in Swedish.
- **Replies** (`/pr-feedback-review`): post the *Ready-to-Send Reply* text verbatim.

#### Minor-findings block

The artifact's *🟢 Minor Findings* list becomes **one general comment per PR** (`kind: "general"`, no file anchor), so it reads as a single non-blocking note instead of a dozen threads to resolve.

- **Title:** `**🟢 Minor findings (non-blocking)**`.
- **Only that PR's items.** In a multi-repo review, split the list by the repo each item cites. An item about a cross-repo check (e.g. "contract checked against the frontend PR: consistent") goes in the block of the PR that owns the contract.
- **One bullet per item:** `` `File.cs:123`: <claim>. `` When an item has several points, use sub-bullets. Resolved findings become a leading `**✅ <what was checked>: <result>.**` bullet.
- **Expand the artifact's compressed tail.** The artifact caps the list at 8 and ends with "+N more of the same kind: …". Post those as a short *Smaller still:* sub-list, so the comment holds every item the user read.
- Same reference rules as threads: repo-relative paths, no `(from the X review)` markers, no local links, no finding numbers.

### Step 5 — Dedupe, dry-run, post one, verify, post the rest

1. **Dedupe.** List existing threads and skip any item whose title line is already on a **live** thread:
   ```bash
   az devops invoke … --resource pullRequestThreads --route-parameters project=<p> repositoryId=<r> pullRequestId=<id> \
     --api-version 7.1 -o json   # keep threads where !isDeleted and some comment is !isDeleted and commentType != "system"
   gh api repos/<owner>/<repo>/pulls/<n>/comments --paginate --jq '.[].body'
   ```
   On Azure DevOps, deleted threads stay in the list with `isDeleted: true` (or with every comment deleted). CI bots (e.g. coverage checks) post their own threads. Neither counts as "already posted". The artifact's *Posted to PR* row is a hint, not the truth: the user may have deleted those threads. Trust the live list.
2. **Spec + dry run.** Copy [`templates/post_pr_comments.py`](templates/post_pr_comments.py) into `<scratchpad>/pr<id>/`, write `spec.json` beside it (format in the script's docstring), and run `python3 -I post_pr_comments.py spec.json`. It writes one payload file per item and prints each anchor; check them before posting.
3. **Post one, verify.** `--post --only <first-key>`, then fetch that thread and confirm the anchor landed on the intended lines. For a multi-repo batch, verify the first thread **per PR**. A general comment has no anchor: confirm `threadContext` is null, the status is active, and the first line is the title.
   ```bash
   az devops invoke … --resource pullRequestThreads --route-parameters … threadId=<id> --api-version 7.1 --query threadContext
   gh api repos/<owner>/<repo>/pulls/comments/<id> --jq '{path,line,start_line}'
   ```
4. **Post the rest.** `--post --only <remaining-keys>`. On a failure the script stops; report what posted and what did not.

### Step 6 — When the post is denied

Stop. Say plainly that posting was blocked and nothing (or which subset) was posted. Hand over the exact command with the absolute script and spec paths, e.g.:

```bash
python3 -I /<scratchpad>/pr<id>/post_pr_comments.py /<scratchpad>/pr<id>/spec.json --post
```

and mention that a permission rule for `az devops invoke` / `gh api` lets the agent post next time. Ask the user to paste the printed thread ids so the artifact can be updated.

### Step 7 — Record what was posted

Add or extend the *Posted to PR* row in the source artifact's *Review Context* table:

```markdown
| Posted to PR | 2026-10-16 — findings 1–5 as active inline threads on iteration 1: 110776 (1), 110777 (2), …; 6–7: 110781 (6), 110782 (7). 🟢 minor findings not posted. |
```

Append to the row on later batches; never rewrite earlier entries. A clean re-post after the user deleted threads is appended as its own entry naming the deleted ids (`— <date>, clean re-post after the user deleted 110776–110784: …`). Record the minor-findings comments separately (`minor findings as one general comment per PR: 110797 (!18707), 110798 (!18708)`). If the artifact's header links were emitted earlier in the conversation and lines shifted, re-emit them.

---

## 3. Output Format & Deliverables

Chat response, nothing else:

- One line per posted item: key, `path:line` (clickable, workspace-relative), host thread/comment id.
- Skipped items with the reason (already posted, outside the diff → posted as general comment, anchor drift → asked).
- Corrections made (anchor shifted, artifact citation fixed).
- If denied: the hand-over command from *Step 6*.

---

## 4. Verification & Validation

- The first posted thread's anchor was fetched back and matched the intended lines before the rest were posted.
- Every posted item has an id recorded in the artifact's *Posted to PR* row.
- Re-listing threads shows no duplicate titles among live threads, on every PR in the batch.
- Each PR's minor-findings comment holds only that PR's items, and every item from the artifact's list (the "+N more" tail included) appears in exactly one of them.
- No thread was resolved, no vote cast, and the PR description is unchanged unless asked.
