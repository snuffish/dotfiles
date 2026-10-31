---
name: pr-summary
description: "Writes a pull request description from the branch's actual diff, following the repo's PR template and conventions, with the work-item reference. Preview by default: prints a paste-ready block and changes nothing. `update` offers to commit and push the branch's pending work first, then replaces the live PR's description on Azure DevOps or GitHub, retitles the PR when its title no longer fits the diff, and adds the labels the project profile requires. Use for /pr-summary, \"write the PR description\", \"summarize this branch for the PR\", \"update the PR description\", \"fix the PR title\"."
argument-hint: "[update] [branch | base]"
---

# PR Summary Generator Skill

Use this skill whenever the user requests a pull request (PR) summary, PR description, or commit log summary for changes made in the workspace.

> **Never** produce an implementation plan. Go straight to gathering context and writing the summary.

> **Always compose from scratch.** Derive the summary **only** from the current diff (Steps 1–3). Treat any existing PR description as **stale by default** — never read it to seed, anchor, echo, or partially reuse the new summary, and never let its structure, wording, or omissions shape yours. Compose as if the PR had no description yet. In update mode this is a **full replacement**, not an edit of the old text.

> **The title is the one exception.** Compose a title from the diff too (Step 3 › *PR title*), then read the current title only to decide whether it still fits. Keep it when it does; replace it when it does not. Never retitle for wording alone.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — the summary is printed in chat (preview) or written to the open PR (`update` mode). Never an implementation plan.
- `../_modules/git-worktrees.md`
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`
- `../_modules/project-profile.md`: base profile only (no Command profile); reads *PR labels* and *Report language*

- Confirm the repo root before Step 0's `status`, `add`, `commit` or `push` — Step 0 against the user's main checkout would commit and push *their* unrelated work.

---

## Project profile

Before Step 0, load the project's base profile `<project>-profile` with the Skill tool when the workspace matches its `[Project: …]` gate (`project-profile` › *Discovery*; e.g. `priis-profile` in the GR workspace). There is no `pr-summary-<project>-profile`. Resolve per `project-profile` › *Resolution order*:

- **PR labels** — the labels the PR must carry and how to add them (Step 5.4). No profile, or a profile without the field: set no labels and say nothing about them.
- **Report language** — the language of the body (Step 3 › *Language*).

A profile adds facts; it never widens what update mode may write (*Scope & authorization*).

---

## Invocation modes — preview vs update

Parse the arguments **before** doing anything else:

- **Preview mode (default)** — `/pr-summary`, `/pr-summary <branch>`, or `/pr-summary <base>`. Compose the summary and print it as a paste-ready block (Step 4). Nothing is written to any PR.
- **Update mode** — the arguments contain the token `update` (e.g. `/pr-summary update`, or `/pr-summary update <branch>`). First offer to commit and push any pending work (Step 0). Then compose the summary exactly as in preview mode and push it to the **real, open PR** for the branch on the hosting platform (Step 5).

Any argument that is not the `update` keyword is still treated as the branch/base, exactly as before. If in doubt whether a token is a branch, treat it as the branch name.

---

## Step 0 — Sync the branch before composing

A PR description has to describe the code the PR actually contains. If the work exists only in the working tree, or only in local commits, the summary would describe code reviewers cannot see. So **sync first, then compose**, and **ask the user before any commit or push** (the user's rule: no commits unless told). Run this per `[worktree-context]` block when blocks were handed in, else per repo in the workspace that has a branch to summarise — always against `<repo-root>`, never the current directory.

```bash
git -C <repo-root> status --short                                   # uncommitted work?
git -C <repo-root> rev-list --count @{u}..HEAD 2>/dev/null          # local commits not pushed? (errors when no upstream)
```

Before items 1 and 2, list what would be committed (files and proposed subject) and pushed, per repo, and ask once. Commit and push only on a yes. On a no, commit and push nothing, say which changes the summary covers that reviewers cannot see yet, and ask whether to stop or still update the PR.

1. **Uncommitted changes** — commit them before Step 1.
   - Stage **selectively**: only the files that belong to this branch's change, never `git add -A` / `git add .`. Leave stray files out and name them in chat: generated output, local config, editor settings, scratch artifacts.
   - Use the repo's commit convention, from its workflow skill or `CONTRIBUTING.md`, falling back to the recent `git log`. Example: `#<id>: <short English imperative description>`, with the work-item id taken from the branch name.
   - Apply the attribution-trailer rule the project or profile sets; a project that forbids trailers overrides the harness default.
   - Run the repo's fast pre-commit gates first when they are documented: a formatter, an import organiser on changed files, lint. A failing gate stops here and is reported; never commit around it.
2. **Unpushed commits** — push them: `git -C <repo-root> push`, or `git -C <repo-root> push -u origin HEAD` when the branch has no upstream.
3. **Nothing to sync** — continue silently.

In **preview mode**, do not commit or push. Say instead that the summary covers changes that are not yet committed or pushed, and list them.

Never amend, rebase or force-push existing commits here; add new commits only. Report what was committed and pushed (short SHA and subject per repo) before the summary block.

---

## Step 1 — Determine the diff

Find exactly what changed. Choose the appropriate strategy in order:

| Situation | Command (all `-C <repo-root>`) |
|---|---|
| Branch / PR (default) | `git -C <repo-root> diff $(git -C <repo-root> merge-base HEAD <base>)...HEAD` |
| Staged only | `git -C <repo-root> diff --staged` |
| Unstaged only | `git -C <repo-root> diff` |
| Specific commit range | `git -C <repo-root> log <base>..HEAD --oneline` |

### Base branch discovery

When comparing a branch, find the correct base — **do not guess**:

```bash
# 1. A PR exists: its target branch is the base. Azure DevOps returns a full ref, so strip refs/heads/
#    (az repos pr list --source-branch <branch> --query '[0].targetRefName' -o tsv; gh pr view --json baseRefName -q .baseRefName)
BASE=origin/${targetRefName#refs/heads/}

# 2. No PR: the remote's default branch
BASE=$(git -C <repo-root> symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) \
  || { git -C <repo-root> remote set-head origin -a >/dev/null && BASE=$(git -C <repo-root> symbolic-ref --short refs/remotes/origin/HEAD); } \
  || BASE=origin/main

# 3. Build the diff using three-dot syntax (only commits introduced by this branch):
git -C <repo-root> diff "$BASE...HEAD" --name-only
```

Do **not** use `@{u}` as the base (Step 0's unpushed-commits check is the one place it belongs). On a pushed feature branch the upstream is the branch's own remote copy (`origin/feature/x`), not the integration branch, so the diff comes out empty or nearly empty. In `update` mode that empty summary would replace the live PR description.

Always use the **three-dot** form so you see only what this branch introduces, not divergent commits on the base. Confirm the diff is non-empty before composing anything.

---

## Step 2 — Gather context

1. **List changed files first** (`--name-status` or `--name-only`) to grasp the scope.
2. **For small diffs** (< ~200 lines): read the raw diff directly.
3. **For large diffs**: read each changed file in full (`view_file` under Antigravity, `Read` under Claude Code); do **not** rely on truncated diff output.
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
<!-- 2–5 bullets. Label each by the change/behaviour it introduces; a file name only when that file is itself one cohesive change. Group edits across files under one conceptual bullet. Do not pad. Match the number to the actual scope of the change. -->

#### Bug description

<!-- Include whenever the PR actually fixes a bug — i.e. the classification includes "Bug fix"/"Hotfix" — regardless of branch prefix. Explain what the bug was, why it happened, and how it was resolved. Omit the section entirely when nothing incorrect is being corrected. -->

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
- **Key impacts**: 2–5 bullets, each a concrete change in this diff, labelled with a short backticked name for the behaviour it introduces (e.g. `` `Closure under expired template` ``). Group edits that serve one behaviour across files; use a file name as the label only when that file is itself one cohesive change. Name the specific symbols or values in the prose, and put any list of several items in nested sub-bullets. A paired PR is conveyed by the footer relation link, not a bullet.
- **Bug description**: include this section whenever the PR **actually fixes a bug** — i.e. whenever the classification includes **Bug fix** or **Hotfix** — *regardless of the branch prefix*. A `bugfix/`/`hotfix/` branch always qualifies, but so does a `feature/` (or any other) branch that corrects incorrect behaviour as part of its change (e.g. a feature PR that also repairs a pre-existing defect, or a cross-repo alignment fix). Explain what the bug was, why it happened, and how it was resolved, scoped to the bug-fixing part of the diff. **Omit the section entirely** when the PR corrects nothing — pure new feature, new content, refactoring, performance, validation, docs, or cleanup work.
- **Language**: write in English unless the project clearly uses another language for PR descriptions.
- **Tone**: clear, professional, concise — written for a reviewer who knows the codebase but not the exact intent of this change.
- **Footer trailer lines**: if the platform uses trailer lines (e.g. `Resolved: #xxxx`, `This PR relates to: !xxxx`), keep them at the very bottom after a `---` divider — with `Resolved:` first and the paired-PR relation link (`This PR relates to:`) **last**.
- **Length budget — max 4000 characters**: the complete body (headings, bullets, footer included) must fit within **4000 characters** — Azure DevOps hard-caps PR descriptions at that size, and staying under it keeps the summary scannable on any platform. Compose within the budget from the start; when over, **condense rather than truncate**:
  1. tighten prose and drop redundant qualifiers,
  2. collapse nested sub-bullets back into their parent bullet,
  3. merge overlapping Key-impacts bullets,
  4. only as a last resort shorten the Bug description — never cut mid-sentence and never drop the footer trailer lines.

### PR title

Azure DevOps makes the title the default merge commit subject (`Merged PR <id>: <title>`), so a stale title lands in the target branch's history. Compose one from the same diff as the body.

First locate the PR with 5.1 in **both** modes (the lookup is read-only, and it sets `ORG`, `PROJECT`, `REPO` and the PR id used below; Step 5 reuses the result). In preview mode, when 5.1 finds no PR or several, skip the keep-or-replace check and print `Title: <title>` alone (Step 4), without asking or offering to create one.

- **Convention**: match the repo's title format. Take it from recent completed PRs into the same target (`az repos pr list --org "$ORG" --project <PROJECT> --repository <REPO> --target-branch <target> --status completed --top 10 --query "[].title" -o tsv`; GitHub: `gh pr list --base <target> --state merged --limit 10 --json title -q '.[].title'`), else from the commit convention (Step 0). Example: `#<work-item-id>: <short English imperative>`.
- **Content**: name the PR's main change, i.e. the change the *PR Summary* leads with. Cover a second change only when it is as significant as the first, and keep the title about one line (~80 characters). No trailing period, and no `WIP`, branch names or file names.
- **Keep or replace** (update mode, and the preview's `Title:` line): read the current title (ADO `--query title`; GitHub `--json title -q .title`). Keep it when it still names the main change and follows the convention. Replace it when:
  - it describes only part of the diff and leaves out a change as significant as the one it names (e.g. a dependency upgrade added after the PR was opened), or
  - it names something the diff no longer does, or
  - it breaks the convention (missing work-item prefix, placeholder, `WIP`, branch name).

---

## Step 4 — Output

Wrap the final PR body in a fenced markdown block so the user can copy-paste it directly:

````text
```markdown
<the complete PR body from Step 3>
```
````

Do **not** add extra commentary around the block unless the user asks a question. The output should be immediately paste-ready. Put one line before the block with the title: `Title: <title> (unchanged)` when the current title is kept, or `Title: <new title> (will replace: <current title>)` when it is to be replaced. Update mode reports the outcome after the write (5.2 step 4). Without a PR, write `Title: <title>` alone. When the profile defines *PR labels*, add one line after the block naming the labels the rule picks for this diff, e.g. `Labels: Backend, Frontend` (preview mode only lists them; Step 5.4 sets them). **In update mode**, still show this block (so the user sees what was pushed), then continue to Step 5 to write it to the live PR.

**Before printing, verify the length budget**: measure the composed body (e.g. write it to a temp file and `wc -m`) and confirm it is **≤ 4000 characters**. If it exceeds the budget, condense per the Step 3 length rules and re-measure — do not print an over-budget body.

---

## Step 5 — Update the real PR (update mode only)

Run this step **only** when the invocation is in update mode (see *Invocation modes*). Otherwise stop after Step 4.

Compose the body first (Steps 1–3). Then push it to the live PR — **never fabricate a PR that doesn't exist**.

### 5.1 — Detect the platform and locate the PR

Step 3 › *PR title* runs this lookup in both modes; in update mode, reuse its result here instead of looking the PR up again.

Derive the host from the git remote (`git remote -v`), then find the open PR whose **source branch** is the target branch (default: the current branch, `git branch --show-current`):

- **Azure DevOps** (remote host contains `visualstudio.com` or `dev.azure.com`) — use the `az repos` CLI. Derive `ORG`, `PROJECT`, and `REPO` from the remote URL; a project-scoped workflow skill (e.g. `priis-backend-workflow` / `priis-frontend-workflow`) may already document the constants.

  ```bash
  ORG=<org-url>   # the form the workspace already uses: pr-host › Organization URL
  BR=$(git branch --show-current)
  az repos pr list --org "$ORG" --project <PROJECT> --repository <REPO> --source-branch "$BR" --status active --query "[0].pullRequestId" -o tsv
  ```

- **GitHub** (remote host contains `github.com`) — use `gh`:

  ```bash
  gh pr view --json number,url -q .number   # PR for the current branch
  ```

Handle these edge cases explicitly — do **not** guess:

- **No open PR** for the branch → do not invent one. Print the composed body (Step 4) and tell the user no PR was found, offering to create one (`az repos pr create` / `gh pr create`).
- **More than one** open PR for the branch → list them and ask which to update.
- **Branch exists in several repos** (cross-repo change) → locate and update the PR in **each** repo, one per repo.
- **Counterpart under a different branch name** → run the lookup in `pr-counterpart` › *Counterpart discovery* even when the branch exists in one repo only, because the halves of a change usually carry different work-item ids and branch names. Every PR it finds gets the relation link (5.3). An *expected but missing* half is reported back, never papered over with a placeholder.

### 5.2 — Show what will be replaced, then update

1. Fetch and show the **current** title and description first (and, on ADO, note `isDraft` for step 3), purely as a transparency read-back so the overwrite is visible:
   - ADO: `az repos pr show --id <id> --org "$ORG" --query "{title:title,description:description,isDraft:isDraft}" -o json`
   - GitHub: `gh pr view <id> --json title,body`

   Treat it as **stale** and replace it in full — it is shown for the record, never used as input for the new summary (see the *Always compose from scratch* principle above). Do not pause to reconcile with, preserve, or merge in the old text; the `update` keyword is the authorization to overwrite.
2. Write the composed body to a **temp file** — never inline it in the shell command. PR bodies contain backticks and `!`, which the shell tries to expand (command substitution / history expansion) and corrupts the text; a file avoids all escaping. Prefer writing the file with the editor tool rather than `echo`/heredoc.
3. Apply the update from the file:
   - ADO: `az repos pr update --id <id> --org "$ORG" --description "$(cat /tmp/pr-<id>.md)" --draft <isDraft from the read-back>` — without `--draft` the update publishes a draft PR. ADO caps the description at **4000 characters**. The Step 3 length budget should already guarantee this; if the update is still rejected for length, condense per the Step 3 rules and retry rather than truncating mid-sentence or splitting across fields.
   - GitHub: `gh pr edit <id> --body-file /tmp/pr-<id>.md`

   When Step 3 › *PR title* decided to replace the title, set it in the same call: write it to its own temp file (`/tmp/pr-<id>-title.txt`) and add `--title "$(cat /tmp/pr-<id>-title.txt)"` to either command. A kept title is not sent.
4. **Verify**: re-fetch the description (and the title, when it was sent) and confirm they match, then report the PR URL and whether the title was kept or replaced. Only claim success after the read-back confirms it.

### 5.3 — Cross-repo relation links

For a cross-repo change, once **both** PR IDs are known, fill each body's footer relation link with the *other* repo's real PR number (`This PR relates to: !<other-id>`) before updating — never leave a `!<placeholder>` in a live description.

### 5.4 — Labels (when the profile defines *PR labels*)

Apply the profile's rule to the same three-dot diff as Step 1 (and the work-item type when the rule uses it), then:

1. Read the PR's current labels with the profile's read command.
2. Add each label the rule picks that the PR lacks, one call per label, with the profile's add command.
3. **Never remove a label**, including one the rule would not pick: reviewers and boards set their own.
4. Read the labels back and report them, marking which were added.

A rule that picks no label (for example a change outside every area folder) adds nothing; say so in the report. A failed label write is reported with its error; it does not undo the description update.

### Scope & authorization

- Update the **description/body**, the **title** when Step 3 › *PR title* says it no longer fits, and add the profile's **missing labels** (5.4). Never remove a label, change the draft state, vote or touch reviewers.
- Update mode writes to a real, outward-facing artifact. The `update` keyword **is** the user's authorization to write the description and the title, not to commit or push (Step 0 asks) — but still show the current ones first (5.2) so the overwrite stays transparent.

---

## Heuristics & Common Pitfalls

- **Do not summarise commit messages verbatim.** Read the actual diff and describe the intent, not the mechanics.
- **Do not fabricate details** not present in the diff (e.g., "this improves performance by 30%").
- **If the diff is ambiguous**, inspect the changed files directly rather than guessing from filenames alone.
- **Match the project's terminology**: if the codebase uses specific domain terms (e.g. "ticket", "suggestion", "matching"), use them in the summary rather than generic synonyms.
- **Describe the diff, not the architecture.** Keep every bullet anchored to something that actually changed in this diff. Resist adding explanatory bullets about invariants, contracts, or cross-repo coupling that aren't themselves a change in this PR.
