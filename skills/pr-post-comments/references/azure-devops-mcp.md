# Azure DevOps MCP Route for `/pr-post-comments`

On-demand reference for [SKILL.md](../SKILL.md). Use the `azure-devops` MCP server when the project Profile's **PR tooling** prefers it or when an `az` CLI call fails with `The requested resource requires user authentication` (`pr-host` › *Tool: MCP vs CLI*). Keep one route for the whole run.

---

- **Parameters**: MCP tools take `project` + `repositoryId` (name or GUID) + `pullRequestId`. Pass `fullResponse: true` whenever `isDeleted`, `commentType` (`3` = system), or `parentCommentId` are needed.
- **Step 2 (Pin PR head & iteration)**: call `repo_pull_request` `get` with `includeChangedFiles: true`. The head is `lastMergeSourceCommit.commitId` and the latest iteration is `changedFilesSummary.secondComparingIteration`.
- **Step 3 (`changeTrackingId`)**: read `changedFilesSummary.changeEntries[]` (`changeTrackingId`, `item.path`) from the same `get` call, paging by passing `nextSkip`/`nextTop` back as `skip`/`top` until `nextSkip` is `0`.
- **Step 5.1 (Dedupe)**: call `repo_pull_request_thread` `list` with `fullResponse: true` (page with `skip`/`top`).
- **Step 5.2 (Dry-run payload generation)**: run `python3 -I <skill-dir>/scripts/post_pr_comments.py <scratchpad>/pr<id>/spec.json --via mcp`. The script writes `mcp-<key>.json` per item and `mcp-<key>-resolve.json` for resolved replies (`create`, `reply`, and `update_status` `Fixed`).
- **Step 5.3–5.4 (Post one, verify, post rest)**: call the MCP `tool` with `arguments` from `mcp-<first-key>.json` unchanged (plus its `-resolve` file if present). Read the thread back via `repo_pull_request_thread` `list` (`fullResponse: true`) or `list_comments` on `threadId` to confirm `threadContext` and `status` before posting the rest. Send every remaining `mcp-<key>.json` call in **one message** (parallel calls, not one per turn), then all their `-resolve` files in a second message, since a resolve needs its reply to exist. Record each call's thread ID or error per key; on a partial failure re-send only the failed keys. Parallel creates can land in a different order than the keys. (An MCP reply takes no `parentCommentId` and lands with `0` inside the same thread.)
- **Step 6 (Handover on auth/permission block)**: hand over both the CLI command (`az devops login` + `post_pr_comments.py --post`) and the `mcp-*.json` paths (noting permission rule `mcp__azure-devops__repo_pull_request_thread_write`).
