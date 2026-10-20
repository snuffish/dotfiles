# pr-host

How a Command finds and reads a pull request on its host (Azure DevOps, GitHub, GitLab): parsing a PR or work-item URL, choosing the organization URL, normalising branch names, resolving the PR from a branch, fetching the PR with its work items and acceptance criteria, fetching discussion threads, and what to do when a fetch fails. Read-only throughout; posting is `/pr-post-comments`' job. Depends on no other Module. Finding a PR's sibling in another repo is [pr-counterpart.md](pr-counterpart.md).

---

## Parse a PR or work-item URL

| Host | PR URL | Parts |
|---|---|---|
| Azure DevOps | `https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{prId}` or `https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{prId}` | `org`, `project`, `repo`, `prId` |
| GitHub | `https://github.com/{owner}/{repo}/pull/{n}` | `owner`, `repo`, `n` |
| GitLab | `https://{host}/{group}/{project}/-/merge_requests/{n}` | `group`, `project`, `n` |
| Bitbucket | `https://bitbucket.org/{workspace}/{repo}/pull-requests/{n}` | `workspace`, `repo`, `n` |

Work items: `https://dev.azure.com/{org}/{project}/_workitems/edit/{id}`, `https://{org}.visualstudio.com/{project}/_workitems/edit/{id}`, or a bare `#{id}`; GitHub and GitLab issues use their issue URLs.

`{repo}` is often a GUID rather than a name. Pass it through unchanged; the API accepts either. A bare PR id (`18170`, `#18170`) takes host, org and project from the current repo's remote.

The workspace repo a PR belongs to is the one whose `origin` matches the PR's `{repo}`. In a multi-repo workspace, check each child repo's `git remote get-url origin`.

## Organization URL

Azure DevOps accepts both forms of the organization URL, `https://dev.azure.com/{org}` and the older `https://{org}.visualstudio.com`. `az repos pr show` works with either: checked 2026-10-20 with az 2.87.0 and azure-devops 1.0.5, both exit 0 for the same PR. Use the form the workspace already uses, in this order:

1. The form in the URL the user pasted.
2. The project Profile's tracker fields, when one is loaded (`project-profile`).
3. The `organization` default from `az devops configure --list`.
4. The host of the repo's git remote (`vs-ssh.visualstudio.com` → `https://{org}.visualstudio.com`, `ssh.dev.azure.com` → `https://dev.azure.com/{org}`).

Do not rewrite one form into the other. If a call fails with an authentication error, see *When a fetch fails* before changing anything.

Pass `--org` explicitly on every `az repos` / `az boards` / `az devops invoke` call. Without it, `--detect` infers the org from the current directory's remote and falls back to the `az devops configure` defaults, so the result depends on where the command runs and on each user's defaults. `az repos pr show` accepts only `--id`, `--org`, `--detect` and `--open`; `pr list` takes `--project` and `--repository`.

## Branch names

Azure DevOps returns a PR's branches as full refs: `sourceRefName` / `targetRefName` are `refs/heads/feature/x`, in the REST API and in `az repos pr show` output alike. `origin/refs/heads/feature/x` never resolves, so strip the prefix before building a remote-tracking ref:

```bash
SRC=${sourceRefName#refs/heads/}    # feature/x
TGT=${targetRefName#refs/heads/}    # main
git -C <repo> fetch origin "$SRC" "$TGT"
git -C <repo> rev-parse "origin/$SRC"
```

`az repos pr list --source-branch` / `--target-branch` add the prefix themselves, so a bare branch name is fine there. GitHub's `headRefName` / `baseRefName` are already bare.

**A resolved PR settles the diff base:** its target branch is the base (`origin/$TGT`). Use the remote's default branch only when there is no PR.

## Resolve the PR from a branch

When no URL or id was given, a checked-out branch almost always has a PR. Find it rather than skipping the description:

```bash
# Azure DevOps
az repos pr list --org <org-url> --project <project> --source-branch "$(git -C <repo> rev-parse --abbrev-ref HEAD)" \
  --status active --query '[].{id:pullRequestId,title:title,tgt:targetRefName}' -o json
# add --status all when the PR may already be completed or abandoned; --repository <name> to narrow

# GitHub: no argument means "the PR for the current branch"
gh pr view --json number,title,body,headRefName,baseRefName,url
```

**In a multi-repo workspace, do this per repo.** A feature split across repos has one PR per repo, each with its own description and work item:

```bash
for d in */; do
  [ -d "$d/.git" ] || [ -f "$d/.git" ] || continue
  b=$(git -C "$d" rev-parse --abbrev-ref HEAD)
  echo "== $d ($b)"
  az repos pr list --org <org-url> --project <project> --source-branch "$b" --status active \
     --query '[].{id:pullRequestId,title:title}' -o tsv
done
```

Report which repos resolved to a PR and which did not. A repo still sitting on the integration branch is itself worth saying out loud.

## Fetch the PR, its work items and acceptance criteria

Check which CLIs exist first (`command -v az gh glab`).

```bash
# Azure DevOps
az repos pr show --id <prId> --org <org-url> \
  --query '{title:title,status:status,repo:repository.name,src:sourceRefName,tgt:targetRefName,desc:description,head:lastMergeSourceCommit.commitId}' -o json
az repos pr work-item list --id <prId> --org <org-url> -o json            # linked work items
az boards work-item show --id <id> --org <org-url> --expand all -o json   # fields + relations
#   System.Title, System.State, System.Description, Microsoft.VSTS.Common.AcceptanceCriteria,
#   System.Rev, System.ChangedDate; relations: Hierarchy-Reverse (parent), Hierarchy-Forward (children), Related

# GitHub
gh pr view <n> --json title,body,state,headRefName,baseRefName,files,reviewDecision,reviews
# GitLab
glab mr view <n>
```

- **Follow linked work items.** That is usually where the acceptance criteria live. A PR's task often says "implement per #parent", and the parent story holds the spec.
- **Descriptions and AC fields are HTML.** Strip tags before quoting (`<li>` → `- `, `<br>` / `</p>` → newline, unescape entities). When a work item has no AC field, say so and name what you used instead (parent, description, linked page).
- **The description states intent; the diff states truth.** Where they disagree the diff wins, and the disagreement is itself a finding for the calling Command.

## Fetch discussion threads

**Azure DevOps** has no `az repos pr thread` command; use `az devops invoke`. A thread's position is `threadContext.rightFileStart`, an object `{line, offset}`, not a number:

```bash
az devops invoke --org <org-url> --area git --resource pullRequestThreads \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<prId> \
  --api-version 7.1 -o json > threads.json

python3 - threads.json <<'PY'
import json, sys
for t in json.load(open(sys.argv[1])).get('value', []):
    if t.get('isDeleted'):
        continue
    ctx = t.get('threadContext') or {}
    line = (ctx.get('rightFileStart') or {}).get('line')
    human = [c for c in t.get('comments', [])
             if not c.get('isDeleted') and c.get('commentType') != 'system'
             and c.get('author', {}).get('displayName') != 'Azure Pipelines Test Service']
    if human:
        print(f"=== Thread {t['id']} | {t.get('status')} | {ctx.get('filePath')}:{line} ===")
        for c in human:
            print(f"[{c['author']['displayName']}] ({c.get('publishedDate')}):\n{c.get('content')}\n")
PY
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

## When a fetch fails

Do not continue silently as if no PR was given, and never guess a description from a branch name.

- **Authentication error** (`The requested resource requires user authentication`): the CLI is not signed in for that organization. Give the user the one-liner and continue diff-only meanwhile, saying so:
  ```bash
  az devops login --organization <org-url>    # paste a PAT with Code: Read (Work Items: Read for work items)
  # or: export AZURE_DEVOPS_EXT_PAT=<pat>
  ```
  Try the other organization URL form only after that, and report which one worked.
- **CLI missing**: say which one, and offer to work from the diff alone.
- **Fetch blocked entirely**: ask the user to paste the description.
- **A web fetch of a private PR URL** returns a login page, not the PR. Never treat that as the description.

**Offline fallback.** The branch name and commit subjects usually carry the work-item id (`feature/30342_persist-…`, `#30342: <subject>`):

```bash
git -C <repo> rev-parse --abbrev-ref HEAD
git -C <repo> log --oneline <base>..HEAD
```

That gives an id to quote and hand back to the user, but **not** the acceptance criteria. Say which of the two you have.
