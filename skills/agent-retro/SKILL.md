---
name: agent-retro
description: 'Retro on an agent review of a pull request: finds the issues the review missed, verifies each against sources fetched now, posts them after approval, then finds why the review missed them and fixes that cause, routed to a PR thread, an open PR on the same concern, or a draft PR of its own with a work item. Writes `<prefix>-agent_retro-<suffix>.md`. Use for /agent-retro, "what did the review miss on !19153?", "why did the review miss this?". Not for a first review (use /code-review), triaging threads (use /pr-feedback-review) or fixing findings on the PR branch (use /fix-findings).'
disable-model-invocation: true
argument-hint: "<PR id | URL> [--retro] [--no-fix] [--dry-run]"
---

# Skill: `/agent-retro` — What the Review Missed, and Why

Looks back at a PR an agent (or a person) already reviewed, keeps only the issues nobody raised, verifies and posts them, and then fixes the review rules or tooling that let them through, so the next review catches them.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until the write gates in Steps 5, 7 and 8; no `/proceed` gate line at the end
- `../_modules/artifact-protocol.md`: writes `<prefix>-agent_retro-<suffix>.md`, suffix `<PR id>-<slug of the PR title>`
- `../_modules/git-worktrees.md`: snapshot for Steps 2–6, workspace for each fix PR in Step 8
- `../_modules/project-profile.md`: the base profile and the rulebooks that name the review and posting rules
- `../_modules/pr-host.md`
- `../_modules/fan-out.md`: Step 3 lanes and the Step 6 retro variants
- `../_modules/outward-writes.md`

On-demand references (`references/`):
- [`references/hunt.md`](references/hunt.md): Steps 3–4, where reviews miss issues and how to check them
- [`references/routing.md`](references/routing.md): Steps 6–8, the cause of a miss, a home for each fix, and opening the PRs

- **Repo skill first.** When the repo's rulebook ships its own agent-retro skill, use that one; it knows the repo's review tooling.
- **Words.** A *candidate* is an issue you drafted. A *finding* is a candidate nobody raised before and Step 4 verified. Candidates dropped as already raised are counted apart.
- **Pin the PR head.** The head is the PR's last merge source commit. When `origin/<source-branch>` differs, the branch moved after the PR was read: use the pinned SHA and say so.
- **Draft first, compare last.** Draft candidates before reading earlier reviews and threads in full, then drop those already raised.
- **Facts are fetched, never recalled.** A claim about a tool, library or service is checked against its source at the version the repo pins (*Step 4*).
- **Fates.** Every finding ends as posted, routed to a PR, or left out with a reason the user saw. A refuted candidate leaves without a section, count or card.
- **`--dry-run`.** Run every read the steps reach. What a step would show or ask goes into the artifact and the final report: the overview, the findings, each thread text (with the *read and approved* marker form, if the project has one), the routing table, and for each new PR its branch and title. Record `Voice pass: skipped: dry run` in the artifact header. A skill gap goes in the report, not in a gap file. The snapshot is still removed.
- **Agents.** At most 4 lanes in Step 3 and 3 retro variants in Step 6, on Sonnet, read-only (`fan-out` › *Speed fan-out*). Inline, area by area, when the caller or the user's rules forbid spawning.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| The PR has no review yet | [`/code-review`](../code-review/SKILL.md), or the review skill the project's rulebook names |
| Triage what reviewers already wrote and draft replies | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| Fix review findings on the PR's own branch | [`/fix-findings`](../fix-findings/SKILL.md) |
| Explain the PR, not find defects | [`/pr-overview`](../pr-overview/SKILL.md) |
| Work through skill gaps already logged | [`/skill-gap`](../skill-gap/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Is there a review to look back on?

1. Resolve the PR and pin the head (`pr-host` › *Parse a PR or work-item URL*, *Fetch the PR, its work items and acceptance criteria*).
2. Fetch the threads (`pr-host` › *Fetch discussion threads*). A thread counts as review when a person or a person-approved AI review wrote it; system, pipeline-bot and vote threads do not. List earlier review artifacts in `<artifact-dir>` whose file name holds `-<PR id>-` (names only; do not read their findings yet).
3. Search earlier work for the PR id (claude-mem `search`, `work_state_read`). Record the result, or `not searched: <reason>`.
4. **No review** (no review thread and no artifact): write the artifact with the pin and the reason, end with the closing block, and point to the review skill (*When not to use*).

### Step 2: Snapshot and rules

1. Create a snapshot at the pinned SHA (`git-worktrees` › *Snapshot Lifecycle*).
2. Load the base profile and the rulebooks (`project-profile` › *Resolution order*). Read the review and posting rules from `origin/<default>` (`project-profile` › *Upstream content*); a PR that edits them is judged by the version on `origin/<default>`.
3. In chat, at most 10 lines: what the PR improves, then the issues that must be solved before merge with `path:line`, each marked *raised* when a review thread holds it. Keep going without waiting.

### Step 3: Hunt for missed issues

1. Draft candidates against the diff at the pinned head, using the rows of [`references/hunt.md`](references/hunt.md) whose area the diff touches; record which rows you checked. When the diff exceeds 1,000 changed lines (`git diff --stat -M`, added plus deleted, leaving out tool-written files such as lockfiles, snapshots and claims files, and renames), split it into up to 4 lanes by area.
2. Stop drafting when each changed file was read once and each matching row was checked.
3. Now read every review thread (all comments in it) and earlier review. Drop each candidate already raised (same defect, any wording) and name the thread it matched.

### Step 4: Verify

For each remaining candidate, in the snapshot:
- Re-open the code at `path:line` and the code that could refute it (callers, config, tests).
- For tool or library behaviour, read its source at the version the repo pins (lockfile, image tag); docs sites usually show only the latest version. On GitHub: `gh api 'repos/<owner>/<repo>/contents/<path>?ref=<tag>' -H 'Accept: application/vnd.github.raw'`. Quote the line that decides it.
- Grade it: `✅ Verified` (every link in the evidence read) or `🟡 Inferred` (the code is read, one runtime value cannot be fetched yet, such as an identity's display name; name that value). Both are findings; a `🟡` one is posted as a question. Refuted → drop. Not checkable at the pinned version → left out with `unverified at <version>`.

Show the user the findings with evidence. **No findings:** say so, skip Steps 5–8, write the artifact and end with the closing block.

### Step 5: Post (write gate)

1. Draft one thread per finding on the line it anchors to (a finding in two files: the first file's line, the second named in the body), in the PR's language, following the posting rules the rulebooks name (markers included), or [`/pr-post-comments`](../pr-post-comments/SKILL.md) when they name none. Run the *Voice pass*.
2. Ask before posting (AskUserQuestion). The question carries the full text of every thread and **names each finding left out, with why** (out of scope, belongs in another PR, unverified at the pinned version). Text before the question can be hidden; put it in the question.
3. Post only what was approved. Leave the vote unchanged unless the user asks. Read back the thread IDs (`outward-writes` › *Read back*).

### Step 6: Why was it missed?

Runs under `--no-fix` too. For each finding, find the cause per [`references/routing.md`](references/routing.md) › *Find the cause*.

With `--retro`, also run up to 3 retrospective variants in parallel sub-agents (a spotlight on the misses, a bare session sweep, a spotlight on facts that had to be dug out), each writing to the scratchpad. Keep each cause that one of them proves with a transcript turn or `path:line`.

### Step 7: Route the fixes (write gate)

Skip under `--no-fix`; the causes stay in the artifact. Build the routing table per [`references/routing.md`](references/routing.md) › *Choose a home*: one row per fix with its home and the reason. Show it and wait for the go: approval to post in Step 5 does not cover commits or PRs.

### Step 8: Open the PRs (write gate)

Per [`references/routing.md`](references/routing.md) › *Open a fix PR*: one locked workspace worktree per new PR, the project's checks, commit through [`/commit`](../commit/SKILL.md), a draft PR from the repo template, the work item the project's PR rules require, and a read back of each.

---

## 3. Output Format & Deliverables

The artifact holds: the pinned SHA, the earlier-work search result, the overview, the hunt rows checked, the candidates dropped as already raised with their thread, the findings (each with grade, evidence and fate: thread ID, routed PR, or left out with reason), the causes and the routing table with PR and work-item IDs. Under `--dry-run` it also holds the payloads.

Chat (and a dry run's final report) ends with:

```markdown
**!<id> agent retro** at `<sha>`: <n> findings, <n> posted · <n> candidates already raised

| Fix | Home | Result |
|---|---|---|
| <one line> | thread on !<id> / !<open PR> / new PR | <thread id · commit sha · !<new id> (task <id>) · not opened: dry run> |

- Left out: <finding> (<reason>) (or: none)
- Worktrees: <kept at path: reason> (or: removed)
- Others to tell: <session or person that must pull a commit> (or: none)
```

---

## 4. Verification & Validation

- Every finding names the pinned SHA and its evidence; none rests on recall.
- Posted plus left out equals the finding count (a dry run posts none).
- Each new PR is a draft (unless the user asked otherwise), links its work item, and its description reads back as written.
- Each fix branch passed the checks its PR description names, run in this session.
