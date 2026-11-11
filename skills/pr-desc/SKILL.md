---
name: pr-desc
description: "Writes a PR description and title from the branch's diff against the PR target, following the repo's PR template plus Testing and Risks, with the work item, backticked generics and the 4000-character cap. Bare /pr-desc writes it straight to the PR; `--draft` shows it first and applies on approval; `--dry-run` prints only. Offers to commit pending work first, then updates the description on Azure DevOps or GitHub, retitles a stale title and adds required labels. Use for /pr-desc, \"write the PR description\", \"summarize this branch for the PR\", \"update the PR description\", \"fix the PR title\"."
argument-hint: "[--draft | --dry-run] [branch | base]"
---

# pr-desc

Composes a pull request description and title from the branch's actual diff.

- **Never** produce an implementation plan.
- **Compose from scratch** from the current diff (Steps 2–4). Treat the existing PR description as stale: carry over only its work-item references (`AB#1234`, `#1234`) and links, never its prose.
- **The title is the one exception**: compose a title from the diff, compare it with the live title, and keep the live title when it still fits the diff and the convention.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact; prints in chat, or updates the open PR
- `../_modules/git-worktrees.md`
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`
- `../_modules/project-profile.md`: base profile only (`<project>-profile`); reads *Tracker*, *PR tooling*, *PR labels*, and *Report language*
- `../_modules/outward-writes.md`

- Confirm `repo-root` (`git-worktrees` › *Using this Module from a Command*) before Step 1's `status`, `add`, `commit`, or `push`.

`<skill-dir>` below is this skill's real folder.

---

## Project profile

Before Step 1, load `<project>-profile` when the workspace matches its gate (`project-profile` › *Discovery*) and resolve:

- **Tracker** and **PR tooling**: org URL, project/repo constants, and CLI/MCP route.
- **PR labels**: required PR labels, selection rule, and read/add commands (*Apply*, item 4).
- **Report language**: language of the PR body. Without a profile, use the existing description's language, else English.

---

## Modes

| Invocation | Does |
| --- | --- |
| `/pr-desc [branch \| base]` | Step 1 commit offer, draft, print, then *Apply* with no approval prompt. |
| `/pr-desc --draft [branch \| base]` | Step 1 commit offer, draft, preview, then **Apply** / **Revise** / **Cancel**. Writes only on Apply. |
| `/pr-desc --dry-run [branch \| base]` | Draft and print the paste-ready block (Step 5), then stop. Never commits, pushes or writes to the PR. Other Commands call this mode. |

---

## Step 1 — Offer to commit pending work (not in `--dry-run`)

Run per `repo-root` in scope:

```bash
git -C <repo-root> status --short
git -C <repo-root> rev-list --count @{u}..HEAD 2>/dev/null
```

- **`--dry-run`**: never commit or push; note in chat that uncommitted or unpushed changes are included in the draft but not on the PR.
- **Bare and `--draft`**: if uncommitted or unpushed work exists, list the files, a proposed commit subject and the unpushed commits per repo, and **ask once** with AskUserQuestion whether to commit and push before the description is written. On yes, follow [`/commit`](../commit/SKILL.md) Steps 2–5 (selective staging, repo commit convention + trailer rule, pre-commit gates, `git -C <repo-root> push` / `push -u origin HEAD`). On no, say the pending work is left out of the description. Never amend, rebase, or force-push.
- **Overlap with the gates:** once the commit's files are staged, start its pre-commit gates with `run_in_background` and run Steps 2–3 meanwhile on `git -C <repo-root> diff --staged "$BASE"` plus the committed `"$BASE...HEAD"` range. After the push, compare `git -C <repo-root> diff --stat "$BASE...HEAD"` with what was read; re-read only the files that differ (a formatter changed them).

---

## Step 2 — Find the PR and the diff

Resolve the open PR (if any) and diff base `<base>` per `pr-host` › *Resolve the PR from a branch* and *Branch names & Diff base* (PR target `origin/$TGT` when a PR exists, else `origin/HEAD`; never `@{u}`; always three-dot `git -C <repo-root> diff "$BASE...HEAD"`, so only this branch's changes show). Confirm the diff is non-empty.

- One PR: note its id, title, current description and (on Azure DevOps) `isDraft`.
- None: draft and preview anyway, say there is no PR to apply it to, and offer to create one. Never create it unasked.
- Several: list them and ask.
- The host CLI fails (not logged in, no extension): diff against `origin/HEAD`, draft anyway, and treat *Apply* as blocked.

---

## Step 3 — Gather context

1. List changed files (`--name-status`, plus `--stat` for the totals) and skip machine-generated files (`*.gen.ts`, `*.g.cs`, `*.Designer.cs`, committed API snapshots such as `swagger.json`).
2. **Read the diff inline, whatever its size; never start sub-agents in this Command.** Read it per area (`git -C <repo-root> diff "$BASE...HEAD" -- <paths>`), the files the `--stat` and commit bodies point at first. Digest agents re-read the whole diff to save context a PR description does not need saved (!19023, 2026-11-11: three agents for ~1,600 lines).
3. **As parallel tool calls with the diff reads**, fetch the context: the repo PR template (`git ls-files | grep -iE '^(\.azuredevops/|\.vsts/|docs/|\.github/)?pull_request_template\.md$'`, first match wins), the work-item ID from the branch name, commit subjects or linked work items, the recent PR titles (Step 4.3), and outside `--dry-run` the counterpart PR (`pr-counterpart` › *Counterpart discovery*, reused in *Apply*).

---

## Step 4 — Compose the body and title

Write the body to `<scratchpad>/pr-<id>/body.md` (scratchpad from the system prompt; `/tmp` if none) in the profile's *Report language*. Every claim comes from the diff or commits; no padding.

1. **Repo template**: when Step 3 found one, follow it:
   - Keep its headings verbatim and in order. Replace each `<!-- … -->` guidance comment with content that does what it asks, and drop the comment.
   - Fill placeholders in their shape (`` `<impact1>`: Description of impact 1 `` becomes `` `<area>`: <what changed> ``, one per meaningful change). Drop leftover placeholder and filler lines such as "Additional impacts…".
   - Keep every checklist item. Tick it only when the diff shows it done; never remove it.
   - Remove a section the template marks as removable ("Remove this section if not applicable") when it doesn't apply. Fill work-item placeholders (`#<work item id>`) from the existing description or the branch name; drop the line when none is known.
   - Append `Testing` and `Risks`, at the template's heading level, after its last section unless it already has them (rules in [pr-body-template.md](references/pr-body-template.md)).
2. **No template**: follow the structure, classification vocabulary and composition rules in [pr-body-template.md](references/pr-body-template.md).
3. **Title**:
   - Match the repo's convention from recent completed PRs (`az repos pr list --org <org-url> --project <project> --repository <repo> --target-branch <target> --status completed --top 10 --query "[].title" -o tsv` or `gh pr list --base <target> --state merged --limit 10 --json title`), e.g. `#<work-item-id>: <short English imperative>` (~80 chars max, no trailing period or `WIP`).
   - Compare with the live PR title (if an open PR exists): **keep** it when it still names the main change and follows the convention; **replace** it only when a major change was added or removed, or it breaks the convention.

---

## Step 5 — Voice pass, wrap generics, then preview

Run the body's prose through `outward-writes` › *Voice pass* first (template headings, checkboxes, paths and IDs stay verbatim), so the generics script sees the final text.

```bash
python3 <skill-dir>/scripts/wrap_generics.py <scratchpad>/pr-<id>/body.md
wc -m <scratchpad>/pr-<id>/body.md
```

Azure DevOps markdown renders a bare `<T>` as an HTML tag and drops it. The script wraps `List<Foo>`, `Dictionary<string, List<int>>`, `<TKey, TValue>` in backticks, leaving code fences and existing code spans alone. Azure DevOps caps descriptions at 4000 characters: if `wc -m` is over that, condense per [pr-body-template.md](references/pr-body-template.md) and rerun the script.

Print:

1. `Title: <title> (unchanged)` or `Title: <new title> (will replace: <current title>)` (or `Title: <title>` when no PR exists).
2. The complete body inside a fenced ```` ```markdown ```` block.
3. `Labels: <labels>` when the profile defines *PR labels*.

- **Bare**: go on to *Apply*.
- **`--draft`**: ask with AskUserQuestion: **Apply** / **Revise** (take the notes, redraft, rerun the script, preview again) / **Cancel**. Do nothing more without an explicit Apply.
- **`--dry-run`**: stop here.

---

## Apply

1. **Locate the PR(s)**: reuse the PR from Step 2 and the counterpart from Step 3.3 (`pr-counterpart` › *Counterpart discovery* across repos). When a cross-repo counterpart exists, fill each PR's footer relation link (`This PR relates to: !<other-id>`) with the real counterpart ID before updating.
2. **Read-back before overwrite**: fetch and display the current `title`, `description`/`body`, and (on Azure DevOps) `isDraft` (`az repos pr show --id <id> --org <org-url>` / `gh pr view <id> --json title,body`).
3. **Write from scratchpad files**: the body from `<scratchpad>/pr-<id>/body.md`, and the title from `<scratchpad>/pr-<id>/title.txt` when replacing it. Never inline markdown in shell arguments; the shell would run the backticks.
   - **Azure DevOps**: prefer the MCP `repo_pull_request_write` with `action: update`, `repositoryId`, `pullRequestId`, `description` (the file's text), and `title` when replacing; leave `isDraft` out so the PR keeps its draft state. If the MCP is unavailable or denied, run `az repos pr update --id <id> --org <org-url> --description "$(cat <scratchpad>/pr-<id>/body.md)" --query "{id:pullRequestId,draft:isDraft}" -o json` (plus `--title "$(cat <scratchpad>/pr-<id>/title.txt)"` when replacing). If `draft` in the output differs from the read-back value, say so in the report.
   - **GitHub**: `gh pr edit <id> --body-file <scratchpad>/pr-<id>/body.md` (plus `--title "$(cat <scratchpad>/pr-<id>/title.txt)"` when replacing).
4. **Labels** (when the profile defines *PR labels*): read current labels, add any missing labels picked by the profile's rule (one call per label; **never remove existing labels**), and read back.
5. **Verify (`outward-writes` › *Read back*)**: re-fetch the live description, title and labels, diff the description against the body file (`az repos pr show --id <id> --query description -o tsv | diff - <scratchpad>/pr-<id>/body.md`; a trailing-newline difference only is fine), and report the PR URL.

### If the apply is blocked

If the call is denied, needs interactive login, or fails on auth or network, don't retry. Print the exact command, with the real id and absolute path filled in, for the user to run as `! <command>` from the repo root:

```bash
az repos pr update --id 18897 --description "$(cat '/abs/path/pr-18897/body.md')" -o table
```

If the error was auth, put `az login` (or `az devops login`) before it. Keep the body file; mention its absolute path.

---

## Heuristics & Common Pitfalls

- **Describe the diff, not commit messages or general architecture**: anchor every bullet in *Key impacts* (or the template's equivalent) to a concrete change in this diff.
- **Never claim a check you didn't see pass**, and never fabricate metrics.
- **Use the codebase's domain terminology**.
