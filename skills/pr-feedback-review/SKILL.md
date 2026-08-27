---
name: pr-feedback-review
description: Review, triage, and evaluate reviewer feedback, discussion threads, and votes on a pull request. Analyzes technical implications against the codebase and provides actionable recommendations and response options.
---

# PR Feedback Review Skill

Use this skill whenever the user asks to review pull request feedback, triage review comments, assess reviewer objections or suggestions, or plan responses/actions for PR comments.

> **Never** produce an implementation plan for a feedback review. Go straight to fetching context, analyzing discussion threads against the codebase, and presenting findings and options.

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

---

## Step 3 — Investigate Codebase Context & Related PRs

Do not analyze comments in a vacuum. Cross-reference each comment with the actual codebase:

1. **Inspect Targeted Code**:
   - Use `view_file` or `grep_search` to view the specific lines, classes, queries, or configs mentioned in the feedback.
2. **Check Downstream & Stacked Dependencies**:
   - Check if other PRs or branches branch off this PR (e.g. feature branch stacking).
   - Check linked work items (`az repos pr work-item list --id <prId>` or `az boards work-item show --id <id>`).
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

## Step 6 — Output Format

Format the output clearly and concisely:

```markdown
### PR Overview & Review Status
- **PR**: [<Title>](<url>) (`<source>` → `<target>`)
- **Status**: Active / Needs Attention
- **Reviewers**:
  - **<Reviewer Name>**: `<Vote / Status>` (e.g. `-5 Changes Requested` / `Approved`)

---

### Feedback Summary & Evaluation

#### Thread #<ThreadId>: <File / Topic Summary>
* **Author:** <Name> (<Timestamp>)
* **Status:** Active / Closed
* **Location:** `[<file>:<line>]` (or PR level)
* **Reviewer Comment:**
  > <Quote of reviewer's comment>

##### Technical Analysis
* **Core Concern:** <What the reviewer is pointing out>
* **Architectural Assessment:** <How this fits into the codebase, EF Core / API conventions, constraints>
* **Tradeoffs & Risks:** <Pros/cons of changing vs keeping as-is, downstream impact>

---

### Recommended Course of Action

#### Option 1 — <Brief Option Title> (Recommended)
<Actionable steps and rationale>

#### Option 2 — <Alternative Option Title>
<Actionable steps and rationale>

---

### Draft Reply to Reviewer

> <Draft text ready for the author to post in the PR thread>
```

---

## Heuristics & Common Pitfalls

- **Do not ignore reviewer votes**: A `-5` or `-10` vote blocks PR completion in most CI/CD branch policies. Highlight blocking feedback prominently.
- **Check for stacked branches**: If another active feature branch branches off this PR, major refactoring in this PR will require rebasing the downstream branch. Mention this tradeoff explicitly.
- **Differentiate opinion vs defect**: A suggestion to use implicit relationships or rename a variable is an architectural preference or cleanup; a missing authorization filter or data loss migration is a defect. Make the distinction crisp.
- **Match the language of the PR conversation**: If the PR thread discussions and reviewers communicate in Swedish (common in Swedish public sector / municipal projects like PRIIS), provide draft replies in Swedish, along with English technical summaries.
