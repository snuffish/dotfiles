# pr-host

How a Command finds and reads a pull request or work item on its host (Azure DevOps, GitHub, GitLab, Bitbucket). Read-only throughout; outward writes follow [outward-writes.md](outward-writes.md). Counterpart PR discovery across repos is in [pr-counterpart.md](pr-counterpart.md).

---

## Parse a PR or work-item URL

| Host | PR URL | Parts |
|---|---|---|
| Azure DevOps | `https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{prId}` or `https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{prId}` | `org`, `project`, `repo`, `prId` |
| GitHub | `https://github.com/{owner}/{repo}/pull/{n}` | `owner`, `repo`, `n` |
| GitLab | `https://{host}/{group}/{project}/-/merge_requests/{n}` | `group`, `project`, `n` |
| Bitbucket | `https://bitbucket.org/{workspace}/{repo}/pull-requests/{n}` | `workspace`, `repo`, `n` |

Work items: `https://dev.azure.com/{org}/{project}/_workitems/edit/{id}`, `https://{org}.visualstudio.com/{project}/_workitems/edit/{id}`, or a bare `#{id}`; GitHub and GitLab issues use their issue URLs. `{repo}` may be a GUID; pass it through unchanged. A bare id takes host, org, and project from the current repo's remote. In a multi-repo workspace, match `{repo}` against each child repo's `git remote get-url origin`.

## Organization URL

Azure DevOps accepts both `https://dev.azure.com/{org}` and `https://{org}.visualstudio.com` ([ADR-0004](../../docs/adr/0004-pr-host-access-is-a-module.md)). Use the form the workspace already uses, in this order:
1. The URL the user pasted.
2. The project Profile's **Tracker** / **PR tooling** fields (`project-profile`).
3. `organization` from `az devops configure --list`.
4. The repo's git remote (`vs-ssh.visualstudio.com` → `https://{org}.visualstudio.com`, `ssh.dev.azure.com` → `https://dev.azure.com/{org}`).

Pass `--org <org-url>` explicitly on every `az repos` / `az boards` / `az devops invoke` call (never rely on `--detect` or ambient defaults). `az repos pr show` accepts only `--id`, `--org`, `--detect`, and `--open`; `pr list` also takes `--project` and `--repository`.

## Tool: MCP vs CLI

1. Check the project Profile's **PR tooling** and **Tracker** fields (`project-profile` › *Shared fields*) first — obey any per-operation override (e.g. MCP for interactive reads/writes, `az` CLI for bulk JSON queries).
2. Otherwise prefer an available host MCP tool for single-item reads/writes and the host CLI (`az`, `gh`, `glab`) for bulk queries, pipelines, or REST invocations.
3. On MCP auth or transport errors, fall back to the CLI (`outward-writes` › *Auth error vs denial*).

## Branch names & Diff base

Azure DevOps returns `sourceRefName` / `targetRefName` with `refs/heads/` prefixed. Strip it before building a git ref:

```bash
SRC=${sourceRefName#refs/heads/}
TGT=${targetRefName#refs/heads/}
git -C <repo> fetch origin "$SRC" "$TGT"
```

**Diff base resolution:**
1. **PR resolved**: base is `origin/$TGT` (the PR's target branch).
2. **No PR**: base is the remote default branch (`git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD`, running `git -C <repo> remote set-head origin --auto` first if unset).
3. **Never use `@{u}`** as the diff base (it tracks the feature branch itself once pushed).
4. **Always use three-dot diff** (`git -C <repo> diff <base>...HEAD`) so changes on `<base>` since branch-off are excluded.

## Resolve the PR from a branch

When no URL or id was given, check whether the current branch has an open PR:

```bash
# Azure DevOps (add --status all when the PR may be completed/abandoned; --repository <name> to narrow)
az repos pr list --org <org-url> --project <project> --source-branch "$(git -C <repo> rev-parse --abbrev-ref HEAD)" \
  --status active --query '[].{id:pullRequestId,title:title,tgt:targetRefName}' -o json

# GitHub / GitLab
gh pr view --json number,title,body,headRefName,baseRefName,url
glab mr view
```

In a multi-repo workspace (`git-worktrees` › *Repo Resolution*), run this per repo and report which repos resolved to a PR and which sit on the default branch.

## Fetch the PR, its work items and acceptance criteria

```bash
# Azure DevOps
az repos pr show --id <prId> --org <org-url> \
  --query '{title:title,status:status,repo:repository.name,src:sourceRefName,tgt:targetRefName,desc:description,head:lastMergeSourceCommit.commitId,reviewers:reviewers[].{name:displayName,vote:vote,req:isRequired}}' -o json
az repos pr work-item list --id <prId> --org <org-url> -o json
az boards work-item show --id <id> --org <org-url> --expand all -o json
# Work-item discussion comments when spec details live in comments:
az devops invoke --org <org-url> --area wit --resource comments \
  --route-parameters project=<project> workItemId=<id> --api-version 7.1-preview.4 -o json

# GitHub / GitLab
gh pr view <n> --json title,body,state,headRefName,baseRefName,files,reviewDecision,reviews
gh issue view <id> --comments
glab mr view <n> && glab issue view <id> --comments
```

- **Follow linked work items, comments, and wiki links**: tasks often point to a parent story (`Hierarchy-Reverse`), work-item comments, or a wiki page for acceptance criteria.
- **Strip HTML** from descriptions and AC fields (`<li>` → `- `, `<br>`/`</p>` → newline).
- **The description states intent; the diff states truth.** Disagreements between them are findings.
- **Azure DevOps reviewer `vote` values**: `10` Approved, `5` Approved with suggestions, `0` No vote, `-5` Waiting for author, `-10` Rejected.

## Fetch discussion threads

Read [references/pr-host-threads.md](references/pr-host-threads.md) for the Azure DevOps `pullRequestThreads` invocation, GitHub REST + GraphQL `reviewThreads` query, and dual-navigation thread link formatting.

## When a fetch fails

Never guess a PR description or work item from a branch name:
- **Authentication error**: give the user `az devops login --organization <org-url>` (or `gh auth login`), continue diff-only meanwhile, and say so. Try the alternate Azure DevOps org URL form only after login fails.
- **CLI missing or fetch blocked**: say which tool is missing or blocked, offer to work diff-only, or ask the user to paste the description. Never treat a login-redirect HTML page from a web fetch as the PR.
- **Offline fallback**: extract the work-item ID from `git -C <repo> rev-parse --abbrev-ref HEAD` and `git -C <repo> log --oneline <base>..HEAD` to cite the ID, and state explicitly that acceptance criteria were not fetched.
