---
name: pr-desc
description: Drafts an Azure DevOps PR description from the current branch's diff against the PR's target branch, following the repo's pull_request_template.md plus Testing and Risks (without a template: Summary, Changes, Testing, Risks), wraps generics like List<T> in backticks, previews it for approval, then applies it with `az repos pr update`; if that call is blocked, prints the exact command to run by hand. Use for /pr-desc, "write the PR description and apply it", "update the ADO PR description".
---

# pr-desc

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/outward-writes.md`: *Voice pass* on the draft

---

Read-only on git: never commit, push, or change the PR title, reviewers or work items.
`<skill-dir>` below is `~/.claude/skills/pr-desc`.

## 1. Find the PR and its target

Run from the repo root (az detects the org and project from the `origin` remote):

```bash
b=$(git branch --show-current)
az repos pr list --source-branch "$b" --status active \
  --query "[].{id:pullRequestId,target:targetRefName,draft:isDraft,title:title}" -o json
```

- One PR: note `id`, `draft` and the target (strip `refs/heads/`).
- None: the target is `git symbolic-ref --short refs/remotes/origin/HEAD` minus `origin/`. Draft and preview anyway, then say there is no PR to apply it to and stop.
- Several: ask which one.
- az fails (not logged in, no extension): use `main` as the target, draft anyway, and treat step 5 as blocked.

Fetch the current description (`az repos pr show --id <id> --query description -o tsv`) and keep any work-item references (`AB#1234`, `#1234`) and links it has.

## 2. Diff against the target

```bash
git fetch origin <target>
git log --oneline origin/<target>..HEAD
git diff --stat origin/<target>...HEAD
git diff origin/<target>...HEAD
```

Three dots: the diff runs from the merge base, so it shows only this branch's changes. For a large diff, read `--stat` first, then the files by area. If `git status --porcelain` shows uncommitted changes, say they are not in the description.

## 3. Draft

Write the draft to `<scratchpad>/pr-<id>-description.md` (scratchpad from the system prompt; `/tmp` if none), in English unless the existing description is in another language. Every claim comes from the diff or commits; no padding.

### 3a. Repo template

Look for the repo's PR template; the first match wins:

```bash
git ls-files | grep -iE '^(\.azuredevops/|\.vsts/|docs/|\.github/)?pull_request_template\.md$'
```

If there is one, the draft follows it:

- Keep its headings verbatim and in order. Replace each `<!-- … -->` guidance comment with content that does what it asks, and drop the comment.
- Fill placeholders in their shape (`` `<impact1>`: Description of impact 1 `` becomes `` `<area>`: <what changed> ``, one per meaningful change). Drop leftover placeholder and filler lines such as "Additional impacts…".
- Keep every checklist item. Tick it only when the diff shows it done; never remove it.
- Remove a section the template marks as removable ("Remove this section if not applicable") when it doesn't apply. Fill work-item placeholders (`#<work item id>`) from the existing description or the branch name; drop the line when none is known.
- Append `Testing` and `Risks` sections, at the template's heading level, after its last section unless it already has them. Their content follows the rules in 3b.

### 3b. No template

Use these sections:

```markdown
## Summary

1–3 sentences: what changes and why. Name the work item if there is one.

## Changes

- Grouped by area (backend / frontend / infra / docs), one bullet per meaningful change. Name files or symbols only when they help a reviewer.

## Testing

- What was actually run (tests, builds, manual checks) and what wasn't. Never claim a check you didn't see pass. If nothing is known, write "Not yet tested" and suggest what to run.

## Risks

- Migrations, contract or API changes, config, behaviour changes, rollback notes. "Low: <reason>" when there is nothing significant.
```

## 4. Voice pass, wrap generics, then preview

Run the draft's prose through `outward-writes` › *Voice pass* first, so the generics script sees the final text.

```bash
python3 <skill-dir>/scripts/wrap_generics.py <draft-file>
wc -c <draft-file>
```

ADO markdown renders a bare `<T>` as an HTML tag and drops it. The script wraps `List<Foo>`, `Dictionary<string, List<int>>`, `<TKey, TValue>` in backticks, leaving code fences and existing code spans alone. ADO caps descriptions at 4000 characters: if `wc -c` is over that, shorten the change bullets (Changes, or the template's equivalent such as Key impacts) and rerun the script.

Print the full draft, then ask with AskUserQuestion: **Apply** / **Revise** (take their notes, redraft, rerun the script, preview again) / **Cancel**. Do nothing more without an explicit Apply.

## 5. Apply

```bash
az repos pr update --id <id> --description "$(cat '<draft-file>')" --draft <draft> \
  --query "{id:pullRequestId,draft:isDraft}" -o json
```

- Read the description from the file with `"$(cat …)"`; never inline the text, because the shell would run the backticks.
- Always pass `--draft` with the PR's current value: `az repos pr update --description` alone publishes a draft PR.
- Check the output: `draft` must equal the value before the call. Then confirm the stored text: `az repos pr show --id <id> --query description -o tsv | diff - <draft-file>` (a trailing-newline difference only is fine).

## 6. If the apply is blocked

If the call is denied, needs interactive login, or fails on auth or network, don't retry. Print the exact command, with the real id, draft value and absolute path filled in, for the user to run as `! <command>` from the repo root:

```bash
az repos pr update --id 18897 --description "$(cat '/abs/path/pr-18897-description.md')" --draft false -o table
```

If the error was auth, put `az login` (or `az devops login`) before it. Keep the draft file; mention its absolute path.
