---
name: pr-summary
description: "Writes a pull request description from the branch's actual diff, following the repo's PR template and conventions, with the work-item reference. Preview by default: prints a paste-ready block and changes nothing. `update` offers to commit and push the branch's pending work first, then replaces the live PR's description on Azure DevOps or GitHub, retitles the PR when its title no longer fits the diff, and adds the labels the project profile requires. Use for /pr-summary, \"write the PR description\", \"summarize this branch for the PR\", \"update the PR description\", \"fix the PR title\"."
argument-hint: "[update] [branch | base]"
---

# PR Summary Generator Skill

Composes a pull request description and title from the branch's actual diff.
- **Never** produce an implementation plan.
- **Always compose from scratch** from the current diff (Steps 1–3). Treat any existing PR description as stale — never seed, echo, or partially reuse it.
- **The title is the one exception**: compose a title from the diff (*PR title*), compare it against the live title, and keep the live title when it still fits the diff and convention.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — prints in chat (preview) or updates the open PR (`update` mode)
- `../_modules/git-worktrees.md`
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`
- `../_modules/project-profile.md`: base profile only (`<project>-profile`); reads *Tracker*, *PR tooling*, *PR labels*, and *Report language*
- `../_modules/outward-writes.md`
- `../_modules/fan-out.md`: _Speed fan-out_ for the diff digests (Step 2)

- Confirm `repo-root` (`git-worktrees` › *Using this Module from a Command*) before Step 0's `status`, `add`, `commit`, or `push`.

---

## Project profile

Before Step 0, load `<project>-profile` when the workspace matches its gate (`project-profile` › *Discovery*) and resolve:
- **Tracker** and **PR tooling** — org URL, project/repo constants, and CLI/MCP route.
- **PR labels** — required PR labels, selection rule, and read/add commands (Step 5.4).
- **Report language** — language of the PR body (default: language of recent PR descriptions in the repo).

---

## Invocation modes — preview vs update

- **Preview mode (default)** — `/pr-summary [branch | base]`: compose and print the paste-ready summary block (Step 4). Writes nothing to any remote or PR.
- **Update mode** — `/pr-summary update [branch | base]`: offer to commit and push pending work (Step 0), compose the summary, print it, and replace the live PR description, stale title, and missing labels on the host (Step 5).

---

## Step 0 — Sync the branch before composing

Run per `repo-root` in scope:
```bash
git -C <repo-root> status --short
git -C <repo-root> rev-list --count @{u}..HEAD 2>/dev/null
```
- **Preview mode**: never commit or push; note in chat if uncommitted or unpushed changes are included.
- **Update mode**: if uncommitted or unpushed work exists, list the files, proposed commit subject, and unpushed commits per repo and **ask once**. On approval, follow [`/commit`](../commit/SKILL.md) Steps 2–5 (selective staging, repo commit convention + trailer rule, pre-commit gates, `git -C <repo-root> push` / `push -u origin HEAD`). Never amend, rebase, or force-push.
- **Overlap with the gates (update mode):** once the commit's files are staged, start its pre-commit gates with `run_in_background` and run Steps 1–2 meanwhile on `git -C <repo-root> diff --staged "$BASE"` plus the committed `"$BASE...HEAD"` range. After the push, compare `git -C <repo-root> diff --stat "$BASE...HEAD"` with what was digested; re-digest only the files that differ (a formatter changed them).

---

## Step 1 — Determine the diff

Resolve the open PR (if any) and diff base `<base>` per `pr-host` › *Resolve the PR from a branch* and *Branch names & Diff base* (PR target `origin/$TGT` when a PR exists, else `origin/HEAD`; never `@{u}`; always three-dot `git -C <repo-root> diff "$BASE...HEAD"`). Confirm the diff is non-empty.

---

## Step 2 — Gather context

1. List changed files (`--name-status`, plus `--stat` for the totals) and skip machine-generated files (`*.gen.ts`, `*.g.cs`).
2. **Small changes (< ~200 diff lines):** read the raw diff inline.
3. **Larger changes:** split the changed files by area (for example backend, frontend, tests and config; at most 3 areas, merging the smallest) and spawn one digest sub-agent per area per `fan-out` › _Speed fan-out_ and [diff-digest.md](references/diff-digest.md). Compose from their digests and the `--stat`, re-opening at least one cited hunk per digest before relying on it.
4. **In the same message as the digests** (or as parallel tool calls when inline), fetch the context: the repo PR template (`docs/pull_request_template.md`, `.github/pull_request_template.md`), the work-item / ticket ID from the branch name, commit subjects or linked work items, the recent PR titles (Step 3.2), and in `update` mode the counterpart PR (`pr-counterpart` › *Counterpart discovery*, reused in Step 5.1).

---

## Step 3 — Compose the PR body & title

1. **PR body**: follow the repo's PR template if one exists, otherwise follow the template, classification vocabulary (`New feature` vs. `New content`, `Bug fix`, etc.), and **4000-character budget** in [pr-body-template.md](references/pr-body-template.md). Write in the profile's *Report language*.
2. **PR title**:
   - Match the repo's convention from recent completed PRs (`az repos pr list --org <org-url> --project <project> --repository <repo> --target-branch <target> --status completed --top 10 --query "[].title" -o tsv` or `gh pr list --base <target> --state merged --limit 10 --json title`), e.g. `#<work-item-id>: <short English imperative>` (~80 chars max, no trailing period or `WIP`).
   - Compare with the live PR title (if an open PR exists): **keep** the live title when it still names the main change and follows the convention; **replace** it only when a major change was added/removed or it breaks the convention.

---

## Step 4 — Output

Run the body's prose through `outward-writes` › *Voice pass* (template headings, checkboxes, paths and IDs stay verbatim), then verify the body is **≤ 4000 characters** (`wc -m` on `<scratchpad>/pr-<id>/body.md`; condense per [pr-body-template.md](references/pr-body-template.md) if over). Print:
1. `Title: <title> (unchanged)` or `Title: <new title> (will replace: <current title>)` (or `Title: <title>` when no PR exists).
2. The complete PR body inside a fenced ```` ```markdown ```` block.
3. `Labels: <labels>` when the profile defines *PR labels*.

In preview mode, stop here.

---

## Step 5 — Update the real PR (`update` mode only)

1. **Locate the PR(s)**: reuse the PR resolved in Step 1 (`pr-host` › *Resolve the PR from a branch*) and the counterpart found in Step 2.4 (`pr-counterpart` › *Counterpart discovery* across repos).
   - No open PR → do not create one unasked; print the Step 4 output and offer to create the PR.
   - Multiple open PRs for the same branch → list and ask.
   - Cross-repo counterpart found → fill each PR's footer relation link (`This PR relates to: !<other-id>`) with the real counterpart ID before updating.
2. **Read-back before overwrite**: fetch and display the current `title`, `description`/`body`, and (on ADO) `isDraft` (`az repos pr show --id <id> --org <org-url>` / `gh pr view <id> --json title,body`).
3. **Write via scratchpad files**: write the body to `<scratchpad>/pr-<id>/body.md` (and `<scratchpad>/pr-<id>/title.txt` when replacing the title) — never inline markdown in shell arguments:
   - **Azure DevOps**: `az repos pr update --id <id> --org <org-url> --description "$(cat <scratchpad>/pr-<id>/body.md)" --draft <isDraft>` (plus `--title "$(cat <scratchpad>/pr-<id>/title.txt)"` when replacing). Passing `--draft <isDraft>` is mandatory so a draft PR is not accidentally published.
   - **GitHub**: `gh pr edit <id> --body-file <scratchpad>/pr-<id>/body.md` (plus `--title "$(cat <scratchpad>/pr-<id>/title.txt)"` when replacing).
4. **Labels** (when the profile defines *PR labels*): read current labels, add any missing labels picked by the profile's rule (one call per label; **never remove existing labels**), and read back.
5. **Verify (`outward-writes` › *Read back*)**: re-fetch the live PR description, title, and labels to confirm they match, and report the PR URL.

---

## Heuristics & Common Pitfalls

- **Describe the diff, not commit messages or general architecture**: anchor every bullet in *Key impacts* to a concrete change in this diff.
- **Never fabricate metrics or unverified claims**.
- **Use the codebase's domain terminology**.
