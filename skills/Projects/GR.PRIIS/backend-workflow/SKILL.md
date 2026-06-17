---
name: backend-workflow
description: "[Project: GR.PRIIS.Backend] GR.PRIIS.Backend development workflow — branch naming, commit format, PR title and body, ADO state transitions, work item intake, and validation checklist. Load when creating branches, commits, or pull requests. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# Development Workflow — GR.PRIIS.Backend

This skill is the single source of truth for day-to-day git and ADO conventions in this repo. It is self-contained so all team members follow the same rules regardless of local tooling.

---

## 1. Branch Naming

Format: `<prefix>/<work_item_id>_<english-kebab-slug>`

The work item ID is always the **implementing task or bug ID**, not the parent user story.

| Prefix | When to use |
|--------|-------------|
| `feature/` | Tasks and user stories targeting `main` |
| `bugfix/` | Bugs targeting `main` |
| `hotfix/` | Bugs targeting a `release/X.Y.Z` branch (production hotfix) |

```
feature/28048_rename-category-for-adult-hvb
bugfix/28110_fix-null-category-seed-mapping
hotfix/29034_fix-registration-number-validation
```

**Rules:**
- Use English only in the slug
- The slug is lowercase kebab-case (`my-feature-name`, not `MyFeatureName`)
- One implementation branch per repo
- Hotfix branches branch off the relevant `release/X.Y.Z` branch and PR back into it

---

## 2. Release Branches

Release branches follow the pattern `release/X.Y.Z`:

```
release/2.2.X   ← current stable sprint
release/2.3.X   ← next sprint (created at sprint start)
```

- **Minor version** (`2.2` → `2.3`) increments each sprint
- **Patch version** (`2.2.0` → `2.2.1`) increments for each hotfix

Hotfix workflow:
1. Branch off `release/X.Y.Z` → `hotfix/{id}_{slug}`
2. Implement the fix
3. PR targets `release/X.Y.Z` (not `main`)
4. After merging to release, merge release → main via a separate integration PR

---

## 3. Commit Messages

Format: `#<work_item_id>: <short English description>`

```
#28048: Rename category for adult HVB
#28110: Fix null category in seed mapping
#29034: Address PR review comments
```

**Rules:**
- Always reference the implementing task or bug ID (not the parent story)
- English only
- Imperative present tense ("Fix bug" not "Fixed bug")
- For PR review fixes: `#<id>: Address PR review comments`
- Stage only the intended files — never `git add -A` or `git add .`

---

## 4. Pull Request Title

Same format as commits: `#<work_item_id>: <short English description>`

```
#28048: Rename category for adult HVB
#28110: Fix null category in seed mapping
```

---

## 5. Pull Request Body

Always read `docs/pull_request_template.md` before composing the PR body. The template structure:

```markdown
#### PR Classification
<New feature | Bug fix | Refactoring | Performance | Cleanup | Testing>

#### PR Summary
<One paragraph describing what changed and why>

**Key impacts:**
- `<area or file>`: <what changed and why it matters>
- `<area or file>`: <what changed and why it matters>

#### Bug description
<Describe the bug that was present — ONLY include this section for bugfix/hotfix branches; remove entirely for other PR types>

Resolved: #<implementing task or bug ID>
```

**Rules:**
- End with `Resolved: #<id>` pointing to the implementing **task or bug**, not the parent user story
- Bug and hotfix PRs: keep the "Bug description" section
- All other PR types: remove the "Bug description" section entirely
- Add the `Bugfix` label when the work item type is Bug
- Keep descriptions in English
- The `Resolved: #<id>` line links the PR to the ADO work item automatically

---

## 6. ADO Work Item State Transitions

| When | What to do |
|------|-----------|
| Starting work | Set the **User Story** to `Active` |
| Reusing a child task | Set the **Task** to `Active` |
| Creating a new child task | Create → set to `Active` → link to parent story |
| PR created | Move the **implementing Task or Bug** to `Pull Request` |
| PR merged | Work item typically moves to `Resolved` or `Done` automatically |

Link the PR to the implementing **task or bug** — not only to the parent user story.

---

## 7. Work Item Intake

| Work item type | Action |
|----------------|--------|
| **User Story** | Look for an existing `Backend`-tagged child task to reuse. If none exists, create a new Task with the `Backend` tag, set it `Active`, and link it to the story. Use the child task ID for the branch. |
| **Task** | Work directly on that task. Use its ID for the branch. |
| **Bug** | Work directly on that bug. Use its ID for the branch. |

Child task tags:
- `Backend` — backend-scoped task
- `Frontend` — frontend-scoped task

---

## 8. Validation Checklist (Before Committing)

Run these before `git add`:

```bash
dotnet format                                  # fix formatting (CI enforces this)
dotnet build --configuration Release           # zero errors/warnings
dotnet test --configuration Release            # all tests pass
```

Or run `/verify` to automate all checks including anti-pattern scanning.

The project uses `TreatWarningsAsErrors` — a build warning is a build failure.

---

## 9. PR Targets

| Branch type | Default PR target |
|-------------|-------------------|
| `feature/` | `main` |
| `bugfix/` | `main` |
| `hotfix/` | The `release/X.Y.Z` branch it was cut from |

Create one PR per repo. For cross-repo changes (Backend + Frontend), each PR links to its own repo-scoped implementing task.

---

## 10. ADO Tooling — MCP Server vs CLI

**Always prefer the `mcp__azure-devops__*` MCP tools over `az repos` / `az boards` CLI commands.** The CLI silently truncates multi-line descriptions and has other quoting issues on Windows; the MCP tools do not.

Fall back to `az` only for operations not covered by the MCP server (e.g. pipeline triggers).

### Common operations

| Operation | MCP tool |
|---|---|
| Create PR | `mcp__azure-devops__repo_create_pull_request` |
| Update PR description / title / status | `mcp__azure-devops__repo_update_pull_request` |
| Get PR by ID | `mcp__azure-devops__repo_get_pull_request_by_id` |
| Link PR to work item | `mcp__azure-devops__wit_link_work_item_to_pull_request` |
| Move work item state | `mcp__azure-devops__wit_update_work_item` |
| Create work item | `mcp__azure-devops__wit_create_work_item` |
| Add work item comment | `mcp__azure-devops__wit_add_work_item_comment` |
| Get work item | `mcp__azure-devops__wit_get_work_item` |

### Parameters always required

- `repositoryId`: use the repo name (`"GR.PRIIS.Backend"`) — not the GUID
- `project`: `"PRIIS"` — required whenever `repositoryId` is a name

### PR creation example

```
mcp__azure-devops__repo_create_pull_request(
  repositoryId = "GR.PRIIS.Backend",
  project      = "PRIIS",
  sourceBranch = "refs/heads/feature/28048_my-branch",
  targetBranch = "refs/heads/main",
  title        = "#28048: My PR title",
  description  = "... full markdown body ..."
)
```

---

## Quick Reference

```
Branch:   feature/28048_rename-category-for-adult-hvb
Commit:   #28048: Rename category for adult HVB
PR title: #28048: Rename category for adult HVB
PR body:  ...Resolved: #28048
ADO:      Move Task #28048 to "Pull Request" after PR is created
```
