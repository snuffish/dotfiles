---
name: pr-post-comments
description: "Posts drafted review findings and thread replies from review artifacts to Azure DevOps or GitHub pull requests. Anchors inline comments to verified diff lines at PR head, batches minor findings into a summary comment, routes counterpart PR comments, and records remote thread IDs back into the artifact."
argument-hint: "[draft]"
---

# Skill: `/pr-post-comments` — Post Drafted Feedback to a Pull Request

Turns already-drafted review findings and thread replies into anchored comments on the pull request, deduplicating against live threads and recording the posted thread IDs back in the source artifact.

---

## Invariants

1. **Outward write discipline**: follow `outward-writes` (*Explicit request & draft mode*, *Denied write is final*, *Auth error vs denial*, *Read back*). `/pr-post-comments draft` stops after the dry run and preview.
2. **Post only what was drafted**: reformat for the PR (*Step 4*), never invent findings or change substance.
3. **Resolve only verified fixed replies**: new findings are posted **active**; a replied thread is set to Resolved (`fixed` / `resolveReviewThread`) only when *Which replied threads to resolve* holds. A declined suggestion gets `wontFix` only on the user's say-so (*Which replied threads to resolve*). Never set `closed` unasked, cast votes, or edit the PR description.
4. **Do not modify the working tree**: read the PR head via `git show <sha>:<path>`, write payloads to `<scratchpad>/pr<id>/`, and update only the source artifact's *Posted to PR* row and declared status fields.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: updates only the source artifact's *Posted to PR* row and declared status fields (rule 3 & rule 7)
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`
- `../_modules/outward-writes.md`

---

## Modes

| Invocation | Mode | What happens |
|---|---|---|
| `/pr-post-comments [what] [pr]` | **Post** (default) | Steps 1–7: dedupe, dry run, post first item and verify anchor, post remaining items, record IDs |
| `/pr-post-comments draft [what] [pr]` | **Draft** | Steps 1–4 + Step 5.1–5.2 (dedupe & dry run), then show the preview ([comment-formats.md](references/comment-formats.md)) and ask *Post all <N>* / *Keep as draft* |

- **`keep-open`** in arguments: post replies without resolving any thread.
- **Draft mode is also the default** when user rules require confirmation before posting PR comments or when the user asks to preview first.
- **After a draft**: if approved ("post", "post 1,3"), re-run Step 2 (re-verify anchors if the PR head moved) and Step 5.1 dedupe, then continue from Step 5.3. If edited ("change item 3"), regenerate payloads and re-preview.

### When to Use

| Situation | Use instead |
|---|---|
| Nothing drafted yet | [`/code-review`](../code-review/SKILL.md) or [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| Writing or updating the PR description | [`/pr-summary`](../pr-summary/SKILL.md) |
| Red pipeline on the PR | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |

---

## 2. Core Protocol & Workflow

Choose the CLI or MCP route per `pr-host` › *Tool: MCP vs CLI*. When using the Azure DevOps MCP server, follow [azure-devops-mcp.md](references/azure-devops-mcp.md) at each step.

### Step 1 — Resolve what to post

1. **Source**: the artifact named by the user, else the newest matching review artifact (`code_review`, `squashed_code_review`, `pr_feedback_review`) for this PR written by this host/model (`<prefix>…`, `artifact-protocol` › *Claim* › *Readers & family selection*). Another model's artifact is posted only when explicitly named.
2. **Selection**:

   | User says | Posted as |
   |---|---|
   | `"the findings"` | Every open 🔴/🟡 as one inline thread each + 🟢 minor findings as one general comment per PR ([comment-formats.md](references/comment-formats.md)) |
   | `"the new findings"` | Open 🔴/🟡 not yet in *Posted to PR*, plus the minor-findings comment if none is live |
   | `"only the 🔴/🟡"` | Open 🔴/🟡 inline threads only |
   | `"the minor findings"` / `"the 🟢"` | One standalone general comment per PR |
   | `"the replies"` | Every *Ready-to-Send Reply* whose recommendation includes replying |
   | `"clean"` / `"again"` (after deleting threads) | Re-post from the artifact's current text |

   - Never post resolved/refuted findings as threads.
   - **A finding linked to an existing open thread** (`/code-review` Step 6b or `/squash-code-review`) is posted as `"kind": "reply"` on that `thread_id`, not as a duplicate thread.
3. **PR**: resolve from (1) user URL/ID, (2) artifact *Review Context*, (3) PR ID in artifact filename/title, or (4) current branch (`az repos pr list --org <org-url> --project <project> --source-branch …` / `gh pr view`; ask if it differs from the artifact).
4. **Multi-repo artifacts**: route each item to the PR whose code it cites (`pr-counterpart` › *Counterpart discovery*), maintaining one `spec.json` per PR.

### Step 2 — Pin the PR head and detect drift

```bash
# Azure DevOps — latest iteration and its source commit
az devops invoke --org <org-url> --area git --resource pullRequestIterations \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<id> --api-version 7.1 \
  --query 'value[-1].{id:id,src:sourceRefCommit.commitId}' -o json
# GitHub
gh pr view <n> --json headRefOid,headRefName
```

If `<head>` moved since the artifact's reviewed head, run `git -C <repo> diff <reviewed>..<head> -- <path>`: shift line numbers when the hunk only moved; stop and ask if the anchored lines themselves changed.

### Step 3 — Verify every anchor at the PR head

```bash
git -C <repo> show <head>:<path> | awk 'NR>=<start> && NR<=<end> {print NR": "length($0)": "$0}'
```

- Confirm the lines match the quoted code (fix drifted line numbers in both the spec and the artifact). Set `end_offset = length(end line) + 1`.
- **Azure DevOps**: fetch each file's `changeTrackingId` in the latest iteration:
  ```bash
  az devops invoke --org <org-url> --area git --resource pullRequestIterationChanges \
    --route-parameters project=<p> repositoryId=<r> pullRequestId=<id> iterationId=<it> --api-version 7.1 \
    --query 'changeEntries[].{ct:changeTrackingId,path:item.path}' -o tsv
  ```
- **Outside the diff**: files not in the PR's changed entries (or lines outside a `RIGHT`-side diff hunk on GitHub) become general comments naming `path:line` (or `"subject_type": "file"` on GitHub).

### Step 4 — Turn each item into a PR comment

- **Title line**: `**<severity> <one-line claim>**` (strip artifact-only tags like `Verified`, finding numbers, `[plain]` links).
- **Body**: *What and why*, then *Fix* diff block (or *Options: (a) … (b) …*), then *Test to add* if present. Use repo-relative `File.cs:123` paths only.
- **Skip**: *In Plain Terms*, *Feature in Brief*, and praise. Format the 🟢 minor-findings block per [comment-formats.md](references/comment-formats.md).
- **Replies**: use *Ready-to-Send Reply* verbatim in its drafted language.
- **Voice**: run each comment body and reply not marked `Voice pass: done` through `outward-writes` › *Voice pass* (title line, `File.cs:123` paths and diff blocks stay verbatim) before the dry run, so the preview shows the text that gets posted.
- **Which replied threads to resolve**: set `"resolve": true` on a reply **only** when (1) the artifact marks the thread `✅ Fixed` or `↩ Superseded` (or its Action Checklist item is `[x]`), **and** (2) the fix commit is at the remote PR head (`git -C <repo> merge-base --is-ancestor <fix> <head>` and `git -C <repo> show <head>:<path>` confirms it), **and** `keep-open` was not passed. Leave active whenever the reply asks a question, defers (Path B), or is partial/unpushed.
- **Declined suggestions** (Azure DevOps): `"resolve": "wontFix"` (or `"byDesign"`) on a reply that declines the suggestion, **only** when the user picks that status in the draft preview or the arguments; otherwise the thread stays active for the reviewer. A reply that ends in a question to the reviewer always stays active.

### Step 5 — Dedupe, dry-run, post one, verify, post the rest

1. **Dedupe**: fetch live threads (`pr-host` › *Fetch discussion threads*, [pr-host-threads.md](../_modules/references/pr-host-threads.md); on GitHub also check `issues/<n>/comments` for the minor-findings comment) and skip any item whose title line is already on a live non-deleted thread.
2. **Spec + dry run**: copy [`templates/spec.json`](templates/spec.json) to `<scratchpad>/pr<id>/spec.json`, populate all fields, and run:
   ```bash
   python3 -I <skill-dir>/scripts/post_pr_comments.py <scratchpad>/pr<id>/spec.json
   ```
   (Add `--via mcp` for the MCP route: [azure-devops-mcp.md](references/azure-devops-mcp.md).) In **draft mode**, stop here, print the preview ([comment-formats.md](references/comment-formats.md)), and ask.
3. **Post one & verify**: run with `--post --only <first-key>` (per PR), then read the posted thread back (`pullRequestThreads` `threadContext` & `status` on ADO; `pulls/comments/<id>` on GitHub) to verify the anchor and resolved state before posting the rest.
4. **Post the rest**: run with `--post --only <remaining-keys>` (or remaining `mcp-*.json` files). Stop on any error and report what posted.

### Step 6 — When the post is denied or blocked

Follow `outward-writes` › *Denied write is final* and *Auth error vs denial*. Hand over the exact command:
```bash
python3 -I /<skill-dir>/scripts/post_pr_comments.py /<scratchpad>/pr<id>/spec.json --post
```
(plus `mcp-*.json` paths when on the MCP route) and ask the user to paste the resulting thread IDs so Step 7 can record them.

### Step 7 — Record what was posted

1. Append to (or create) the **Posted to PR** row in the source artifact's *Review Context* table with the date, iteration, finding numbers → thread IDs, resolved reply IDs, and minor-findings comment ID.
2. Update all declared **status fields** (`artifact-protocol` › *Rules* › rule 7; `/pr-feedback-review` › *6.4 — Status fields*), `grep` for stale `⏸` / `Not addressed` hits, and re-emit the `artifact-protocol` › *Chat link block* if line numbers shifted.

---

## 3. Output Format & Deliverables

- **Draft mode**: see [comment-formats.md](references/comment-formats.md) › *Draft Preview Format (`draft` mode)*.
- **After posting**: one line per posted item (`key`, clickable `path:line`, thread/comment ID, resolved vs. active status), skipped items with reason, anchor adjustments, and updated artifact link block.

---

## 4. Verification & Validation

- First posted thread per PR was read back and its anchor verified before posting the rest.
- Every posted item has its remote ID recorded in *Posted to PR*, and all status fields are synced (`artifact-protocol` rule 7).
- No duplicate live thread titles exist; only qualifying reply threads were resolved; no code or PR description was modified.
