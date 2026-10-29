---
name: standup-recap
description: 'Writes speaker notes for the daily standup from evidence of your last working day: commits, Azure DevOps PRs, reviews, work item state changes and pipeline runs, plus claude-mem session summaries, grouped per work item into Yesterday / Today / Blockers. Use for /standup-recap, "what did I do yesterday?", "prep my standup". `--file` also writes an artifact. Not for comparing worktrees or PRs into one consolidation plan (use claude-mem:standup).'
disable-model-invocation: true
argument-hint: "[--since YYYY-MM-DD] [--all] [--root <dir>] [--file]"
---

# Skill: `/standup-recap` — Daily Standup Speaker Notes

Recaps your last working day as short speaker notes. A collector script gathers and groups the evidence; the model only phrases it.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-standup_recap-<YYYY-MM-DD>.md` only with `--file`; the date is the window's start day

- Read-only on every repo and tracker: the collector runs `git log`, `az … list/show/query` and `gh search` only.
- English output, whatever the language of the work item titles.

---

## 1. When _not_ to use

| Situation                                                                   | Use instead                         |
| --------------------------------------------------------------------------- | ----------------------------------- |
| Compare several worktrees, branches or PRs and plan how to consolidate them | `claude-mem:standup`                |
| Resume a piece of work from yesterday                                       | [`/continue`](../continue/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Run the collector

```bash
python3 -I <skill-dir>/scripts/collect.py [--since YYYY-MM-DD] [--all] [--root <dir>]
```

`<skill-dir>` is the `realpath` of this skill's base directory. Pass through the user's arguments except `--file`. It prints one JSON object and always exits 0.

What it decides, so you do not re-derive it:

- **Window**: the latest day before today with any of my activity, at most 7 days back; Monday after a quiet weekend lands on Friday (`scripts/collect.py:25`, `scripts/collect.py:394-400`). `--since D` makes the window `D` up to today (`scripts/collect.py:396`). Days are Europe/Stockholm days, whatever the shell's TZ (`scripts/collect.py:21`).
- **Repos**: every repo under `--root` (default `~/Projects`) to depth 4, plus their worktrees (`scripts/collect.py:26`, `scripts/collect.py:527`). Only repos whose remote contains the `az devops configure -l` organization count as work; `--all` adds the rest, GitHub PRs and all sessions (`scripts/collect.py:135`, `scripts/collect.py:541`, `scripts/collect.py:552`).
- **Me**: commits by each repo's `user.email` plus the `az account show` email (`scripts/collect.py:137`, `scripts/collect.py:540`); merge commits are excluded (`scripts/collect.py:148`).
- **Grouping** (`yesterday[]`): one entry per work item (`#NNNNN:` subject or `feature|bugfix/NNNNN_` branch), else per `repo:branch` chore, else per reviewed PR (`review:<id>`) (`scripts/collect.py:200`). Azure's `Merged PR N:` squash commits fold into PR N (`scripts/collect.py:423`). Each entry has `commits`, `prs[].events` (`opened` / `completed` / `abandoned`), my `states` transitions, `pipelines`, my review `comments` and `votes`; entries are sorted by `weight` (`scripts/collect.py:481`).
- **Summary** (`yesterday[].summary`): one sentence per entry, taken from the PR description (the paragraph under a `Summary` heading, else the first prose paragraph), else a session whose request names the entry's `#id` or `!id`, else the first commit subject; `summary_source` says which (`scripts/collect.py:210`, `scripts/collect.py:468-480`).
- **Reviews**: PRs where I am a reviewer and not the author (`scripts/collect.py:242`); my comments and vote updates come from at most 10 thread calls per run (`scripts/collect.py:27`, `scripts/collect.py:574`), votes already translated (`scripts/collect.py:28`).
- **Today** (`today`): open PRs with approvals and change requests, unmerged branches touched in the window that have no PR, my assigned items not in a done state, the last branch I committed on, unpushed commits and dirty trees (`scripts/collect.py:485-497`, `scripts/collect.py:31`).
- **Blockers** (`blockers[]`): the latest run of a pipeline failed on an open PR, an open PR with no approving or rejecting vote yet, an item in state `Blocked` (`scripts/collect.py:502-510`).
- **Sessions** (`sessions[]`): claude-mem session summaries, read-only; transcripts are the fallback (`scripts/collect.py:353-356`, `scripts/collect.py:368`).
- **Notes** (`notes[]`): one line per source that was skipped (missing CLI, failed auth, timeout) (`scripts/collect.py:62`), and `nothing recorded …` for an empty window (`scripts/collect.py:586`).

### Step 2: One summary pass

Turn the JSON into the format below. Rules:

- Two lines per entry. Line 1 leads with `#<id> <title>` for work items, `!<id> <title>` for a review, the branch name for a chore, then the facts joined by ` · `: `N commits`, `!PR opened` / `!PR completed`, `→ <state>`, `🟢` (all pipelines `succeeded`) or `🔴`, `reviewed: <vote>`.
- Line 2, indented: `summary` shortened to at most 12 words, in your own words but adding nothing it does not say. No `summary` → line 1 only.
- At most 5 bullets per section, in the collector's order. Fold the rest into one line: `+N minor: <short names>`.
- Sessions are supporting evidence: use them to phrase _what_ an entry was about. Work that appears only in sessions gets its own bullet tagged `(investigation)`.
- Omit an empty section. Never invent work the JSON does not hold.
- When `window.today_is_live` is true, _Today_ and _Blockers_ show the live state, not the state on that date; say so in one line.
- Print every `notes[]` line under the recap, prefixed `⚠`.

---

## 3. Output Format & Deliverables

Chat, by default:

```markdown
**Standup — <weekday> <window.start>**

**Yesterday**
- #1234 Add invoice export · 8 commits · !567 completed · → Resolved · 🟢
  CSV and PDF export of invoices from the billing page.
- !570 Retry failed webhooks (Alex) · reviewed: waiting for author · 3 comments
  Queues failed webhook deliveries and retries them with backoff.
- +2 minor: flaky e2e menu test, CI agent pin

**Today**
- !568 Glossary — awaiting review
- !566 Address change requests from Sam

**Blockers**
- !566 CI Frontend red
```

With `--file`, also write the same content to `<prefix>-standup_recap-<window.start>.md` at the workspace root (`artifact-protocol` › _Claim_) and link it.

---

## 4. Verification & Validation

- The collector's JSON parsed and `meta.elapsed_s` is reported if it exceeded 30.
- Every bullet traces to an entry, a `today` field, a blocker or a session in the JSON.
- `notes[]` lines are shown, not swallowed.
- No commit, push, comment or tracker write happened.
