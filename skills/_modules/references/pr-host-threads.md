# PR Discussion Threads & Dual-Navigation Links

On-demand reference for [pr-host.md](../pr-host.md) › *Fetch discussion threads* and [artifact-protocol.md](../artifact-protocol.md).

---

## Fetch discussion threads

**Azure DevOps** has no `az repos pr thread` command; use `az devops invoke` (or the Azure DevOps MCP thread tool when available). A thread's position is `threadContext.rightFileStart`, an object `{line, offset}`, not a number:

```bash
az devops invoke --org <org-url> --area git --resource pullRequestThreads \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<prId> \
  --api-version 7.1 -o json > <scratchpad>/threads.json
```

In a worktree-isolated session the guard refuses this command (it reads `--area git` as a git call). Use the Azure DevOps MCP `repo_pull_request_thread` with `action: "list"`, `top: 200` and `fullResponse: true` (the trimmed default drops `isDeleted` and `commentType`), save only the JSON array between the untrusted-content banner lines, and wrap it as `{"value": <array>}` so `ado_threads.py` reads it.

Then print the human comments with [ado_threads.py](../scripts/ado_threads.py) (it skips deleted threads, system comments and the test bot):

```bash
python3 -I ~/.terminal/skills/_modules/scripts/ado_threads.py <scratchpad>/threads.json
```

Deleted threads stay in the list with `isDeleted: true`, or with every comment deleted. CI bots post their own threads. Neither counts as a reviewer's thread. Each thread's `pullRequestThreadContext.iterationContext` says which iteration it was written against, and so how far the code may have moved since.

**GitHub** splits a PR's comments in two, and REST pages at 30 items by default:

```bash
gh api --paginate repos/{owner}/{repo}/pulls/{n}/comments    # inline review comments on the diff
gh api --paginate repos/{owner}/{repo}/issues/{n}/comments   # general conversation comments (a PR is an issue)
```

REST review comments carry no resolved or outdated state. Get it per thread from GraphQL, and join on `comments.nodes[0].databaseId`, the REST `id` of each thread's first comment:

```bash
gh api graphql --paginate -F owner='{owner}' -F repo='{repo}' -F pr={n} -f query='
  query($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $endCursor) {
          pageInfo { hasNextPage endCursor }
          nodes { isResolved isOutdated path line
                  comments(first: 1) { nodes { databaseId } } }
        }
      }
    }
  }'
```

---

## PR Discussion Thread Links (Dual Navigation)

When artifacts reference discussion threads or comments from a pull request (`pr_feedback_review`, `code_review`, `squash_code_review`), every thread reference must provide **dual navigation**:

1. **Intra-Document Navigation**: Navigates locally within the markdown file to the thread's detailed analysis section: `[#<id>](#thread-<id>)`.
2. **Direct Remote Link**: Opens the specific discussion thread in the remote host:
   - **Azure DevOps**: `<prWebUrl>?discussionId=<threadId>`  
     *(e.g. `https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{prId}?discussionId=106813`)*
   - **GitHub**: `<prWebUrl>#discussion_r<commentId>` or `<prWebUrl>#issuecomment-<id>`

### Formatting Standards

- **In Tables & Triage Matrices**: Keep the internal anchor and append the remote link in parentheses:
  ```markdown
  | [#106813](#thread-106813) ([devops](https://dev.azure.com/.../pullrequest/18176?discussionId=106813)) | `File.cs:42` | ...
  ```
- **In Section Headings**: Include the direct remote link on the thread number, wrapped in the intra-document anchor:
  ```markdown
  ### <a id="thread-106813"></a>Thread [#106813](https://dev.azure.com/.../pullrequest/18176?discussionId=106813): Revoke permissions when terminated
  ```
