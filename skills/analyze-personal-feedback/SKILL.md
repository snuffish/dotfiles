---
name: analyze-personal-feedback
description: 'Monthly review of the feedback I received: collects every comment and blocking vote others left on my Azure DevOps PRs and every reply to my reviews, plus mail (.eml), call transcripts (.vtt), Telegram exports and notes from an export folder. Says who said what and where, groups it by theme, names the top 3 ways to improve and compares them with last month''s report. Use for /analyze-personal-feedback, "what feedback did I get this month?", "how can I improve?". Not for triaging one PR''s threads (use /pr-feedback-review).'
disable-model-invocation: true
argument-hint: "[--days N] [--exports <folder>] [--me <name>]"
---

# Skill: `/analyze-personal-feedback`: Monthly Feedback Review

A collector script gathers what people said to me; the model groups it into themes and picks the top 3 improvements. Run it once a month.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-personal_feedback-<YYYY-MM>.md`. The artifact dir is fixed at `${AGENT_ARTIFACTS_DIR:-$HOME/.cache/agent-artifacts}/personal-feedback/`, whatever the cwd, so each month lands next to the last.

- Read-only on every source: the collector runs `az repos pr list`, `az devops invoke` (GET) and `az account show` only. It posts, resolves and votes on nothing.
- The report is in English. Quote people in their own language.

---

## 1. When _not_ to use

| Situation                                           | Use instead                                             |
| --------------------------------------------------- | ------------------------------------------------------- |
| Triage and reply to the threads on one PR            | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| Recap of yesterday's work for standup                | [`/standup-recap`](../standup-recap/SKILL.md)           |

---

## 2. Core Protocol & Workflow

### Step 1: Ask for exports (once per run)

Mail, Teams chats, call transcripts and Telegram are only read from an export folder. Chrome automation is not used, because Chrome has no Microsoft 365 session and the agent must not sign in. If the user gave no `--exports`, ask once whether they have a folder. Otherwise go on with Azure DevOps only and say so in the report header.

What the folder may hold (`scripts/collect.py:194`):

| File | Read as | From |
| --- | --- | --- |
| `*.eml` | one item per mail; quoted replies are cut off (`scripts/collect.py:142`) | Outlook: drag mails to a folder, or *Save as* |
| `*.vtt` | one item per utterance by someone other than me; date = file mtime (`scripts/collect.py:157`) | Teams meeting → Recap → Transcript → Download .vtt |
| `*.json` | Telegram Desktop *Export chat history* → JSON (`scripts/collect.py:170`) | Telegram Desktop |
| `*.txt`, `*.md` | one item per file, e.g. pasted Teams chats (`scripts/collect.py:186`) | copy/paste |

Export messages are kept only when they contain a feedback cue word in English or Swedish (`scripts/collect.py:29`, `scripts/collect.py:138`); `--no-filter` keeps them all.

### Step 2: Collect

```bash
python3 -I <skill-dir>/scripts/collect.py [--days 30] [--exports <folder>] [--me <name>] > <scratchpad>/feedback.json
python3 -I <skill-dir>/scripts/collect.py --from <scratchpad>/feedback.json --format md > <scratchpad>/appendix.md
```

`<skill-dir>` is the `realpath` of this skill's base directory. The first call makes about one `az` call per PR (204 PRs took about 2 minutes), so run it once and render the appendix from the saved JSON.

What it decides, so you do not re-derive it:

- **PRs**: every PR where I am creator or reviewer that was still open at the window's start, from `az repos pr list` paged 100 at a time (`scripts/collect.py:106-114`). Me = `az account show` user (`scripts/collect.py:117-125`).
- **On my PRs** (`role: author`): every text comment by someone else in the window, plus `waiting for author` / `rejected` votes (`scripts/collect.py:88-102`).
- **On my reviews** (`role: reviewer`): others' replies in threads I started (`scripts/collect.py:88`). These rate my reviewing, mostly "Fixed as suggested".
- **Dropped**: my own comments, system comments and build or bot identities (`scripts/collect.py:27`, `scripts/collect.py:93`).
- **Notes** (`notes[]`): one line per source that failed or was skipped (`scripts/collect.py:199`, `scripts/collect.py:212`, `scripts/collect.py:253`).

### Step 3: Read everything, then theme it

Read every item's `text`; do not sample. Long outputs go to a file. Read it in pages.

- Group the items into 5–9 themes. A theme needs at least two items from different PRs or threads. Name it by the behaviour ("Extra DB round-trips"), not the file.
- A 🤖 comment "read and approved by <name>" counts as that person's.
- Keep feedback on my reviewing as its own theme.
- Say which person dominates the sample when one person wrote more than half of it.

### Step 4: Pick the top 3

Rank by how often a theme recurs across PRs and people × how severe it is (blocking or should-fix outranks a nit). Each pick gets: the behaviour, 3–6 PR or source citations with short quotes, and one concrete *Try:* habit.

### Step 5: Compare with last month

Open the newest earlier `*-personal_feedback-*.md` in the artifact dir, if one exists. For each of its top 3, say in one line whether this month's evidence shows it fading, steady or growing.

### Step 6: Write the report

Claim the artifact (`artifact-protocol` › _Claim_), append `appendix.md` under the last heading and link the file.

---

## 3. Output Format & Deliverables

```markdown
# Personal feedback: <since> → <until>

**Sources read:** … **Not read:** … (from `notes[]`)
**Who:** <name> <count> · …

## Top 3 ways to improve
1. **<behaviour>.** <evidence with !PR citations and short quotes>. *Try:* <habit>.

## Versus last month   ← omit on the first run
## Themes              ← table: Theme | Who | Evidence | Gist
## Positive signals
## Appendix: every item (who, where, what)   ← appendix.md verbatim
```

In chat: the top 3 (one line each), the sources not read and the file link.

---

## 4. Verification & Validation

- Every quote and PR number in the report appears in `feedback.json`.
- The appendix row count equals `len(items)`.
- Every `notes[]` line is in the header.

## 5. Running it monthly

Run it by hand on the first working day of the month. A cloud `/schedule` routine cannot reach the local `az` login or the export folder.
