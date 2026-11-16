---
name: create-series-strip
description: 'Draws a comic strip that recaps your last few days of work. It collects commits, PRs, work item changes and claude-mem sessions with the standup-recap collector, writes a 3–5 panel script starring the white tiger and the Claude Code robot with Swedish speech bubbles, paints the panels locally on the GPU (SDXL steered by your reference images through IP-Adapter), then letters them and lays them out as one strip PNG. Use for /create-series-strip, "make this week''s strip", "recap my week as a comic". Not for standup speaker notes (use /standup-recap).'
disable-model-invocation: true
argument-hint: "[--since YYYY-MM-DD] [--panels 3-5] [--all] [--reroll N,M]"
---

# Skill: `/create-series-strip` — Work-Recap Comic Strip

Turns the evidence of your last few days into a lettered comic strip. The collector supplies the facts, the model writes the script, a local diffusion model paints and a script letters.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes the folder `<prefix>-series_strip-<window.start>/` (strip JSON and images, no markdown); claim it with a plain `mkdir` (fails if it exists) and add `-2`, `-3` on collision

On-demand references (`references/`):

- [`references/strip-format.md`](references/strip-format.md) — the strip JSON fields; read before step 3

- Read-only on every repo and tracker: the only writes are the strip folder and, on first run, the model cache.
- Every fact in a label, caption or bubble comes from the collector JSON. Jokes and exaggeration go in tone, never in numbers, IDs or outcomes.
- Bubbles and captions in Swedish; labels (`#id`, `!id`, states, pipeline results) in English, as in the references.
- People other than me appear only by first name, only when the JSON names them, and never as the butt of a joke.

---

## 1. When _not_ to use

| Situation | Use instead |
| --- | --- |
| Speaker notes for the daily standup | [`/standup-recap`](../standup-recap/SKILL.md) |
| Compare several worktrees, branches or PRs | `claude-mem:standup` |

---

## 2. Core Protocol & Workflow

`<skill-dir>` is the `realpath` of this skill's base directory; `<render>` is `uv run --script <skill-dir>/scripts/render.py`.

### Step 0: First run only

`<render> --setup` downloads the fonts and models (about 11 GB into `~/.cache/huggingface`, plus rembg's cut-out model) and checks that torch sees the GPU. It needs, under `~/.local/share/series-strip/` (`SERIES_STRIP_HOME` moves it):

- `refs/*.jpg|png`: whole reference pictures; they steer the backgrounds.
- `refs/tiger/`, `refs/robot/`: crops showing only that character; they steer each actor. The first render cuts them out onto grey and caches them in `refs/<name>/_clean/` (`scripts/render.py:215`); delete that folder after changing a crop.

With either missing, stop and ask me for pictures. If a download stalls (the cache stops growing), stop it and rerun with `env HF_HUB_DISABLE_XET=1 <render> --setup`.

### Step 1: Collect

```bash
python3 -I <skill-dir>/../standup-recap/scripts/collect.py --since <D> [--all]
```

`<D>` is `--since` when given, else four days before today, so a Monday run covers Thursday to Monday. Save the JSON in the session scratchpad. `yesterday[]` holds the window's work per item, already weighted; `blockers[]` and `today` hold what is still open; `sessions[]` says what each item was about.

### Step 2: Pick the beats

Pick `--panels` beats (default 4) from the heaviest entries, in time order, so the strip reads as a story:

| Evidence | Beat | `setting` | Mood |
| --- | --- | --- | --- |
| Many new work items, an investigation, a plan | Kick-off | `desk` | wide-eyed, scheming |
| Many commits, an abandoned PR, a failed pipeline, a long review round | Struggle | `chaos` | rage, panic, energy drinks |
| PR completed, state → Resolved, green pipelines, a reviewer question answered | Win | `deploy` | fist bump, triumph |
| PRs waiting on review, end of the window | Wind-down | `chill` | relaxed, a wink |
| A shared win, a thank-you | Bonus | `hug` or `meadow` | warm, silly |

The last panel always closes the window (wind-down or bonus). Two items can share a beat; then the panel's label names both.

### Step 3: Write the script

Read [`references/strip-format.md`](references/strip-format.md), then claim the strip folder and write `strip.json` in it:

- `subtitle`: the window (`12–16 nov 2026`) and the repo names from `meta.repos`.
- `scene`: English, the place only (`a messy desk exploding with error lights`). No text, signs or numbers: the painter cannot spell.
- `actors`: the tiger `left` and the robot `right` in every panel unless the beat is about one of them, each with its own action. Never put two cast members in one `scene` or one actor `text`: SDXL blends them into one creature.
- One neon label per panel with the item's real `#id` / `!id` and its outcome (`!19061 → Pull Request`, `!19066 ABANDONED`). Emoji do not render: write `CI red`, not 🔴.
- At most two bubbles per panel, at most 8 words each, in different corners from the label. One `shout` per strip at most.
- Pick a fresh `seed` (any integer) so reruns of the skill give new pictures.

### Step 4: Render

```bash
<render> <strip-folder>/strip.json --out <strip-folder>
```

It prints the path of `strip.png`. Run it in the background: on an RTX 3060 the model loads in about 15 seconds and a panel with two actors takes about 80 (one painting for the background, one per actor). If it warns that VRAM is short, another process (often Ollama) holds the GPU; it falls back to `--offload`, which is slower (`scripts/render.py:495`).

### Step 5: Look and fix

Read `strip.jpg` and check every panel:

| Problem | Fix |
| --- | --- |
| A bubble or label covers a face | Move its `pos`, then rerun with `--relayout` (no repaint, seconds) |
| An actor stands in the wrong spot, too big or facing away | Change its `pos`, `height` or `flip`, then `--relayout` (actors are recomposed on every run, `scripts/render.py:534`) |
| The render logged `actor N cut badly` (`scripts/render.py:526`), or an actor has a box of background around it | Change that panel's `seed`, rerun with `--only N` |
| An actor is off-model, has mangled hands or holds gibberish text | Sharpen its `text`, change the panel's `seed`, rerun with `--only N` |
| The characters drift from the references | Raise `--ip-scale` (default 0.6, `scripts/render.py:465`) by 0.1 and repaint |

At most two repaint rounds per panel; then keep the best and say which panel is weak. `--reroll N,M` from the user means: new seeds for those panels, `--only N,M`.

---

## 3. Output Format & Deliverables

Chat:

```markdown
**Veckans strip — 12–16 nov 2026**
<strip-folder>/strip.png

1. Kick-off: #31654 split into 11 AI-platform items
2. Struggle: SetFit detector, 55 commits, !19066 abandoned
3. Win: !19061 answered Daniel with INotificationDefinition<TData>
4. Wind-down: five PRs waiting on review
```

One line per panel: the beat and the facts it shows. Put the path alone on its line. Print every collector `notes[]` line under it, prefixed `⚠`.

---

## 4. Verification & Validation

- Every label, caption and bubble traces to the collector JSON.
- `strip.png` exists, and you looked at it after the last render.
