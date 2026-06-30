---
name: source-command-backend-ship
description: "[Project: GR.PRIIS.Backend] Branch, commit, push, and open a draft PR for current work — following PRIIS workflow conventions. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# source-command-ship

Use this skill when the user asks to run the migrated source command `ship`.

## Command Template

# /ship — Branch · Commit · Push · PR

Ship your current work in one go: create or confirm a branch, run pre-commit validation, commit, push, and open a draft PR — all following the [PRIIS workflow skill](../skills/workflow/SKILL.md) conventions.

**Usage:**

```
/ship [work-item-id]
/ship 28048
/ship
```

- `work-item-id` — the implementing **Task or Bug** ID (not the parent User Story). Inferred from the current branch name if omitted. Asked interactively if it cannot be determined.

---

## ADO constants

| Key | Value |
|-----|-------|
| Project | `PRIIS` |
| Repository | `GR.PRIIS.Backend` |

---

## Step 1 — Read git status

Determine the repo root: run `git rev-parse --show-toplevel` from the current working directory.

Then run:

- `git -C <repo-root> status --short` — list staged and unstaged files
- `git -C <repo-root> branch --show-current` — current branch name
- `git -C <repo-root> log --oneline -5` — recent commits for context

Report a one-line summary: branch name, staged file count, unstaged file count.

---

## Step 2 — Resolve work item ID

Determine the implementing Task or Bug ID using this priority:

1. Command argument (if provided)
2. Current branch name — extract the numeric ID from `<prefix>/<id>_<slug>` (e.g. `feature/28048_my-feature` → `28048`)
3. Ask the user: "Which ADO Task or Bug ID is this work for?"

Fetch the work item via `mcp__azure-devops__wit_get_work_item` (project: `PRIIS`) and confirm its type, title, and state.

**If the work item is a User Story:** stop and tell the user that the branch must target an implementing **Task or Bug**, not a User Story directly. Ask for the child task or bug ID. (See [workflow skill §7 — Work Item Intake](../skills/workflow/SKILL.md).)

---

## Step 3 — Create or confirm branch

Derive the branch name from the work item:

| Work item type | Prefix |
|---|---|
| Task | `feature/` |
| Bug → targets `main` | `bugfix/` |
| Bug → targets a release branch | `hotfix/` — ask the user if unsure |

Full format: `<prefix>/<id>_<english-kebab-slug>` (see [workflow skill §1](../skills/workflow/SKILL.md))

Examples:

```
feature/28048_rename-category-for-adult-hvb
bugfix/28110_fix-null-category-seed-mapping
```

- If already on a correctly named branch → confirm and continue.
- If on any other branch (including `main`): show the proposed branch name, ask the user to confirm or adjust, then run:

  ```bash
  git -C <repo-root> checkout -b <branch-name>
  ```

---

## Step 4 — Pre-commit validation

Run the validation checklist from [workflow skill §8](../skills/workflow/SKILL.md) in sequence from the repo root:

```bash
dotnet format
dotnet build --configuration Release
dotnet test --configuration Release
```

Stop and report any failure — **do not proceed to commit until all three pass.**

(You can also run `/verify` which covers these checks plus anti-pattern scanning.)

---

## Step 5 — Stage and commit

Show the full diff (`git -C <repo-root> diff` and `git -C <repo-root> diff --staged`) and ask the user which files to include.

**Never use `git add -A` or `git add .`** — stage only the confirmed files explicitly:

```bash
git -C <repo-root> add <file1> <file2> ...
```

Commit using the format from [workflow skill §3](../skills/workflow/SKILL.md):

```
#<work_item_id>: <short English description>
```

- Imperative present tense ("Add filtering" not "Added filtering")
- English only
- Derived from the work item title

Example: `#28048: Rename category for adult HVB`

---

## Step 6 — Push

```bash
git -C <repo-root> push -u origin <branch-name>
```

Report success or any errors before continuing.

---

## Step 7 — Create draft PR

**Check for an existing PR first:** call `mcp__azure-devops__repo_list_pull_requests_by_repo_or_project` with `repositoryId = "GR.PRIIS.Backend"`, `project = "PRIIS"`, `sourceRefName = "refs/heads/<branch-name>"`. If an open PR already exists, report its URL and skip creation.

Otherwise:

1. Determine the target branch ([workflow skill §9](../skills/workflow/SKILL.md)):
   - `feature/` and `bugfix/` → `refs/heads/main`
   - `hotfix/` → the `release/X.Y.Z` branch it was cut from
2. **Generate the PR body using the `pr-summary` skill:**
   - Load and follow the `pr-summary` skill (`/Users/snuffish/.terminal/skills/pr-summary/SKILL.md`) in full.
   - Use `git diff $(git merge-base HEAD origin/main)...HEAD` to compute the diff for the branch.
   - Compose the PR body following all rules from the `pr-summary` skill (classification, summary, key impacts, resolved line).
   - Include the `Bug description` section only for `bugfix/` and `hotfix/` branches; omit it entirely for `feature/` branches.
   - End with `Resolved: #<id>`.
3. Compose the PR:
   - **Title:** `#<id>: <description>` (same as commit message)
   - **Body:** the output from the `pr-summary` skill above
   - **isDraft:** `true`
   - **Labels:** add `Bugfix` label when the work item type is Bug
4. Call `mcp__azure-devops__repo_create_pull_request` with `repositoryId = "GR.PRIIS.Backend"`, `project = "PRIIS"`.
5. Call `mcp__azure-devops__wit_link_work_item_to_pull_request` to link the work item to the new PR.
6. Call `mcp__azure-devops__wit_update_work_item` to set the work item state to `Pull Request`.

Report the PR URL on success.
