---
name: sync-skills
description: "Lints the skills registry, verifies links and Modules, syncs loaders (~/.claude/skills, ~/.gemini/config/skills, ~/.gemini/skills), and audits .agents/skills.json."
disable-model-invocation: true
---

# Skill: `/sync-skills` — Registry Lint & Loader Sync

Checks that every skill in the local registry (`<registry>`) is well-formed, then makes the loaders match the registry: flat symlinks in `~/.claude/skills` for Claude Code, `~/.gemini/config/skills` for Antigravity, and `~/.gemini/skills` for Gemini CLI, plus `.agents/skills.json` audits. It reports what it changed. It does not load skills into the running session; the hosts do that themselves.

`<registry>` is the registry root: the parent of this skill's real directory (e.g. `dirname "$(realpath "$HOME/.terminal/skills/sync-skills")"`). Resolve it once and use the absolute path everywhere below, so the run works wherever the registry is cloned.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-skills_sync_report-<suffix>.md` only when requested or for a major registry audit (e.g. `-full-audit`, `-broken-links`). A regular sync answers in chat.

---

## Rules

1. **The registry is the source of truth; loaders follow it.** General skills and Profiles each get one symlink in each loader target (`~/.claude/skills/<name>`, `~/.gemini/config/skills/<name>`, `~/.gemini/skills/<name>`) pointing at their folder in `<registry>`. Skills in `~/.agents/skills/<name>` also get one symlink in each loader target unless `<registry>` defines `<name>` (the registry wins on name clash). Skills in active Claude Code plugins (`~/.claude/plugins/installed_plugins.json`) are symlinked into non-Claude loaders (`~/.gemini/config/skills`, `~/.gemini/skills`) unless already provided by the registry or `~/.agents/skills`.
2. **Monolithic loader symlinks are converted to flat link directories.** If a target directory (such as `~/.gemini/config/skills`) is a top-level symlink pointing to `<registry>`, `--apply` replaces it with a real directory containing individual leaf symlinks, leaving the registry contents untouched.
3. **Project References stay out of flat loaders unless allow-listed.** Claude Code and Antigravity resolve a name clash as *personal over project*, so a global link to `Projects/<Project>/<name>` silently overrides the copy the project's own repo ships in `.claude/skills/` or `.agents/skills/`. A project skill is linked only when its name is listed in `Projects/<Project>/.flat-links` (one name per line). Profiles (`*-profile`) are always linked, because no repo ships them.
4. **Modules are never skills.** `<registry>/_modules/` holds Modules (plain markdown, no frontmatter; ADR-0001, ADR-0002). Nothing in it is linked or counted, and a `SKILL.md` there is an error.
5. **Prune only what this registry, `~/.agents/skills`, or installed plugins own.** A dead link is removed only when it points into `<registry>/`, `~/.agents/skills/`, or an installed Claude plugin directory (`~/.claude/plugins/`). Links into other places are reported, never touched.
6. **Lint, don't rewrite.** The run edits loader links, audits `.agents/skills.json` and updates the README inventory. It never changes the instructions inside a `SKILL.md`; it reports problems for the user to fix.
7. **Global instruction rules follow `AGENTS.md`.** `AGENTS.md` at registry parent (`~/.terminal/AGENTS.md`) is the canonical source of truth for global agent instructions. It is reconciled as a symlink to `~/.terminal/CLAUDE.md`, `~/.claude/CLAUDE.md`, and `~/.gemini/GEMINI.md`.

---

## Steps

### Step 1: Discover and lint

Run the script in *Sync script* below in check mode. It walks `<registry>` (skipping `_modules/`) and checks every `SKILL.md`:

- **Frontmatter attributes**: all declared fields match known Claude Code / Agent Skills keys. Boolean fields (`user-invocable`, `disable-model-invocation`, `background`) have valid boolean values.
- **Profile gating**: every Profile (`*-profile`) has `user-invocable: false` and does not set `disable-model-invocation: true`.
- **Name** in the frontmatter equals the folder name.
- **Description** is present, single-line and at most 1024 characters (the Agent Skills spec limit). Over 1024 is an error. Over 700 is a warning, because every installed skill shares one listing budget and hosts drop descriptions when it overflows, least-used skills first.
- **Project gating**: a skill under `Projects/<Project>/` has a description that opens with `[Project:` and contains `Load ONLY when`.
- **Modules**: every `## Modules` path is relative, resolves from the skill's real folder to a file in `_modules/` (ADR-0002), and the section has the stop sentence.
- **Links**: every relative link to another skill (`…/SKILL.md`), a Module (`_modules/…`) or a `references/` file resolves. Template placeholders (`<…>`, `…`) are skipped.
- **Retired names**: no link to the retired `core` skill (it is a Module now), and no Module section referred to by number.
- **Fences**: an odd number of ```` ``` ```` fence lines means an unclosed code block.

### Step 2: Reconcile Loaders (Claude Code, Antigravity, Gemini CLI)

Run it again with `--apply` when check mode planned changes. If the plan unlinks anything, list those names and ask first: an unlink takes a skill away from every session. With `--apply` the script:

1. Replaces any monolithic target symlink with a real directory.
2. Creates a missing link, or repoints a wrong one, for every general skill, every Profile and every allow-listed project skill across all enabled targets.
3. Prunes a link into `<registry>` whose target is gone.
4. Unlinks a link into `<registry>/Projects/` for a project skill that is not allow-listed (Rule 3), and says why.
5. Reports dead links that point elsewhere, without touching them.

### Step 3: Check `.agents/skills.json` & Global Antigravity Config

The script checks the `.agents/skills.json` of every workspace in a project's `.workspaces`; also read the active workspace's file when it is not one of them. Antigravity scans each entry's direct children, so every `Projects/<Project>` folder (or repo skills folder) whose skills that workspace needs must be listed.
The script also audits `~/.gemini/config/skills.json`. Because `~/.gemini/config/skills/` links all skills including `~/.agents/skills/`, redundant entries in `skills.json` are reported as warnings to avoid duplicate skill loads.

### Step 4: Update the README inventory

In `<registry>/README.md`, recount the skills by group and kind, and update the summary line and the inventory table (alphabetical). Update the *Current live state* paragraph if the linking rules changed.

### Step 5: Git status

Run `git -C <registry> status -s` and list new or modified skills that are not committed.

---

## Sync script

[`sync_skills.py`](sync_skills.py) next to this file holds the lint and the link rules. It finds the registry from its own location, so it runs before any skill is linked, and the shell has it as `sync-skills` (`claude.bash` / `code.bash`), which runs the check and then asks before applying:

```bash
python3 -I <registry>/sync-skills/sync_skills.py            # check: lint, planned link changes across targets; writes nothing
python3 -I <registry>/sync-skills/sync_skills.py --apply    # fixes ~/.claude/skills, ~/.gemini/config/skills, ~/.gemini/skills
```

- `--targets <list>` limits reconciliation to specific hosts (e.g. `--targets claude,antigravity`).
- `--apply` refuses to run from any worktree checkout (`.claude/worktrees/`, `.agents/worktrees/`, `.gemini/worktrees/`), which would point links into the worktree. Pass `--registry <main checkout>/skills` to override.
- `Projects/<Project>/.workspaces` lists the workspaces that use the project, one path per line (`~` allowed). For each one present on this machine the check reports project skills that are neither linked nor shipped in a repo's host skills dirs, and problems in its `.agents/skills.json`. A workspace missing on this machine is skipped.
- `.flat-links` and `.workspaces` take one entry per line; blank lines and `#` comments are ignored.
- Exit status 1 when the lint finds errors or a link change fails.

---

## Output

Answer in chat, in this shape:

```markdown
### Skills sync

**Registry:** <N> skills (<general> general, <project> project) · <errors> errors · <warnings> warnings
**Targets:**
- **claude (~/.claude/skills):** created <…> · repointed <…> · pruned <…> · unlinked <…>
- **antigravity (~/.gemini/config/skills):** created <…> · repointed <…> · pruned <…> · unlinked <…>
- **gemini (~/.gemini/skills):** created <…> · repointed <…> · pruned <…> · unlinked <…>

**Held out:** <N> (project References not allow-listed)

**Errors** (fix before committing): <one line each, as `path: problem`>

**Warnings:** <one line each>

**Workspaces:** <status per workspace>

**Git:** <clean, or the uncommitted skills>
```

---

## Verification

- A second check-mode run plans no link changes across all targets.
- `find ~/.claude/skills ~/.gemini/config/skills ~/.gemini/skills -maxdepth 1 -xtype l` prints only links that point outside `<registry>`.
- Every general skill and every Profile has a link in each target; no project skill outside `.flat-links` does.
- The README counts match the script's counts.
- No `SKILL.md` content changed outside the documented rules.
