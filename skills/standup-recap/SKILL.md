---
name: standup-recap
description: 'Writes speaker notes for the daily standup from evidence of your last working day: commits, Azure DevOps PRs, reviews, work item state changes and pipeline runs, plus claude-mem session summaries, grouped per work item into Yesterday / Today / Blockers. Use for /standup-recap, "what did I do yesterday?", "prep my standup". Asks browser or terminal unless a flag says; `--artifact` publishes a page with a count bar and the 3–5 works to say aloud, `--file` also writes a markdown artifact. Not for comparing worktrees or PRs into one consolidation plan (use claude-mem:standup).'
disable-model-invocation: true
argument-hint: "[--artifact | --terminal] [--since YYYY-MM-DD] [--all] [--root <dir>] [--file]"
---

# Skill: `/standup-recap` — Daily Standup Speaker Notes

Recaps your last working day as short speaker notes. A collector script gathers and groups the evidence; the model only phrases it.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-standup_recap-<YYYY-MM-DD>.md` only with `--file`; the date is the window's start day

- Read-only on every repo and tracker: the collector runs `git log`, `az … list/show/query` and `gh search` only; `--artifact` publishes one private page with the Artifact tool and changes nothing else.

- English output, whatever the language of the work item titles.

---

## 1. When _not_ to use

| Situation                                                                   | Use instead                         |
| --------------------------------------------------------------------------- | ----------------------------------- |
| Compare several worktrees, branches or PRs and plan how to consolidate them | `claude-mem:standup`                |
| Resume a piece of work from yesterday                                       | [`/continue`](../continue/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 0: Pick the medium

`--artifact` means browser, `--terminal` means chat. With neither, ask once with one AskUserQuestion before anything runs: **Browser (`--artifact`)** (Recommended; the page in *Step 3*) or **Terminal** (the chat recap only). Both flags → ask which.

### Step 1: Run the collector

```bash
python3 -I <skill-dir>/scripts/collect.py [--since YYYY-MM-DD] [--all] [--root <dir>] > <scratchpad>/standup.json
```

`<skill-dir>` is the `realpath` of this skill's base directory. Pass through the user's arguments except `--artifact`, `--terminal` and `--file`. It prints one JSON object and always exits 0; read it from the file.

What it decides, so you do not re-derive it:

- **Window**: the latest day before today with any of my activity, at most 7 days back; Monday after a quiet weekend lands on Friday (`scripts/collect.py:25`, `scripts/collect.py:398-404`). `--since D` makes the window `D` up to today (`scripts/collect.py:400`). Days are Europe/Stockholm days, whatever the shell's TZ (`scripts/collect.py:21`).
- **Repos**: every repo under `--root` (default `~/Projects`) to depth 4, plus their worktrees (`scripts/collect.py:26`, `scripts/collect.py:579`). Only repos whose remote contains the `az devops configure -l` organization count as work; `--all` adds the rest, GitHub PRs and all sessions (`scripts/collect.py:138`, `scripts/collect.py:593`, `scripts/collect.py:604`).
- **Me**: commits by each repo's `user.email` plus the `az account show` email (`scripts/collect.py:140`, `scripts/collect.py:592`); merge commits are excluded (`scripts/collect.py:151`).
- **Grouping** (`yesterday[]`): one entry per work item (`#NNNNN:` subject or `feature|bugfix/NNNNN_` branch), else per `repo:branch` chore, else per reviewed PR (`review:<id>`) (`scripts/collect.py:203`). Azure's `Merged PR N:` squash commits fold into PR N; one for a PR outside the PR list still marks its `#NNNNN:` work item completed (`scripts/collect.py:427-438`). Each entry has `commits`, `prs[].events` (`opened` / `completed` / `abandoned`), my `states` transitions, `pipelines`, my review `comments` and `votes`; entries are sorted by `weight` (`scripts/collect.py:491`).
- **Summary** (`yesterday[].summary`): one sentence per entry, taken from the PR description (the paragraph under a `Summary` heading, else the first prose paragraph), else a session whose request names the entry's `#id` or `!id`, else the first commit subject; `summary_source` says which (`scripts/collect.py:213`, `scripts/collect.py:478-490`).
- **Reviews**: PRs where I am a reviewer and not the author, across every repo of the default project: `--detect false` stops az narrowing to the repo of the cwd (`scripts/collect.py:233-234`, `scripts/collect.py:244-246`); my comments and vote updates come from at most 10 thread calls per run, so a busy week can miss one (`scripts/collect.py:27`, `scripts/collect.py:626`), votes already translated (`scripts/collect.py:28`).
- **Today** (`today`): open PRs with approvals and change requests, unmerged branches touched in the window that have no PR, my assigned items in progress (`Active` / `In Progress` / `Committed`, `scripts/collect.py:31`, `scripts/collect.py:304-305`), the last branch I committed on, unpushed commits and dirty trees (`scripts/collect.py:537-549`).
- **Blockers** (`blockers[]`): the latest run of a pipeline failed on an open PR, an open PR with no approving or rejecting vote yet, an item in state `Blocked` (`scripts/collect.py:554-563`).
- **Highlights** (`highlights[]`): the 3–5 works worth saying aloud, at most 5 slots (`scripts/collect.py:32-34`). Each entry gets a `reason`: `shipped` (a PR completed), `needs review` (a PR opened, or the item moved to `Pull Request`), `reviewed`, or `in progress` (3+ commits or a state change); removed items, abandoned-only PRs and chores under 3 commits never qualify (`scripts/collect.py:495-511`). Slots go in that order, by `weight` within a reason, and all reviews share one slot `{"key": "reviews", "keys": [...]}` (`scripts/collect.py:514-525`).
- **Counts** (`counts`): commits, PRs completed, PRs reviewed and blockers over the window, for the page's count bar (`scripts/collect.py:528-534`).
- **Sessions** (`sessions[]`): claude-mem session summaries, read-only; transcripts are the fallback (`scripts/collect.py:357-360`, `scripts/collect.py:372`).
- **Notes** (`notes[]`): one line per source that was skipped (missing CLI, failed auth, timeout) (`scripts/collect.py:65`), and `nothing recorded …` for an empty window (`scripts/collect.py:638`).

### Step 2: One summary pass

Turn the JSON into the format below. Rules:

- Two lines per entry. Line 1 leads with `#<id> <title>` for work items, `!<id> <title>` for a review, the branch name for a chore, then the facts joined by ` · `: `N commits`, `!PR opened` / `!PR completed`, `→ <state>`, `🟢` (all pipelines `succeeded`) or `🔴`, `reviewed: <vote>`.
- Line 2, indented: `summary` restated as one short phrase a listener takes in at a glance, in your own words but adding nothing it does not say. No `summary` → line 1 only.
- _Yesterday_ lists the `highlights[]` entries in their order (a `reviews` slot becomes one bullet per reviewed PR); fold every other entry into one line: `+N minor: <short names>`.
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

Browser (`--artifact`): the page replaces the chat recap; chat gets the link and the `⚠` notes only.

1. Write `<scratchpad>/phrases.json`: one phrase per `yesterday[]` key, plus `reviews` when a `reviews` slot exists, following the line 2 rule of *Step 2*; plus `_summary`, one or two plain sentences on the day's theme and outcome built only from the highlights and `counts` (`scripts/render_page.py:8`).
2. Render it. The page has the `_summary` line under the heading, a count bar, "Say these" (the first three highlights as large cards, the rest smaller), every other entry in an "Also" fold, and a Today / Blockers column whose rows past the sixth sit in a "+N more" fold (`scripts/render_page.py:16`):

   ```bash
   python3 -I <skill-dir>/scripts/render_page.py <scratchpad>/standup.json <scratchpad>/phrases.json <scratchpad>/standup-<window.start>.html
   ```

3. Publish that file with the Artifact tool (`icon: "calendar"` on a first publish). The renderer already follows the page contract, so skip the design pass; the same path in a session updates the same URL. Attach the link to the work state as `work_product`.

With `--file`, also write the same content to `<prefix>-standup_recap-<window.start>.md` in the artifact dir (`artifact-protocol`) (`artifact-protocol` › _Claim_) and link it.

---

## 4. Verification & Validation

- The collector's JSON parsed (`meta.elapsed_s` reported if > 30), every bullet and phrase traces to the JSON, and `notes[]` lines are shown.
- `--artifact`: the renderer printed the HTML path, and the publish returned a URL that is in the reply.
