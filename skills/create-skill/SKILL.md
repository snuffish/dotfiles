---
name: create-skill
description: "Scaffolds, validates, and registers a new skill or profile in the local registry."
disable-model-invocation: true
---

# Skill: `/create-skill` — Skill Creator & Registry Orchestrator

Systematically designs, scaffolds, validates, and registers new skills in the local skill registry (the parent of this skill's real folder, which holds `_modules/`). Every entry is one of the kinds defined in [`skills/README.md`](../README.md) › *Kinds* and [`GLOSSARY.md`](../../GLOSSARY.md); the kind decides the template.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — the deliverable is the new skill directory

On-demand references (`references/`):
- [`references/command-template.md`](references/command-template.md) — `SKILL.md` template for Commands
- [`references/reference-profile-template.md`](references/reference-profile-template.md) — `SKILL.md` rules for References and Profiles

---

## 1. When *not* to use

A shared contract that several Commands depend on and that never runs on its own is a **Module**, not a skill. Write it as `skills/_modules/<name>.md` (plain markdown, no frontmatter, never symlinked; see [ADR-0001](../../docs/adr/0001-modules-live-outside-skill-loaders.md) and [ADR-0002](../../docs/adr/0002-module-paths-relative-to-real-skill-folder.md)) or an on-demand reference under `skills/_modules/references/<name>.md`.

---

## 2. Step-by-Step Creation Workflow

### Step 1 — Kind, Scope & Placement Resolution

1. **Kind** (see [`skills/README.md`](../README.md) › *Kinds*; ask if not obvious): **Command** (has `## Modules`), **Reference** (no `## Modules`), or **Profile** (`user-invocable: false`, no `## Modules`).
2. **Scope & Placement** (skills are general and project-agnostic by default):

| Placement | Directory Target | Use Case | Naming Convention |
|---|---|---|---|
| **General (Default)** | `skills/<name>/` | Universal workflows, patterns, or tooling | Single kebab-case name (e.g. `organize`, `code-review`, `expressive`) |
| **Project-Scoped** | `skills/Projects/<Project>/<name>/` | Explicit single-project rules, and always for a Profile | `<project>-<app>-*` (e.g. `priis-backend-*`, `priis-prod-*`), `<project>-profile`, `<command>-<project>-profile` |

Never place a skill under `skills/_modules/`.

#### Description & Trigger Rules:
- **General Skills**: crisp, domain-focused `description` without project gating.
- **Project-Scoped Skills**: always gated. Open with `[Project: <Project>]` and close with the canonical gate sentence (for GR.PRIIS: `Load ONLY when working in the GR.PRIIS repository or the GR folder that holds it.`).
- **What, then when, then neighbour**: state the use case first, then trigger phrases (`Use for /x, "phrase"`), then `"Not for X (use /y)."` Keep `description` ≤ 1024 chars.
- **Frontmatter flags**: `disable-model-invocation: true` (+ `argument-hint`) for user-only Commands; `user-invocable: false` (never `disable-model-invocation`) for Profiles.
- **Lean body**: keep `SKILL.md` to the workflow (<200 lines); move catalogs, templates, and long examples into `references/` and link them as `[`references/<file>.md`](references/<file>.md)`.

---

### Step 2 — Structure & Architecture Wiring

Draft `SKILL.md` from [`references/command-template.md`](references/command-template.md) (Command) or [`references/reference-profile-template.md`](references/reference-profile-template.md) (Reference / Profile).

#### Module & Link Wiring Rules:
- List only the Modules the Command uses directly (`../_modules/<name>.md` at top level, `../../../_modules/<name>.md` under `Projects/<Project>/`), keeping the `realpath` preamble verbatim ([ADR-0002](../../docs/adr/0002-module-paths-relative-to-real-skill-folder.md)).
- Link sibling skills relatively (`[code-review](../code-review/SKILL.md)`) only within the same placement group; across groups (`skills/<name>` ↔ `skills/Projects/<Project>/<name>`), name the skill in prose instead.
- Link files inside the skill's own `references/` folder as `[`references/<file>.md`](references/<file>.md)` (and from `references/<file>.md` back to `SKILL.md` or `../../_modules/…`).
- Never write machine-specific paths (`/Users/<name>/…`, `/home/<name>/…`); use `~/…`, relative links, or placeholders (`<registry>`, `<workspace-root>`).
- Refer to Module sections by heading name, never by number: `` `git-worktrees` › *Workspace Lifecycle* ``.
- If the Command writes an artifact, add its base name to `_modules/references/artifact-catalog.md`.

---

### Step 3 — File Scaffolding

1. Create `skills/<name>/` (or `skills/Projects/<Project>/<name>/`) and write `SKILL.md`.
2. Place supporting files in `references/` (on-demand markdown with a `# Title` H1 on line 1), `templates/`, or `scripts/` (invoked via `python3 -I <skill-dir>/scripts/<tool>.py`).

---

### Step 3b — Prove It

New tooling is proven by a run, not just written. Before Step 4, run two realistic prompts through sub-agents that read the new `SKILL.md` and follow it:

- Keep run outputs in the session scratchpad, never next to the skill: the registry lints every folder in it.
- A skill that asks the user questions or writes outside its outputs runs in a dry-run mode (add the flag to the skill if it has none), with each round's answers scripted in the sub-agent's prompt.
- Each sub-agent also writes `notes.md`: every instruction it found unclear, contradictory or had to guess at. These notes are the main signal; fix the skill from them, then rerun once.
- With the skill-creator's static review page, an absent `feedback.json` means the user did not submit; ask for comments in chat instead of reading it as approval.

Done when a rerun's `notes.md` holds no problem you would still fix.

---

### Step 4 — Registry Inventory, Lint & Sync

1. Update [`skills/README.md`](../README.md) (summary counts, Inventory table row, and `Projects/<Project>/` tree when project-scoped).
2. Extract verifiable claims for the new skill into `skills/skills-claims.json` and run `python3 -I <registry>/skill-drift/scripts/check_skill_drift.py --file 'skills/<name>/*'` ([`/skill-drift`](../skill-drift/SKILL.md)).
3. Run [`/sync-skills`](../sync-skills/SKILL.md) (`python3 -I <registry>/sync-skills/sync_skills.py` to lint `SKILL.md`, `references/*.md`, `_modules/**/*.md`, `skills-claims.json`, and `README.md` counts; add `--apply` when requested to link the skill into `~/.claude/skills`, `~/.gemini/config/skills`, `~/.gemini/skills`, and `skills/Projects/<Project>/.flat-links/`).
