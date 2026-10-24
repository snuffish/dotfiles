---
name: sync-skills
description: "Lints the local skills registry and repairs its loader wiring. Validates every SKILL.md (name matches folder, description present and at most 1024 characters, `## Modules` paths resolve, links to other skills and Modules resolve, no SKILL.md under _modules/), symlinks general skills and Profiles into ~/.claude/skills, prunes dead registry links, keeps project References out of the flat loader unless allow-listed (a global link would shadow the project repo's own copy), checks .agents/skills.json, and updates the README inventory. Use for /sync-skills, \"sync skills\", \"lint the registry\", \"relink my skills\", \"a skill moved or was renamed\", or after /create-skill. Not needed just to pick up an edited or newly linked skill: Claude Code reloads ~/.claude/skills live, and its built-in /reload-skills covers a newly created skills directory."
---

# Skill: `/sync-skills` — Registry Lint & Loader Sync

Checks that every skill in the local registry (`<registry>`) is well-formed, then makes the loaders match the registry: flat symlinks in `~/.claude/skills` for Claude Code, and `.agents/skills.json` entries for Antigravity. It reports what it changed. It does not load skills into the running session; the hosts do that themselves.

`<registry>` is the registry root: the parent of this skill's real directory (`dirname "$(realpath ~/.claude/skills/sync-skills)"`). Resolve it once and use the absolute path everywhere below, so the run works wherever the registry is cloned.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-skills_sync_report-<suffix>.md` only when requested or for a major registry audit (e.g. `-full-audit`, `-broken-links`). A regular sync answers in chat.

---

## Rules

1. **The registry is the source of truth; loaders follow it.** General skills and Profiles each get one symlink `~/.claude/skills/<name>` pointing at their folder in `<registry>`. Skills in `~/.agents/skills/<name>` also get one symlink in `~/.claude/skills/<name>` unless `<registry>` defines `<name>` (the registry wins on name clash).
2. **Project References stay out of the flat loader unless allow-listed.** Claude Code resolves a name clash as *personal over project*, so a global link to `Projects/<Project>/<name>` silently overrides the copy the project's own repo ships in `.claude/skills/`. A project skill is linked only when its name is listed in `Projects/<Project>/.flat-links` (one name per line). Profiles (`*-profile`) are always linked, because no repo ships them.
3. **Modules are never skills.** `<registry>/_modules/` holds Modules (plain markdown, no frontmatter; ADR-0001, ADR-0002). Nothing in it is linked or counted, and a `SKILL.md` there is an error.
4. **Prune only what this registry or `~/.agents/skills` owns.** A dead link is removed only when it points into `<registry>/` or `~/.agents/skills/`. Links into other places (plugin folders) are reported, never touched.
5. **Lint, don't rewrite.** The run edits loader links, `.agents/skills.json` entries and the README inventory. It never changes the instructions inside a `SKILL.md`; it reports problems for the user to fix.

---

## Steps

### Step 1: Discover and lint

Run the script in *Sync script* below in check mode. It walks `<registry>` (skipping `_modules/`) and checks every `SKILL.md`:

- **Name** in the frontmatter equals the folder name.
- **Description** is present, single-line and at most 1024 characters (the Agent Skills spec limit). Over 1024 is an error. Over 700 is a warning, because every installed skill shares one listing budget and Claude Code drops descriptions when it overflows, least-used skills first.
- **Project gating**: a skill under `Projects/<Project>/` has a description that opens with `[Project:` and contains `Load ONLY when`.
- **Modules**: every `## Modules` path is relative, resolves from the skill's real folder to a file in `_modules/` (ADR-0002), and the section has the stop sentence.
- **Links**: every relative link to another skill (`…/SKILL.md`), a Module (`_modules/…`) or a `references/` file resolves. Template placeholders (`<…>`, `…`) are skipped.
- **Retired names**: no link to the retired `core` skill (it is a Module now), and no Module section referred to by number.
- **Fences**: an odd number of ```` ``` ```` fence lines means an unclosed code block.

### Step 2: Reconcile `~/.claude/skills`

Run it again with `--apply` when check mode planned changes. If the plan unlinks anything, list those names and ask first: an unlink takes a skill away from every session. With `--apply` the script:

1. Creates a missing link, or repoints a wrong one, for every general skill, every Profile and every allow-listed project skill.
2. Prunes a link into `<registry>` whose target is gone.
3. Unlinks a link into `<registry>/Projects/` for a project skill that is not allow-listed (Rule 2), and says why.
4. Reports dead links that point elsewhere, without touching them.

Claude Code watches `~/.claude/skills` and picks up added, edited or removed skills within the running session. Only a top-level skills directory created after the session started needs the built-in `/reload-skills`.

### Step 3: Check `.agents/skills.json`

The script checks the `.agents/skills.json` of every workspace in a project's `.workspaces`; also read the active workspace's file when it is not one of them. Antigravity scans each entry's direct children, so every `Projects/<Project>` folder (or repo `.claude/skills`) whose skills that workspace needs must be listed. Report a missing or dead entry and propose the exact JSON line; add it only if the user asks. If the workspace has `.agents/AGENTS.md`, check that new skills are documented there too.

### Step 4: Update the README inventory

In `<registry>/README.md`, recount the skills by group and kind, and update the summary line and the inventory table (alphabetical). Update the *Current live state* paragraph if the linking rules changed.

### Step 5: Git status

Run `git -C <registry> status -s` and list new or modified skills that are not committed.

---

## Sync script

[`sync_skills.py`](sync_skills.py) next to this file holds the lint and the link rules. It finds the registry from its own location, so it runs before any skill is linked, and the shell has it as `sync-skills` (`claude.bash`), which runs the check and then asks before applying:

```bash
python3 -I <registry>/sync-skills/sync_skills.py            # check: lint, planned link changes, workspace checks; writes nothing
python3 -I <registry>/sync-skills/sync_skills.py --apply    # also fixes ~/.claude/skills
```

- `--apply` refuses to run from a `.claude/worktrees/` checkout, which would point every link into the worktree. Pass `--registry <main checkout>/skills` to override.
- `Projects/<Project>/.workspaces` lists the workspaces that use the project, one path per line (`~` allowed). For each one present on this machine the check reports project skills that are neither linked nor shipped in a repo's `.claude/skills/`, and problems in its `.agents/skills.json`. A workspace missing on this machine is skipped.
- `.flat-links` and `.workspaces` take one entry per line; blank lines and `#` comments are ignored.
- Exit status 1 when the lint finds errors or a link change fails.

---

## Output

Answer in chat, in this shape:

```markdown
### Skills sync

**Registry:** <N> skills (<general> general, <project> project) · <errors> errors · <warnings> warnings

**~/.claude/skills:** created <…> · repointed <…> · pruned <…> · unlinked <…> · held out <N> (project References not allow-listed)

**Errors** (fix before committing): <one line each, as `path: problem`>

**Warnings:** <one line each>

**.agents/skills.json:** <entries OK, or the exact line to add>

**README inventory:** <updated, or unchanged>

**Git:** <clean, or the uncommitted skills>
```

---

## Verification

- A second check-mode run plans no link changes.
- `find ~/.claude/skills -maxdepth 1 -xtype l` prints only links that point outside `<registry>`.
- Every general skill and every Profile has a link; no project skill outside `.flat-links` does.
- The README counts match the script's counts.
- No `SKILL.md` content changed (`git -C <registry> diff --stat` shows only `README.md`, if anything).
