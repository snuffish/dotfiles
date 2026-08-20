---
name: code-review
description: Perform a structured, high-quality review of code changes, identifying potential bugs, design issues, and performance optimizations. Accepts an optional pull-request URL/ID or work-item ID — and resolves the PR from the current branch when none is given — reading its description, acceptance criteria and branches before reviewing.
---

# Code Review Skill

Use this skill whenever the user requests a code review, feedback on a pull request, or a review of specific changes in the workspace.

---

## Step 1 — Determine Scope

Before reviewing any code, establish **what** to review:

| User says | What to diff |
|---|---|
| `staged` / `commit` | `git diff --staged` |
| `unstaged` / `working` | `git diff` |
| `branch` / `pr` / (default) | All commits on the current branch vs. its remote base |
| Specific file(s) | Read those files directly |
| `frontend` / `backend` | Branch diff, scoped to that sub-directory |
| A **pull-request URL** or bare PR id | Resolve it first — see *Pull-Request References* below |
| A work item / issue id (`#30342`, `AB#30342`) | Read the work item, then find its PR or branch |

### Pull-Request References

When the user passes a PR/MR URL or id, resolve it **before** diffing. The description and its acceptance criteria state what the change was *supposed* to do — the single most useful piece of context a reviewer can have, and the only way to spot "promised but not implemented".

Parse the URL into its parts. Azure DevOps:

```text
https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{prId}

e.g.  .../grutbildning/PRIIS/_git/52f22501-...-f597ebeaacf9/pullrequest/18106
      org = grutbildning   project = PRIIS   repo = <guid>   prId = 18106
```

`{repo}` is often a GUID rather than a name — pass it through unchanged, the API accepts either. Other hosts: GitHub `/{owner}/{repo}/pull/{n}`, GitLab `/{group}/{project}/-/merge_requests/{n}`, Bitbucket `/{workspace}/{repo}/pull-requests/{n}`.

#### No URL given — resolve the PR from the branch

Do not skip the description just because the user did not paste a link. A checked-out branch almost always *has* a PR; find it.

```bash
# Azure DevOps — run inside the repo; --detect reads org/project from the git remote
az repos pr list --source-branch "$(git rev-parse --abbrev-ref HEAD)" \
  --status active --detect true \
  --query '[].{id:pullRequestId,title:title,tgt:targetRefName}' -o json

# GitHub — no argument means "the PR for the current branch"
gh pr view --json number,title,body,baseRefName
```

`--detect true` resolves org/project from either an HTTPS or an SSH `dev.azure.com` remote. Add `--status all` if the PR may already be completed or abandoned; widen to `--repository <name>` when reviewing a repo you are not standing in.

Then feed the resulting id into the fetch commands above.

**In a multi-repo workspace, do this per repo.** A feature split across repos has one PR *per repo*, each with its own description and its own work item — resolving only the one you happen to be standing in gets you half the intent:

```bash
for d in */; do
  [ -d "$d/.git" ] || continue
  b=$(git -C "$d" rev-parse --abbrev-ref HEAD)
  echo "== $d ($b)"
  (cd "$d" && az repos pr list --source-branch "$b" --status active --detect true \
     --query '[].{id:pullRequestId,title:title}' -o tsv)
done
```

Report which repos resolved to a PR and which did not — a repo still sitting on the integration branch is itself worth saying out loud.

##### Finding the counterpart PR in the other repo

The two sides usually carry **different** work item ids (e.g. backend `#30342`, frontend `#30343`), so matching on the number in the branch name will not find the sibling. Walk the work-item relations instead:

```bash
az boards work-item relation show --id <workItemId> --org https://dev.azure.com/<org> -o json
```

Look for `Parent`, `Related`, and child links; the sibling story is normally under the same parent feature. Its own branch/PR is then discoverable with the commands above.

#### Fetch the PR and its work item

Use whichever CLI the host provides. Check availability first (`command -v az gh glab`):

```bash
# Azure DevOps (az + azure-devops extension)
az repos pr show --id <prId> --org https://dev.azure.com/<org> \
  --query '{title:title,status:status,repo:repository.name,src:sourceRefName,tgt:targetRefName,desc:description}' -o json
az repos pr work-item list --id <prId> --org https://dev.azure.com/<org> -o json   # linked work items

# GitHub
gh pr view <n> --json title,body,headRefName,baseRefName,state,files

# GitLab
glab mr view <n>
```

`--detect true` lets `az` infer the org/project from the git remote when you are inside the repo, so an explicit `--org` is only needed when the URL points at a different repo than the working directory.

Follow linked work items — that is usually where the acceptance criteria actually live:

```bash
az boards work-item show --id <workItemId> --org https://dev.azure.com/<org> \
  --query '{title:fields."System.Title",state:fields."System.State",desc:fields."System.Description",ac:fields."Microsoft.VSTS.Common.AcceptanceCriteria"}' -o json
```

Descriptions and AC fields are usually **HTML**. Strip the tags before quoting them.

**A resolved PR also settles the diff base:** its `targetRefName` *is* the base — use it directly instead of the fallback chain in *Branch Discovery* below.

#### When the fetch fails

Do not silently continue as if no reference was given, and do not guess the contents from the branch name.

- **Auth error** (`The requested resource requires user authentication`) — the CLI is installed but not signed in. Give the user the one-liner and continue diff-only meanwhile, saying so:
  ```bash
  az devops login --organization https://dev.azure.com/<org>   # paste a PAT with Code: Read
  # or: export AZURE_DEVOPS_EXT_PAT=<pat>
  ```
- **CLI missing** — say which one and offer to work from the diff alone.
- **Fetch blocked entirely** — ask the user to paste the description.

An unauthenticated web fetch of a private PR URL returns a login page, not the PR. Never treat that as the description.

#### Offline fallback

When no CLI is authenticated, the branch name and commit subjects still carry the work item id — most conventions embed it (`feature/30342_persist-...`, `#30342: <subject>`):

```bash
git rev-parse --abbrev-ref HEAD
git log --oneline <base>...HEAD
```

That gives you the id to quote and to hand back to the user, but **not** the acceptance criteria. Say which one you have. Never infer what a description said from a branch slug.

#### Get the right code checked out

A PR URL usually means the user is *not* on that branch. Verify before diffing, and state the mismatch rather than reviewing the wrong tree:

```bash
git rev-parse --abbrev-ref HEAD                       # where am I?
git fetch origin <sourceRefName>                      # sourceRefName from the PR payload
az repos pr checkout --id <prId>                      # ADO: checks out the source branch if the tree is clean
gh pr checkout <n>                                    # GitHub equivalent
```

If the tree is dirty, say so and let the user decide — never stash or check out over their work.

#### How much to trust the description

**The description states intent; the diff states truth.** Where they disagree the diff wins, and the disagreement is itself a finding:

- AC promises behavior with no corresponding change in the diff → 🔴/🟡 *claimed but not implemented*.
- The diff changes user-visible behavior the description never mentions → review it anyway and flag the unannounced change; that is where regressions hide.
- The description describes an earlier revision of the branch → note it as stale and follow the diff.

Never let the description's structure or omissions shape the review. It is evidence, not an outline.

---

### Branch Discovery

When the scope is a branch diff, find the correct base automatically — **do not guess**:

```bash
# 1. Find the upstream tracking ref recorded for this branch
git rev-parse --abbrev-ref --symbolic-full-name @{u}   # e.g. origin/develop

# 2. Fall back: find the merge-base with common integration branches
git merge-base HEAD origin/develop
git merge-base HEAD origin/main

# 3. Build the diff using the merge-base (three-dot syntax):
git diff $(git merge-base HEAD <base>)...HEAD --name-only
```

Always use the **three-dot** form (`A...B`) so you see only the commits introduced by this branch, not divergent commits on the base.

---

## Step 2 — Gather Context

1. **List changed files** first (`--name-status` or `--name-only`) to understand the blast radius before reading code.
2. **For small diffs** (< ~200 lines): read the raw diff directly.
3. **For large diffs**: read each changed file in full with `view_file`. Do **not** rely solely on truncated diff output — you will miss essential context.
4. **Deleted / moved files**: for every deleted file, grep the codebase for remaining imports or references to ensure nothing is left dangling.
5. **Do not** run `npm ci`, `npm install`, `dotnet restore`, or any install/build commands unless the user explicitly requests it.
6. **Do not** run the linter or test suite unless the user explicitly requests it.
7. **Skip auto-generated files** (e.g., `routeTree.gen.ts`, `*.g.cs`) — they are machine-produced and not manually reviewable.

---

## Step 3 — Key Review Dimensions

Assess the changes across the following criteria:

- **Correctness & Edge Cases**: Logical bugs, off-by-one errors, boundary conditions, race conditions, null/undefined references, and unhandled exceptions. Ensure proper error-handling and logging are in place.
- **Conventions & Standards**: Match the design conventions of the target codebase:
  - **Backend (.NET)**: classes are `sealed` by default, EF Core reads use `AsNoTracking()`, endpoints follow FastEndpoints, validators use FluentValidation.
  - **Frontend (React)**: correct hook usage, Zod v4 imports, Radix UI styling patterns, RTK Query cache tagging, TanStack Router file-based routing.
- **Design & Maintainability (DRY)**: Duplicated code or types that should be consolidated, improper separation of concerns, unnecessary prop drilling.
- **Performance & Resource Management**: N+1 query patterns, missing `async/await`, excessive re-renders, missing `useCallback`/`useMemo` on stable references, potential memory leaks, resources not disposed of.
- **Security**: SQL injection, XSS, missing authorization checks, exposed secrets, insecure input validation.
- **Readability**: Variable and function names, comments explaining *why* not *what*, consistent formatting.

---

## Step 4 — Do Not Use Planning Mode

> **Never** produce an implementation plan for a code review. Go straight to gathering context and writing findings. Planning mode is for *code changes*, not reviews.

---

## Step 5 — Output Format

### Summary of Changes

Brief 1-3 sentence overview of what the changes accomplish and their architectural intent.

### Review Findings

Categorize findings by severity:

- **🔴 Critical / Defect** — Blocking bugs, security vulnerabilities, or logic errors that produce incorrect behavior.
- **🟡 Important / Design** — Architectural concerns, DRY violations, convention mismatches, or meaningful performance issues.
- **🟢 Minor / Polish** — Readability, naming, minor style suggestions.
- **💙 Praise** — Exceptionally clean code, clever solutions, or solid architectural choices worth highlighting.

For large reviews (many files), open with a **summary table** before detailed findings:

| # | Severity | File | Issue |
|---|---|---|---|
| 1 | 🔴 | `foo.ts` | Missing null check on `userId` |
| 2 | 🟡 | `bar.tsx` | Duplicated `IssueWriter` type |

Anchor each row's `#` to both the detailed finding and its plain-language counterpart, so a
reader can jump either way.

### Actionable Suggestions

For every 🔴 and 🟡 finding, provide a concrete code block or diff showing the fix, with a brief rationale:

```diff
- public class UserService {
+ public sealed class UserService {
```

### In Plain Terms

After the actionable suggestions, add a plain-language explanation of every 🔴 and 🟡
finding. Technical readers skip it; product owners, testers, and the person who has to
decide whether this blocks a release read only it.

Write each one as four beats, in this order:

1. **What the code is trying to do** — one sentence, in domain nouns (*avtalsmall*,
   *delområde*, *handläggare*), never type names (`ContractTemplate`, `SubareaContract`).
2. **What actually happens** — the failure as a numbered sequence of events with real
   actors, not as a conditional rule. "1. A handler pauses a contract. 2. They close the
   subarea — the guard only looks for *active* contracts, finds none, allows it. 3. …"
   Sequences are concrete; rules are not.
3. **Why it's a defect and not a matter of taste** — name the contradiction: another code
   path already does it correctly, a stated promise in the PR is broken, or the data ends
   up self-inconsistent. Without this beat the reader can dismiss the finding as opinion.
4. **Who notices and how bad** — the user-visible symptom, and why the severity is what it
   is ("nothing crashes, but records silently stay in the wrong state").

Rules:

- **No code, no type names, no method signatures.** If a name is unavoidable, gloss it once
  in domain terms and move on.
- **A three-line ASCII hierarchy or sequence diagram is often worth more than a paragraph.**
  Use one when the finding is about how data or calls nest:
  ```text
  Avtalsmall  →  Delområden  →  Avtal
  ```
- **Don't repeat the fix.** Reference the numbered finding; the diff already lives above.
- **Skip 🟢 and 💙.** Polish and praise don't need translating.
- **Cap each at ~150 words.** If one needs more, the technical finding above it is
  underexplained — fix that instead of padding here.
- **Match the review's language**, except when the product's working language differs from
  the review's (e.g. a Swedish product reviewed in English). This section is aimed at
  non-engineers on the team, so default to the *product's* language for it — and say in one
  line that you've done so.
- If the review produced no 🔴 or 🟡 findings, omit the section entirely rather than
  writing "nothing to explain".

---

## Heuristics & Common Pitfalls

- If the changed files include a **schema or type definition**, search for all consumers to catch downstream type-safety issues.
- If a **context or hook** is changed, verify that all components using it still receive the correct contract.
- If **prop mutation** is spotted (directly modifying a prop object), flag it as 🟡 — use a local `const` copy instead.
- If the same **type is defined in more than one file**, flag it as a DRY violation.
- If a **comment or XML `<summary>` narrates history or an incident** (PR/ticket numbers, "fixed the CI crash", "changed from X to Y", "why this fix works") or **cross-references sibling code as justification** ("mirrors X", "stricter than the Y export"), flag it as 🟢 — comments should state the code's current responsibility or a real constraint, not its backstory.
- If a change alters what code does or needs but **leaves a now-inaccurate comment/doc in place** (e.g. a documented dependency that was removed), flag the stale comment as 🟡 — a wrong doc is worse than none.
- When writing a plain-language explanation, the **"why this isn't a preference" beat is mandatory for every 🟡**. A design finding without it reads as style commentary and gets waved through. The strongest form is pointing at an existing code path in the same repo that already handles the case correctly.
