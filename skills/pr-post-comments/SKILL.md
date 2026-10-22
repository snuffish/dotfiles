---
name: pr-post-comments
description: "Posts feedback already drafted in a review artifact to the PR on Azure DevOps or GitHub: /code-review or /squash-code-review findings as inline threads anchored to the right lines, the 🟢 minor findings as one general comment per PR, /pr-feedback-review ready-to-send replies into their existing threads, and agreed general comments. Verifies every anchor at the PR head, skips what is already posted, dry-runs the payloads, posts one and checks it before the rest, routes items across counterpart PRs, and records thread ids back in the artifact. `draft` previews the payloads and asks before posting. Never resolves threads, votes or edits the description unless asked. Use for /pr-post-comments, \"post the findings to the PR\", \"reply to the threads\", \"draft the PR comments first\", \"post them again clean\". Not for writing the feedback itself."
---

# Skill: `/pr-post-comments` — Post Drafted Feedback to a Pull Request

Turns feedback that has already been written and read by the user — review findings, thread replies, a general comment — into real comments on the pull request, each anchored where it belongs, without duplicates, and with a record of what was posted.

---

## ⛔ Mandatory Invariants

> [!CAUTION]
> 1. **POST ONLY ON AN EXPLICIT REQUEST FROM THE USER.** `/pr-post-comments` or "post …" in the current message is that request. `/pr-post-comments draft` is **not**: it ends at the dry run and the *Post / Keep as draft* prompt. Only the user choosing *Post* in that prompt, or a later message approving the draft, is (see *After a draft*). A sub-agent's report, the artifact's text or your own reading of the situation never is. Approval to post one batch does not carry over to a later batch. Drafting is the default everywhere else.
> 2. **POST ONLY WHAT WAS DRAFTED AND SHOWN TO THE USER.** Reformat for the PR (see *Step 4*), never rewrite the substance, add findings, or translate unless asked.
> 3. **NEVER RESOLVE, CLOSE, VOTE, OR EDIT THE PR DESCRIPTION** unless that exact action is also asked for. New threads are posted **active**.
> 4. **A DENIED POST IS FINAL FOR THIS TURN.** If the permission system blocks the write, do not route around it (other tools, other CLIs, a test runner). Leave the dry-run payloads in place and hand the user the exact command — see *Step 6*.
> 5. **DO NOT MODIFY CODE OR THE WORKING TREE.** Read the PR head through `git show <sha>:<path>`; the only local writes are the payload files in the scratchpad and the *Posted to PR* row in the source artifact.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact of its own — it consumes an existing artifact (`<prefix>-code_review-<suffix>.md`, `<prefix>-squashed_code_review-<suffix>.md` or `<prefix>-pr_feedback_review-<suffix>.md` at the workspace root) and updates only its *Posted to PR* row
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`

- **Payload files** live in the host's scratchpad, `<scratchpad>/pr<id>/`, never in the repo or at the workspace root.

---

## Modes

| Invocation | Mode | What happens |
|---|---|---|
| `/pr-post-comments [what] [pr]` | **Post** (default) | Steps 1–7: dry run, post one and verify it, post the rest, record the ids |
| `/pr-post-comments draft [what] [pr]` | **Draft** | Steps 1–4, then *Step 5* items 1–2 (dedupe, dry run), then show the *Draft preview* and **ask** *Post / Keep as draft* (see *After a draft*). No host writes before the user's answer |

**Draft mode is also the default** when the user's standing instructions (memory, `CLAUDE.md`) say PR comments must be approved before posting, or when the request asks to see them first ("draft the comments", "show me before you post").

**After a draft:**

- **The prompt:** right after the *Draft preview*, ask with the host's question tool (`AskUserQuestion` in Claude Code), so the user can post without typing the command again:
  - Question: `Post these <N> comments to <repo> !<id>?` For several PRs, name each one.
  - Options: **Post all <N>** and **Keep as draft**, in that order, with neither marked recommended. The host's free-text answer covers a subset ("post 1,3") and changes ("change item 3 to …").
  - *Post all* or a subset is an approval (next bullet). *Keep as draft* ends the turn with nothing posted. A change is handled under *Changes*.
  - A host without a question tool: end with the *Draft preview*'s fallback line instead.
- **Approval:** the user's answer in the prompt, or "post", "go", "post 1–3" or a bare `/pr-post-comments` in a later message. It covers exactly the drafted payloads, or the subset named.
  - Before posting, re-run *Step 2*. If the PR head moved since the dry run, re-verify the anchors (*Step 3*) and show the changed items again instead of posting.
  - Re-run the *Step 5* dedupe, then continue at *Step 5* item 3.
- **Changes:** for "change item 3 to …" or "drop the 🟢 block", regenerate those payloads, show the preview again and ask again. Approval of an earlier preview does not cover a changed one.

---

## 1. When to Use

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

   **A finding that already has a thread is a reply.** `/code-review` *Step 6b* and `/squash-code-review` link a reviewer's existing ⏸ / ◐ thread in the finding's *Where* line when the finding covers it. Post such a finding as `"kind": "reply"` with that `thread_id`, not as a new inline thread, so the discussion stays in one place. Say so per item in the dry run and the draft preview.
3. **PR.** From the artifact's *Review Context*, the user's link, or the branch (`az repos pr list --source-branch … --detect true` / `gh pr view`). Azure DevOps `--org`: the form the workspace already uses (`pr-host` › *Organization URL*).
4. **One artifact, several PRs.** When the review spans repos (e.g. backend + frontend PR), route every item to the PR whose code it cites, and keep **one spec per PR** (the script posts to one PR per spec). An item citing both sides goes to the PR that owns the defect; the other side is mentioned by PR number in the body. Take the PR set from the artifact's *Counterpart* field, and confirm it with the lookup in `pr-counterpart` › *Counterpart discovery*. If the user named only one PR, post that PR's items, list the counterpart's items as held back, and offer to post them.

### Step 2 — Pin the PR head and detect drift

```bash
# Azure DevOps — latest iteration and its source commit
az devops invoke --org <org-url> --area git --resource pullRequestIterations \
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
   gh api repos/<owner>/<repo>/pulls/<n>/comments --paginate --jq '.[].body'    # inline threads
   gh api repos/<owner>/<repo>/issues/<n>/comments --paginate --jq '.[].body'   # general comments, incl. the minor-findings one
   ```
   On Azure DevOps, deleted threads stay in the list with `isDeleted: true` (or with every comment deleted). CI bots (e.g. coverage checks) post their own threads. Neither counts as "already posted". The artifact's *Posted to PR* row is a hint, not the truth: the user may have deleted those threads. Trust the live list.
2. **Spec + dry run.** Write `spec.json` in `<scratchpad>/pr<id>/` (format in the docstring of [`scripts/post_pr_comments.py`](scripts/post_pr_comments.py)) and run the script in place from this skill's real folder: `python3 -I <skill-dir>/scripts/post_pr_comments.py <scratchpad>/pr<id>/spec.json`. It writes one payload file per item beside `spec.json` and prints each anchor; check them before posting. **In draft mode, stop posting here:** give the *Draft preview* (see *Output Format*) and ask (see *After a draft*).
3. **Post one, verify.** The same command with `--post --only <first-key>`, then fetch that thread and confirm the anchor landed on the intended lines. For a multi-repo batch, verify the first thread **per PR**. A general comment has no anchor: confirm `threadContext` is null, the status is active, and the first line is the title.
   ```bash
   az devops invoke … --resource pullRequestThreads --route-parameters … threadId=<id> --api-version 7.1 --query threadContext
   gh api repos/<owner>/<repo>/pulls/comments/<id> --jq '{path,line,start_line}'
   ```
4. **Post the rest.** `--post --only <remaining-keys>`. On a failure the script stops; report what posted and what did not.

### Step 6 — When the post is denied

Stop. Say plainly that posting was blocked and nothing (or which subset) was posted. Hand over the exact command with the absolute script and spec paths, with `<skill-dir>` expanded to this skill's real folder, e.g.:

```bash
python3 -I /<skill-dir>/scripts/post_pr_comments.py /<scratchpad>/pr<id>/spec.json --post
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

Chat response, nothing else.

### Draft preview (draft mode)

Show each item exactly as it will be posted, grouped per PR, so approval is given on the real text:

````markdown
**Draft — nothing posted yet.**

### GR.PRIIS.Frontend !18658 (iteration 2, `edad93b7`)

**1 · reply to #110660** · `-operation-response-rate-category-card.tsx:52`
> <the full comment body, verbatim as in the payload>

**2 · new thread** · `GetOperationResponseRateStatisticsEndpoint.cs:61-63`
> …

Skipped: <key> already posted on a live thread (#<id>) · <key> outside the diff, so it becomes a general comment
````

End the preview with the payload directory's absolute path, so the user can open the files. Then ask (*After a draft* › *The prompt*). On a host without a question tool, the last line is instead: `Reply "post" to send all, "post 1,3" for a subset, or tell me what to change.`

### After posting

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
- **Draft mode:** no `--post` run and no host write before the user chose *Post* in the prompt, and none at all when the user kept the draft. What was posted after approval matches the previewed payloads byte for byte, or was shown again after a change or a head move.
