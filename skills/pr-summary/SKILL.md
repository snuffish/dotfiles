---
name: pr-summary
description: Generate standardized, high-quality pull request summaries from the changes in any repository.
---

# PR Summary Generator Skill

Use this skill whenever the user requests a pull request (PR) summary, PR description, or commit log summary for changes made in the workspace.

> **Never** produce an implementation plan. Go straight to gathering context and writing the summary.

---

## Invocation modes — preview vs update

Parse the arguments **before** doing anything else:

- **Preview mode (default)** — `/pr-summary`, `/pr-summary <branch>`, or `/pr-summary <base>`. Compose the summary and print it as a paste-ready block (Step 4). Nothing is written to any PR.
- **Update mode** — the arguments contain the token `update` (e.g. `/pr-summary update`, or `/pr-summary update <branch>`). Compose the summary exactly as in preview mode, then push it to the **real, open PR** for the branch on the hosting platform (Step 5).

Any argument that is not the `update` keyword is still treated as the branch/base, exactly as before. If in doubt whether a token is a branch, treat it as the branch name.

---

## Step 1 — Determine the diff

Find exactly what changed. Choose the appropriate strategy in order:

| Situation | Command |
|---|---|
| Branch / PR (default) | `git diff $(git merge-base HEAD <base>)...HEAD` |
| Staged only | `git diff --staged` |
| Unstaged only | `git diff` |
| Specific commit range | `git log <base>..HEAD --oneline` |

### Base branch discovery

When comparing a branch, find the correct base — **do not guess**:

```bash
# 1. Check the upstream tracking ref recorded for this branch
git rev-parse --abbrev-ref --symbolic-full-name @{u}   # e.g. origin/main

# 2. Fall back: find the merge-base against common integration branches
git merge-base HEAD origin/main
git merge-base HEAD origin/develop

# 3. Build the diff using three-dot syntax (only commits introduced by this branch):
git diff $(git merge-base HEAD <base>)...HEAD --name-only
```

Always use the **three-dot** form so you see only what this branch introduces, not divergent commits on the base.

---

## Step 2 — Gather context

1. **List changed files first** (`--name-status` or `--name-only`) to grasp the scope.
2. **For small diffs** (< ~200 lines): read the raw diff directly.
3. **For large diffs**: read each changed file in full with `view_file` — do **not** rely on truncated diff output.
4. **Identify the core objective**: new feature, new content, bug fix, performance improvement, refactoring, dependency update, test coverage, or documentation. See the classification vocabulary in Step 3 — in particular, distinguish a genuinely new capability (*new feature*) from merely extending an existing mechanism with more values (*new content*).
5. **Look for a PR template**: if a file like `docs/pull_request_template.md` exists in the repo root, read it and use it as the structural basis for the output.
6. **Capture the work item / ticket reference**: extract it from the branch name (e.g. `feature/28048_my-feature` → `28048`), commit messages, or user input. Include it in the output.
7. **Skip auto-generated files** (e.g., `routeTree.gen.ts`, `*.g.cs`) — do not describe machine-produced changes as if they were hand-authored.

---

## Step 3 — Compose the PR body

Use the structure below. If the repo supplies its own PR template, honour that structure instead — do not invent a different shape.

```markdown
#### PR Classification

<!-- Concise classification. Examples: "New feature and code cleanup", "New content and validation change", "Bug fix and regression test", "Refactoring and performance" -->

#### PR Summary

<!-- 2–3 sentences: what changed, why it changed, and what problem it solves. Be specific — avoid vague phrases like "updated code" or "fixed things". -->

**Key impacts:**

- `<change or behaviour>`: What the change does and why it matters
- `<change or behaviour>`: What the change does and why it matters
<!-- 2–5 bullets. Label each by the change/behaviour it introduces — a concept, NOT a filename. Group edits across files under one conceptual bullet. Do not pad. Match the number to the actual scope of the change. -->

#### Bug description

<!-- Include ONLY for bug fix or hotfix branches. Explain what the bug was, why it happened, and how it was resolved. Remove this section entirely for all other PR types. -->

```

**Composition rules:**

- **PR Classification**: one concise line containing *only* the classification term(s); comma-separate if the change spans multiple types. Do **not** append the work item / ticket reference here (no `(work item #xxxx)`) — that belongs in the footer/`Resolved:` line or the summary, not the classification. Pick from this vocabulary — do not default to "New feature" for anything additive:
  - **New feature** — a genuinely new user-facing capability, workflow, endpoint, or screen that did not exist before.
  - **New content** — additional values inside an *existing* mechanism: new enum members, dropdown options, selectable reasons, seed/reference data, labels, or config entries. The feature already exists; you are only extending its data/options. Example: adding new `RemovedFromSelectionReason` values to a deselection dropdown that already works is **new content**, not a new feature.
  - **Bug fix / Hotfix** — corrects incorrect behaviour (see *Bug description* below).
  - **Refactoring** — restructures code with no behaviour change.
  - **Performance** — makes existing behaviour faster or lighter.
  - **Validation change** — adds/tightens/relaxes input rules (e.g. blocking a now-archived option).
  - **Dependency update**, **Test coverage**, **Documentation**, **Code cleanup** — as named.

  Decision rule: if the change only adds, removes, or renames options/values within an existing feature, classify it as **New content** (optionally combined with **Validation change**), *not* **New feature**. Reserve **New feature** for new capability.
- **PR Summary**: 2–3 sentences maximum; state *what*, *why*, and *impact*. Avoid filler. Do **not** mention a paired/coordinated PR here (e.g. "Paired with the coordinated frontend PR on `branch`") — the platform's relation link in the footer (`This PR relates to: !xxxx`) already conveys that. Only spell out coordination in prose if there is no relation link to carry it.
- **Key impacts**: organise bullets by **change or behaviour, not by file**. Give each a short backtick-wrapped label naming *what the change does* — a concept — then explain the change and why it matters (e.g. `` `Closure under expired template` ``, `` `Support for MatchAchieved state` ``, `` `Demo seed data` ``), **not** a filename label like `` `SomeService.cs` ``. Group related edits that serve one behaviour into a single bullet even when they span several files; conversely, split one file into multiple bullets if it carries distinct behaviours. Name specific symbols/values (enum members, methods, seed identifiers) inside the prose where they make the change concrete. 2–5 bullets is the normal range — do not pad. Every bullet must describe a **concrete change in this PR's diff** — do not add meta/coordination bullets (e.g. a "Cross-repo contract" note that values must stay in sync with another repo); a paired PR is conveyed by the footer relation link (`This PR relates to: !xxxx`), not by a bullet or a summary sentence. **Organise by file when that genuinely makes sense** — when a file maps cleanly to one cohesive change, or file boundaries are the clearest mental model for the reviewer, a file-named label is fine, and the two styles may even be mixed in one list. Behaviour-first is the default; pick whichever grouping makes the PR easiest to understand. Whenever a bullet would otherwise pack several discrete items into one line (an inline em-dash or comma-separated run-on list of any kind), break them out as **nested sub-bullets** — one item per line, indented under the parent. This is a general readability rule that applies to any enumeration; nested bullets are far more scannable than a run-on inline list.
- **Bug description**: include only for `bugfix/` and `hotfix/` branches. **Remove the section entirely** for `feature/`, refactoring, or other PR types.
- **Language**: write in English unless the project clearly uses another language for PR descriptions.
- **Tone**: clear, professional, concise — written for a reviewer who knows the codebase but not the exact intent of this change.
- **Footer trailer lines**: if the platform uses trailer lines (e.g. `Resolved: #xxxx`, `This PR relates to: !xxxx`), keep them at the very bottom after a `---` divider — with `Resolved:` first and the paired-PR relation link (`This PR relates to:`) **last**.

---

## Step 4 — Output

Wrap the final PR body in a fenced markdown block so the user can copy-paste it directly:

````text
```markdown
<the complete PR body from Step 3>
```
````

Do **not** add extra commentary around the block unless the user asks a question. The output should be immediately paste-ready. **In update mode**, still show this block (so the user sees what was pushed), then continue to Step 5 to write it to the live PR.

---

## Step 5 — Update the real PR (update mode only)

Run this step **only** when the invocation is in update mode (see *Invocation modes*). Otherwise stop after Step 4.

Compose the body first (Steps 1–3). Then push it to the live PR — **never fabricate a PR that doesn't exist**.

### 5.1 — Detect the platform and locate the PR

Derive the host from the git remote (`git remote -v`), then find the open PR whose **source branch** is the target branch (default: the current branch, `git branch --show-current`):

- **Azure DevOps** (remote host contains `visualstudio.com` or `dev.azure.com`) — use the `az repos` CLI. Derive `ORG`, `PROJECT`, and `REPO` from the remote URL; a project-scoped workflow skill (e.g. `backend-workflow` / `frontend-workflow`) may already document the constants.

  ```bash
  ORG=https://<org>.visualstudio.com
  BR=$(git branch --show-current)
  az repos pr list --org "$ORG" --project <PROJECT> --repository <REPO> \
    --source-branch "$BR" --status active --query "[0].pullRequestId" -o tsv
  ```

- **GitHub** (remote host contains `github.com`) — use `gh`:

  ```bash
  gh pr view --json number,url -q .number   # PR for the current branch
  ```

Handle these edge cases explicitly — do **not** guess:

- **No open PR** for the branch → do not invent one. Print the composed body (Step 4) and tell the user no PR was found, offering to create one (`az repos pr create` / `gh pr create`).
- **More than one** open PR for the branch → list them and ask which to update.
- **Branch exists in several repos** (cross-repo change) → locate and update the PR in **each** repo, one per repo.

### 5.2 — Show what will be replaced, then update

1. Fetch and show the **current** description first, so the overwrite is visible:
   - ADO: `az repos pr show --id <id> --org "$ORG" --query description -o tsv`
   - GitHub: `gh pr view <id> --json body -q .body`

   If the existing description contains hand-written content you did not author and your summary would discard it, surface that and confirm before overwriting.
2. Write the composed body to a **temp file** — never inline it in the shell command. PR bodies contain backticks and `!`, which the shell tries to expand (command substitution / history expansion) and corrupts the text; a file avoids all escaping. Prefer writing the file with the editor tool rather than `echo`/heredoc.
3. Apply the update from the file:
   - ADO: `az repos pr update --id <id> --org "$ORG" --description "$(cat /tmp/pr-<id>.md)"`
   - GitHub: `gh pr edit <id> --body-file /tmp/pr-<id>.md`
4. **Verify**: re-fetch the description and confirm the first lines match, then report the PR URL. Only claim success after the read-back confirms it.

### 5.3 — Cross-repo relation links

For a cross-repo change, once **both** PR IDs are known, fill each body's footer relation link with the *other* repo's real PR number (`This PR relates to: !<other-id>`) before updating — never leave a `!<placeholder>` in a live description.

### Scope & authorization

- Update the **description/body** only. Leave the PR **title** unchanged unless the user explicitly asks (title updates use `--title` on the same commands).
- Update mode writes to a real, outward-facing artifact. The `update` keyword **is** the user's authorization to write — but still show the current description first (5.2) so the overwrite stays transparent.

---

## Heuristics & Common Pitfalls

- **Do not summarise commit messages verbatim.** Read the actual diff and describe the intent, not the mechanics.
- **Do not fabricate details** not present in the diff (e.g., "this improves performance by 30%").
- **If the diff is ambiguous**, inspect the changed files directly rather than guessing from filenames alone.
- **Match the project's terminology**: if the codebase uses specific domain terms (e.g. "ticket", "suggestion", "matching"), use them in the summary rather than generic synonyms.
- **Describe the diff, not the architecture.** Keep every bullet anchored to something that actually changed in this diff. Resist adding explanatory bullets about invariants, contracts, or cross-repo coupling that aren't themselves a change in this PR.
- **Group by behaviour first, by file when it's clearer.** A reviewer reads Key impacts to learn *what the PR does*, not to see a file list — so one behaviour spread across three files is usually one bullet labelled by the behaviour. But when a file maps cleanly to a single cohesive change, or file boundaries are the clearest way to convey the diff, organising by file is perfectly fine. Optimise for reviewer understanding, not for a rigid rule.
