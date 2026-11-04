---
name: skill-drift
description: "Keeps the registry's skills, Modules, Profiles, and repo docs true to the code. Runs skills/skill-drift/scripts/check_skill_drift.py against skills/skills-claims.json (plus automatic link, #anchor, and › *Heading* pointer checks), triages FAIL and STALE claims, fixes drift, and re-extracts claims after skill edits. Use when the skill-drift check fails in sync-skills or the session-start warning fires, after editing a SKILL.md, Module, or AGENTS.md, or for /skill-drift, \"check skill drift\", \"update skills-claims.json\", \"are the skills still right?\"."
argument-hint: "[--file <glob> | --project <name> | --strict]"
---

# Skill: `/skill-drift` — Skills & Modules vs. Code

The skills in `skills/`, the shared Modules in `skills/_modules/`, the project skills in `skills/Projects/<Project>/`, and the repo docs (`claude/AGENTS.md`, `skills/README.md`, `GLOSSARY.md`, `docs/adr/*.md`) state facts about `~/.terminal` and target project repositories (such as `GR.PRIIS`): paths, scripts, CLI flags, symbols, ports, counts, and other skills. `skills/skills-claims.json` lists each verifiable fact with its source line, quote, and verification rule. [`scripts/check_skill_drift.py`](scripts/check_skill_drift.py) checks every claim against the git-tracked files and automatically verifies all relative markdown links, `#anchor` slugs, and `` `<target>` › *Heading* `` pointers.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — fixes drift in the skills or `skills/skills-claims.json` and reports in chat

On-demand references (`references/`):
- [`references/claims-schema.md`](references/claims-schema.md) — `skills/skills-claims.json` claim schema, `base` roots (`repo`, `file_dir`, `project:<Project>`), `verify` methods, and good targets

---

## Where it runs

- **Registry lint (`/sync-skills`):** `skills/sync-skills/sync_skills.py` runs `check_skill_drift.py` during Step 1 and folds any `FAIL` or `STALE` claims into the lint error count.
- **Session start:** `claude/skill-drift-warning.py` (registered under `hooks.SessionStart` in `claude/settings.json`) caches the check result in `.git/skill-drift-cache.json` and warns when any claim is `FAIL` or `STALE`.

---

## 1. Run the check

`<registry>` is the parent of this skill's real folder (`dirname "$(realpath "$HOME/.terminal/skills/skill-drift")"`).

```bash
python3 -I <registry>/skill-drift/scripts/check_skill_drift.py                                   # all claims + auto-scan
python3 -I <registry>/skill-drift/scripts/check_skill_drift.py --file 'skills/_modules/*'        # only matching sources
python3 -I <registry>/skill-drift/scripts/check_skill_drift.py --project GR.PRIIS                # only GR.PRIIS project claims
python3 -I <registry>/skill-drift/scripts/check_skill_drift.py --json                            # machine-readable output
python3 -I <registry>/skill-drift/scripts/check_skill_drift.py --strict                          # WARN rows fail too
python3 -I <registry>/skill-drift/scripts/check_skill_drift.py --mcp                             # query configured stdio MCP servers
```

| Status | Meaning | Fails the run |
|---|---|---|
| `FAIL` | A path, `#anchor`, `` `<target>` › *Heading* `` pointer, symbol, port, config key, npm script, or skill the text names is gone | yes |
| `STALE` | The claim's `quote` is no longer in its source file: the skill text changed, so the claim must be re-extracted (§3) | yes |
| `WARN` | Fuzzy prose checks (`kind: "other"`), counts, zero-claim coverage warnings, executables on `PATH`, MCP tools | only with `--strict` |
| `SKIP` | `manual` claims, `project:<Project>` claims whose `.workspaces` checkout is not on this machine, and MCP tools without `--mcp` | no |

Exit code `0` = clean, `1` = failures, `2` = `skills/skills-claims.json` unreadable.

---

## 2. Triage a `FAIL`

For each `FAIL` row, read the skill line in context and inspect the code or target file the claim points at, then decide:

| Verdict | Signs | Fix |
|---|---|---|
| **Skill wrong** | A file, heading, script, flag, symbol, or skill moved, was renamed, or no longer matches the codebase | Update the skill text to match the code at `HEAD`, citing the file you checked. Then re-extract that line's claim (§3) |
| **Claim wrong** | The skill text is accurate, but the claim's `verify` rule targets the wrong path, regex, or `base` | Fix the claim's `verify` block in `skills/skills-claims.json` |

Common `Claim wrong` patterns:
- **Git-ignored or generated files** (`routeTree.gen.ts`, `src/store/api/generated/*`, `appsettings.local.json`): the checker only sees git-tracked files. Verify the `.gitignore` entry or generator config instead.
- **Placeholder or illustrative code** (`CreateFooRequest`, `<prefix>-implementation_plan-<suffix>.md`): drop the claim or mark it `manual`.
- **Target project file checked against `base: "repo"`**: set `"base": "project:<Project>"` (e.g. `"project:GR.PRIIS"`) so it resolves against the workspace in `skills/Projects/<Project>/.workspaces`.

Every fact written into a skill must be true at `HEAD`: `grep` or read the code you cite before editing.

---

## 3. Re-extract claims after editing a skill

Whenever you edit a covered file (or create a new skill or Module, or fix a skill gap), update its claims in the same change:

1. Run `check_skill_drift.py --file '<glob>'` on the files you edited. `STALE` rows show the claims whose `quote` changed; `WARN` coverage rows show covered files with zero claims.
2. In `skills/skills-claims.json`, remove or update the stale entries (from a Python script that loads the file and writes it back with `json.dumps(data, indent=2) + "\n"`, never with the Edit or Write tool: a PostToolUse `prettier --write` hook reformats the whole file, and the checker then fails it as not canonical) and add one claim per verifiable fact in the new or edited lines, following [`references/claims-schema.md`](references/claims-schema.md).
3. Re-run `check_skill_drift.py` and `/sync-skills`: confirm `0 fail`, `0 stale`, and `✓ 0 errors`.

A quote that only moved to another line number in the same file is located automatically and does not become `STALE`.

---

## 4. Scope

Covered in `~/.terminal`:
- `skills/**/SKILL.md` and `skills/**/references/*.md` (general skills, Profiles, and `skills/Projects/<Project>/**`)
- Shared Modules under `skills/_modules/` (`*.md` and `references/*.md`)
- `claude/AGENTS.md`, `skills/README.md`, `GLOSSARY.md`, and `docs/adr/*.md`
