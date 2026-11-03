---
name: insights
description: Analyses recent Antigravity session transcripts and renders an HTML usage report (what you work on, interaction style, friction, rule suggestions) in the same layout as Claude Code's /insights.
compatibility: antigravity
---

# Skill: `/insights` — Antigravity usage report

Mirrors Claude Code's `/insights`: a script counts what happened, you rate each session and write the narrative, the script renders the HTML. Data lives in `~/.gemini/antigravity-cli/usage-data/` (`DEFAULT_DATA` in `scripts/generate_insights.py`).

The script is `~/.terminal/skills/insights/scripts/generate_insights.py`; use that absolute path.

## Step 1 — Collect

```bash
python3 ~/.terminal/skills/insights/scripts/generate_insights.py collect --days 14 --max 200
```

Reads transcripts modified in the last 14 days (newest 200), writes `session-meta/<id>.json` and `digests/<id>.json` (at most 6 KB each), and prints the ids that need a facet: no facet yet, or the transcript changed since it was rated. Cached facets are reused. The first run rates up to 200 sessions, so say that to the user before starting.

## Step 2 — Write a facet per listed id

Read each listed `digests/<id>.json`, in batches of about 10, and write `facets/<id>.json` with exactly these keys:

`underlying_goal` (str), `goal_categories` ({name: count}), `outcome` (str), `user_satisfaction_counts` ({level: count}), `agent_helpfulness` (str), `session_type` (str), `friction_counts` ({type: count}), `friction_detail` (str), `primary_success` (str, `none` if no success), `brief_summary` (str), `session_id` (the id), `transcript_mtime` (copied from the digest).

Rate only what the digest shows; do not invent.

## Step 3 — Write `usage-data/sections.json`

From all facets plus the `session-meta` totals. Every field is required and non-empty:

- `at_a_glance`: `whats_working`, `whats_hindering`, `quick_wins`, `ambitious_workflows` (str)
- `project_areas.areas[]`: `name`, `session_count` (int), `description`
- `interaction_style`: `narrative` (paragraphs separated by a blank line), `key_pattern`
- `what_works`: `intro`, `impressive_workflows[]` of `title`, `description`
- `friction_analysis`: `intro`, `categories[]` of `category`, `description`, `examples[]` (str)
- `suggestions`: `rules_additions[]` of `addition`, `why`; `features_to_try[]` of `feature`, `one_liner`, `why_for_you`, `example_code`; `usage_patterns[]` of `title`, `suggestion`, `detail`, `copyable_prompt`
- `on_the_horizon`: `intro`, `opportunities[]` of `title`, `whats_possible`, `how_to_try`, `copyable_prompt`
- `fun_ending`: `headline`, `detail`

## Step 4 — Render

```bash
python3 ~/.terminal/skills/insights/scripts/generate_insights.py render
```

Exits non-zero, naming the problem, when a section is missing or empty, or when an analysed session has no fresh facet. Fix the named file and rerun. Writes `report-<timestamp>.html` (mode 0600) and prints its path.

## Step 5 — Reply

Give the report path as a link, the four `at_a_glance` lines, and end with: "Want to dig into any section?". Do not write a markdown artifact or edit `MY-RULES.md` or `AGENTS.md`; the report's rule suggestions are copy buttons for the user.
