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

1. **The registry is the source of truth; loaders follow it.** General skills and Profiles each get one symlink `~/.claude/skills/<name>` pointing at their folder in `<registry>`.
2. **Project References stay out of the flat loader unless allow-listed.** Claude Code resolves a name clash as *personal over project*, so a global link to `Projects/<Project>/<name>` silently overrides the copy the project's own repo ships in `.claude/skills/`. A project skill is linked only when its name is listed in `Projects/<Project>/.flat-links` (one name per line). Profiles (`*-profile`) are always linked, because no repo ships them.
3. **Modules are never skills.** `<registry>/_modules/` holds Modules (plain markdown, no frontmatter; ADR-0001, ADR-0002). Nothing in it is linked or counted, and a `SKILL.md` there is an error.
4. **Prune only what this registry owns.** A dead link is removed only when it points into `<registry>/`. Links into other places (`../../.agents/skills/*`, plugin folders) are reported, never touched.
5. **Lint, don't rewrite.** The run edits loader links, `.agents/skills.json` entries and the README inventory. It never changes the instructions inside a `SKILL.md`; it reports problems for the user to fix.

---

## Steps

### Step 1: Discover and lint

Run the script in *Sync script* below. It walks `<registry>` (skipping `_modules/`) and checks every `SKILL.md`:

- **Name** in the frontmatter equals the folder name.
- **Description** is present, single-line and at most 1024 characters (the Agent Skills spec limit). Over 1024 is an error. Over 700 is a warning, because every installed skill shares one listing budget and Claude Code drops descriptions when it overflows, least-used skills first.
- **Project gating**: a skill under `Projects/<Project>/` has a description that opens with `[Project:` and contains `Load ONLY when`.
- **Modules**: every `## Modules` path is relative, resolves from the skill's real folder to a file in `_modules/` (ADR-0002), and the section has the stop sentence.
- **Links**: every relative link to another skill (`…/SKILL.md`), a Module (`_modules/…`) or a `references/` file resolves. Template placeholders (`<…>`, `…`) are skipped.
- **Retired names**: no link to the retired `core` skill (it is a Module now), and no Module section referred to by number.
- **Fences**: an odd number of ```` ``` ```` fence lines means an unclosed code block.

### Step 2: Reconcile `~/.claude/skills`

The same script then:

1. Creates a missing link, or repoints a wrong one, for every general skill, every Profile and every allow-listed project skill.
2. Prunes a link into `<registry>` whose target is gone.
3. Unlinks a link into `<registry>/Projects/` for a project skill that is not allow-listed (Rule 2), and says why.
4. Reports dead links that point elsewhere, without touching them.

Claude Code watches `~/.claude/skills` and picks up added, edited or removed skills within the running session. Only a top-level skills directory created after the session started needs the built-in `/reload-skills`.

### Step 3: Check `.agents/skills.json`

In the active workspace, read `.agents/skills.json`. Antigravity scans each entry's direct children, so every `Projects/<Project>` folder whose skills that workspace needs must be listed. Report a missing entry and propose the exact JSON line; add it only if the user asks. If the workspace has `.agents/AGENTS.md`, check that new skills are documented there too.

### Step 4: Update the README inventory

In `<registry>/README.md`, recount the skills by group and kind, and update the summary line and the inventory table (alphabetical). Update the *Current live state* paragraph if the linking rules changed.

### Step 5: Git status

Run `git -C <registry> status -s` and list new or modified skills that are not committed.

---

## Sync script

Run it with `python3 - <<'PY' … PY`, after replacing `<registry>` if `~/.claude/skills/sync-skills` is not linked yet (the first run after a rename).

```python
import json, os, re

_self = os.path.realpath(os.path.expanduser('~/.claude/skills/sync-skills'))
root = os.path.dirname(_self) if os.path.isdir(_self) else os.path.expanduser('<registry>')
flat = os.path.expanduser('~/.claude/skills')
modules = os.path.join(root, '_modules')
os.makedirs(flat, exist_ok=True)

errors, warnings, skills = [], [], {}
module_ref = re.compile(r'^- `([^`]*_modules/[^`]+\.md)`', re.M)
link_ref = re.compile(r'\]\(((?:\.\./)*[\w./-]*(?:SKILL\.md|_modules/[\w-]+\.md|references/[\w./-]+))(?:#[^)]*)?\)')
guard = 'If any Module cannot be read, stop and report the path.'
retired = re.compile(r'(?<![\w-])core/SKILL\.md|(?<![\w-])(?:core|git-worktrees|artifact-protocol)`? §')

def allowed(project_dir):
    path = os.path.join(project_dir, '.flat-links')
    return set(open(path).read().split()) if os.path.isfile(path) else set()

for d, _, files in os.walk(root):
    if d == modules or d.startswith(modules + os.sep):
        if 'SKILL.md' in files:
            errors.append(f'{d}: SKILL.md inside _modules/')
        continue
    if 'SKILL.md' not in files or '/.git' in d:
        continue
    text = open(os.path.join(d, 'SKILL.md'), encoding='utf-8').read()
    m = re.match(r'---\n(.*?)\n---\n', text, re.S)
    if not m:
        errors.append(f'{d}: no frontmatter'); continue
    fm = m.group(1)
    name = (re.search(r'^name:\s*(.+)$', fm, re.M) or [None, None])[1]
    raw = (re.search(r'^description:\s*(.+)$', fm, re.M) or [None, ''])[1].strip()
    desc = json.loads(raw) if raw.startswith('"') else raw.strip("'")
    folder = os.path.basename(d)
    project = os.path.relpath(d, root).startswith('Projects' + os.sep)
    if name != folder:
        errors.append(f'{d}: name {name!r} != folder {folder!r}')
    if not desc or desc in ('>', '>-', '|', '|-'):
        errors.append(f'{d}: description missing or multi-line')
    elif len(desc) > 1024:
        errors.append(f'{d}: description {len(desc)} chars > 1024')
    elif len(desc) > 700:
        warnings.append(f'{d}: description {len(desc)} chars (listing budget)')
    if project and not (desc.startswith('[Project:') and 'Load ONLY when' in desc):
        errors.append(f'{d}: project skill not gated')
    mods = module_ref.findall(text)
    for mod in mods:
        target = os.path.realpath(os.path.join(d, mod))
        if mod.startswith(('/', '~')) or not (os.path.isfile(target) and os.path.dirname(target) == modules):
            errors.append(f'{d}: Module path {mod!r} does not resolve into _modules/')
    if mods and guard not in text:
        errors.append(f'{d}: ## Modules has no stop sentence')
    for link in link_ref.findall(text):
        if '<' in link or '…' in link:
            continue
        if not os.path.exists(os.path.realpath(os.path.join(d, link))):
            errors.append(f'{d}: dead link {link}')
    if retired.search(text):
        errors.append(f'{d}: retired core link or numbered Module section')
    if sum(1 for line in text.splitlines() if line.lstrip().startswith('`' * 3)) % 2:
        warnings.append(f'{d}: odd number of code fences (unclosed block)')
    if name == folder:
        is_profile = folder.endswith('-profile')
        link = (not project) or is_profile or folder in allowed(os.path.dirname(d))
        skills[folder] = {'path': d, 'project': project, 'link': link}

created, repointed, pruned, unlisted, foreign_dead = [], [], [], [], []
for item in sorted(os.listdir(flat)):
    p = os.path.join(flat, item)
    if not os.path.islink(p):
        continue
    target = os.path.join(flat, os.readlink(p))
    target = os.path.normpath(target)
    if not os.path.exists(p):
        if target.startswith(root + os.sep):
            os.unlink(p); pruned.append(item)
        else:
            foreign_dead.append(f'{item} -> {target}')
    elif target.startswith(os.path.join(root, 'Projects') + os.sep) and item in skills and not skills[item]['link']:
        os.unlink(p); unlisted.append(item)

for name, meta in sorted(skills.items()):
    if not meta['link']:
        continue
    p = os.path.join(flat, name)
    if not os.path.lexists(p):
        os.symlink(meta['path'], p); created.append(name)
    elif os.path.islink(p) and os.path.normpath(os.path.join(flat, os.readlink(p))) != meta['path']:
        os.unlink(p); os.symlink(meta['path'], p); repointed.append(name)

held = sorted(n for n, m in skills.items() if not m['link'])
print(f'skills: {len(skills)} (general {sum(not m["project"] for m in skills.values())}, project {sum(m["project"] for m in skills.values())})')
for label, items in [('created', created), ('repointed', repointed), ('pruned dead', pruned),
                     ('unlinked (not allow-listed)', unlisted), ('held out of ~/.claude/skills', held),
                     ('dead links outside registry (untouched)', foreign_dead),
                     ('ERRORS', errors), ('warnings', warnings)]:
    print(f'{label}: {len(items)}')
    for i in items:
        print(f'  - {i}')
```

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

- `find ~/.claude/skills -maxdepth 1 -xtype l` prints only links that point outside `<registry>`.
- Every general skill and every Profile has a link; no project skill outside `.flat-links` does.
- The README counts match the script's counts.
- No `SKILL.md` content changed (`git -C <registry> diff --stat` shows only `README.md`, if anything).
