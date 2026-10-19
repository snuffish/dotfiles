---
name: priis-backend-ship
description: "[Project: GR.PRIIS] Branch, commit, push, and open a draft PR for current work — following PRIIS workflow conventions for both Frontend and Backend repositories."
---

# /priis-backend-ship — Branch · Commit · Push · PR

Ship your current work in one go: create or confirm a branch, run pre-commit validation, commit, push, and open a draft PR — all following the PRIIS workflow conventions for the respective repository.

**Usage:**

```
/priis-backend-ship [work-item-id]
/priis-backend-ship 28048
/priis-backend-ship
```

- `work-item-id` — the implementing **Task or Bug** ID (not the parent User Story). Inferred from the current branch name if omitted. Asked interactively if it cannot be determined.

---

## Modules

Read these before step 1:
- `~/.terminal/skills/_modules/core.md`
- `~/.terminal/skills/_modules/artifact-protocol.md`: writes no artifact — the deliverables are the commit, the push and the draft PR
- `~/.terminal/skills/_modules/git-worktrees.md`

- Mutating by design: stage only files the user confirmed, never force-push.
- **Repo root** without a `[worktree-context]` block: `git rev-parse --show-toplevel` from the current working directory. Every command below is `git -C <repo-root>`.

---

## Step 1 — Detect environment and repository

Determine the repo root per *Repo root* above: the handed-in `repo-root`, else `git rev-parse --show-toplevel` from the current working directory.
Check which repository you are working in (using the directory name or git remote URL — in a worktree the directory is `<repo>/.claude/worktrees/<slug>`, so prefer the remote URL):

- **Backend** if directory/remote is `GR.PRIIS.Backend`
- **Frontend** if directory/remote is `GR.PRIIS.Frontend`

Then run:

- `git -C <repo-root> status --short` — list staged and unstaged files
- `git -C <repo-root> branch --show-current` — current branch name
- `git -C <repo-root> log --oneline -5` — recent commits for context

Report a one-line summary: repo name, branch name, staged file count, unstaged file count.

---

## Step 2 — Resolve work item ID

Determine the implementing Task or Bug ID using this priority:

1. Command argument (if provided)
2. Current branch name — extract the numeric ID from `<prefix>/<id>_<slug>` (e.g. `feature/28048_my-feature` → `28048`)
3. Ask the user: "Which ADO Task or Bug ID is this work for?"

Fetch the work item via CLI:

```bash
az boards work-item show --id <ID> --org https://dev.azure.com/grutbildning --output json
```

Confirm its type, title, and state from the output.

**If the work item is a User Story:** stop and tell the user that the branch must target an implementing **Task or Bug**, not a User Story directly. Ask for the child task or bug ID.

---

## Step 3 — Create or confirm branch

Derive the branch name from the work item:

| Work item type | Prefix |
|---|---|
| Task | `feature/` |
| Bug → targets `main` | `bugfix/` |
| Bug → targets a release branch | `hotfix/` — ask the user if unsure |

Full format: `<prefix>/<id>_<english-kebab-slug>` (e.g., `feature/30048_add-oppenvard-barn-q4`)
*Slug rules: English only, kebab-case (hyphens, no underscores after the ID).*

- If already on a correctly named branch → confirm and continue. A workspace worktree is always already on its branch (`git-worktrees` › *Workspace Lifecycle* step a created it), so this is the normal case under `/implement-feature`; never `checkout -b` there.
- If on any other branch **and no `[worktree-context]` was handed in**: show the proposed branch name, ask the user to confirm or adjust, then check out:

  ```bash
  git -C <repo-root> checkout -b <branch-name>
  ```

  If `<branch-name>` already exists, say where it is checked out (`git -C <repo-root> worktree list`) and ask instead of forcing.

---

## Step 4 — Pre-commit validation

Run the validation checklist in sequence based on the active repository:

### For Backend (`GR.PRIIS.Backend`)

Run from backend repo root:

```bash
pwsh -NoProfile -File ./scripts/format-changed.ps1   # dotnet format on changed files only (-All for whole solution)
dotnet build --configuration Release
dotnet test --configuration Release
```

### For Frontend (`GR.PRIIS.Frontend`)

Run from `source/priis-web/`:

```bash
npm run lint
npm run build
# npm run e2e (optional for logic-only changes, required for UI/interaction changes)
```

Stop and report any failure — **do not proceed to commit until validation passes.**

---

## Step 5 — Stage and commit

Show the full diff (`git -C <repo-root> diff` and `git -C <repo-root> diff --staged`) and ask the user which files to include.
**Never use `git add -A` or `git add .`** — stage only the confirmed files explicitly:

```bash
git -C <repo-root> add <file1> <file2> ...
```

Commit using the same format in both repositories (`priis-backend-workflow` / `priis-frontend-workflow` §3):

```
#<work_item_id>: <short English description, imperative>
```

*Example: `#28048: Add quota change request to operation`*

- English only, imperative present tense — never the Swedish work-item title.
- Reference the implementing Task or Bug, not the parent User Story.
- For review fixes: `#<id>: Address PR review comments`.

## Step 6 — Push

```bash
git -C <repo-root> push -u origin <branch-name>
```

Report success or any errors before continuing.

---

## Step 7 — Create draft PR

**Check for an existing PR first:**

```bash
az repos pr list --org https://dev.azure.com/grutbildning --project PRIIS --repository <repo-name> --source-branch <branch-name> --status active --output json
```

If an open PR already exists, report its URL and skip creation.

Otherwise:

1. Determine the target branch:
   - `feature/` and `bugfix/` → `main`
   - `hotfix/` → the `release/X.Y.Z` branch it was cut from
2. **Generate the PR body using the `pr-summary` skill:**
   - Load and follow the `pr-summary` skill (`../../../pr-summary/SKILL.md`) in full, handing it the same `[worktree-context]` block (if any) so its Step 0 and diff run against `<repo-root>`.
   - Use `git -C <repo-root> diff $(git -C <repo-root> merge-base HEAD origin/main)...HEAD` to compute the diff for the branch.
   - Compose the PR body following all rules from the `pr-summary` skill (classification, summary, key impacts, resolved line).
   - English in both repositories.
   - End with `Resolved: #<id>`.
3. Create the PR via CLI:
   - **Title:** `#<id>: <description>` — English imperative in both repositories (`*-workflow` §4)
   - **Body:** the output from the `pr-summary` skill above
   - **isDraft:** `true`

```bash
az repos pr create --org https://dev.azure.com/grutbildning --project PRIIS --repository <repo-name> --source-branch <branch-name> --target-branch <target-branch> --title "#<id>: <description>" --description "<PR body>" --draft true --work-items <id>
```

1. Move work item state to `Pull Request`:

```bash
az boards work-item update --id <id> --state "Pull Request" --org https://dev.azure.com/grutbildning
```

Report the PR URL on success.
