---
name: reload-skills
description: Scans, discovers, validates, and synchronizes all skills across the local skills registry (~/.terminal/skills). Reconciles missing flat-loader symlinks in ~/.claude/skills, checks workspace .agents/skills.json configurations, prunes broken symlinks, updates the registry README inventory, and refreshes active agent awareness of newly authored skills. Trigger on /reload-skills, "reload skills", "sync skills", "refresh skills", "load new skills", "rescan skills".
---

# Skill: `/reload-skills` — Skill Registry Scanner & Live Loader Synchronizer

Systematically scans the local skill registry (`~/.terminal/skills`), audits all discovered skill directories for specification compliance, synchronizes flat symlinks into live loader directories (`~/.claude/skills`), verifies workspace registration (`.agents/skills.json` and `.agents/AGENTS.md`), updates registry inventories, and immediately hydrates the current session with complete awareness of newly authored skills.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.

- **Target Artifact** (when requested or reporting major registry audits): `<prefix>-skills_sync_report[-<suffix>].md` at the **workspace root**.
- **Anti-Overwrite Rule**: When generating multiple or targeted sync reports, append a descriptive kebab-case `<suffix>` (e.g. `-full-audit`, `-broken-links`).
- For regular synchronizations, execute atomic link/inventory updates directly and output a structured discovery summary in the chat response.

---

## ⛔ Golden Invariants

> [!CAUTION]
> **ABSOLUTE RULES — REGISTRY INTEGRITY & SAFE LINKING:**
>
> 1. **ZERO DRIFT BETWEEN REPOSITORY & FLAT LOADERS.**
>    Every valid skill directory in `~/.terminal/skills/` (top-level general or `Projects/<Project>/`) must have an active, matching symlink in `~/.claude/skills/<name>`.
> 2. **STRICT SPECIFICATION VALIDATION BEFORE PROMOTION.**
>    A directory is only considered a valid skill if it contains a `SKILL.md` with valid YAML frontmatter containing `name` and `description`. The directory name must **identically match** the `name:` frontmatter attribute.
> 3. **SAFE PRUNING (NEVER PURGE UNRELATED LOADERS).**
>    When pruning dead symlinks in `~/.claude/skills/`, only remove links that point to deleted or moved targets within `~/.terminal/skills/`. Never delete standalone directories or links pointing to workspace-specific skill bundles (e.g. `../../.agents/skills/*`).
> 4. **NON-DESTRUCTIVE EXECUTION.**
>    Never modify or overwrite the instruction contents of existing `SKILL.md` files during a scan.
> 5. **IMMEDIATE SESSION HYDRATION.**
>    Once new skills are discovered and linked, the agent must immediately index their paths, names, and trigger descriptions in the current turn so the user can use them right away without restarting the agent or IDE.

---

## 1. When to Use

Invoke this skill whenever:

- The user runs `/reload-skills` (or `/sync-skills`, `/refresh-skills`).
- The user states:
  - *"reload skills"*
  - *"refresh my skills"*
  - *"rescan skills repository"*
  - *"load newly created skills"*
  - *"my new skill is not recognized"*
- Immediately after creating one or more new skills via `/create-skill` or manual authoring.
- When switching branches or pulling changes in `~/.terminal/skills` that introduced or removed skills.

---

## 2. Loader Ecosystem & Synchronization Architecture

Different AI tools discover skills using different paradigms:

```
                      ~/.terminal/skills/ (Source of Truth)
                      ├── <general-skills>/SKILL.md
                      └── Projects/<Project>/<skill>/SKILL.md
                                      │
               ┌──────────────────────┴──────────────────────┐
               ▼                                             ▼
     Flat Symlink Loader                         Workspace Loader
      (~/.claude/skills/)                     (.agents/skills.json)
               │                                             │
      Used by: Claude Code                         Used by: Antigravity IDE
 (Requires 1 flat symlink per skill)         (Resolves directory entry trees)
```

1. **Flat Symlink Loader (`~/.claude/skills/`)**:
   Requires a flat directory where each entry is a direct child symlink (or folder) pointing to the skill directory containing `SKILL.md`. Subdirectories like `Projects/` are not traversed recursively by flat loaders; every nested skill must be symlinked directly by its unique name.
2. **Workspace Tree Loader (`.agents/skills.json`)**:
   Used by Antigravity IDE. It declares root paths to scan (e.g. `/Users/snuffish/.terminal/skills` and `/Users/snuffish/.terminal/skills/Projects/GR.PRIIS`). If a new project directory is created under `Projects/`, it must be registered here.
3. **Active Session Awareness**:
   If an agent began its conversation before a new skill was created on disk, it may not have that skill in its initial system prompt. Running `/reload-skills` actively inspects and reads the new skill specifications into the current context so the agent can execute them immediately.

---

## 3. Step-by-Step Synchronization Protocol

### Step 1: Discover & Catalog Local Skills

Scan `/Users/snuffish/.terminal/skills` (or `~/.terminal/skills`) recursively for all files named `SKILL.md`.

Categorize each discovered skill:
- **General (top-level)**: Direct children of `skills/` (e.g. `skills/clean/SKILL.md`).
- **Project-Scoped**: Nested under `skills/Projects/<Project>/` (e.g. `skills/Projects/GR.PRIIS/backend-ef-core/SKILL.md`).

For each skill, extract:
- `name`: Value from YAML frontmatter.
- `description`: Value from YAML frontmatter.
- `path`: Absolute directory path.
- `relative_path`: Path relative to `~/.terminal/skills`.

### Step 2: Validate Compliance & Integrity

Enforce the following quality checks on each skill:
1. **Name Alignment**: Confirm `name:` in `SKILL.md` exactly matches the enclosing directory name.
2. **Core Link Integrity**: Verify relative links to foundational skills:
   - Top-level skills must reference `../core/SKILL.md` and `../artifacts/SKILL.md`.
   - Project-scoped skills must reference `../../core/SKILL.md` and `../../artifacts/SKILL.md`.
3. **Trigger Description**: Ensure `description` is non-empty and contains actionable trigger phrases.

Flag any warnings or errors for resolution.

### Step 3: Synchronize Flat Loader Symlinks (`~/.claude/skills/`)

Ensure `~/.claude/skills` directory exists:
```bash
mkdir -p ~/.claude/skills
```

Audit and reconcile symlinks:
1. **Add Missing Links**: For every valid skill discovered in `~/.terminal/skills`:
   - If `~/.claude/skills/<name>` does not exist, create the symlink:
     ```bash
     ln -sfn "<absolute_path>" ~/.claude/skills/<name>
     ```
   - If it points to an incorrect or stale path, update the symlink.
2. **Prune Dangling Links**: Inspect all symlinks in `~/.claude/skills/`:
   - If a link points into `~/.terminal/skills/` but its target directory or `SKILL.md` no longer exists, prune it:
     ```bash
     rm ~/.claude/skills/<broken_link_name>
     ```
   - **Protection Rule**: Never delete symlinks or folders pointing outside `~/.terminal/skills/` (such as `.agents/skills/*`).

### Step 4: Synchronize Workspace Configurations

1. **Audit `.agents/skills.json`**:
   - Inspect the active workspace's `.agents/skills.json`.
   - Verify that all project folders under `~/.terminal/skills/Projects/*` (e.g. `Projects/GR.PRIIS`) are included in `"entries"`. If a new project folder was created, append it to `"entries"`.
2. **Audit Workspace Playbook (`.agents/AGENTS.md`)**:
   - If working in a repository with `.agents/AGENTS.md`, check that newly introduced general or project-scoped skills are documented under the corresponding section with a clickable markdown link.

### Step 5: Synchronize Registry Inventory (`~/.terminal/skills/README.md`)

Audit the master inventory in `~/.terminal/skills/README.md`:
1. Calculate the total skill count and group counts:
   - Total count
   - General (top level) count
   - Each `Projects/<Project>/<prefix>` count
2. Update the summary text: `<total> skills total — <general> general + <project> under Projects/...`.
3. Verify that all skills are listed in alphabetical order in the Markdown inventory table.

### Step 6: Git Status Audit

Check git status in the skills repository:
```bash
git -C ~/.terminal/skills status -s
```
Alert the user if any new or modified skills remain uncommitted or untracked.

### Step 7: Immediate Context Hydration

In the agent's turn response:
- Output the full list of newly synchronized or updated skills.
- List their triggers and primary capabilities.
- Confirm that the current agent session is now actively aware of all discovered skills and ready to execute them immediately.

---

## 4. Deterministic Synchronization Script

To execute Steps 1–3 in a single reliable operation, run the following Python script:

```python
import os
import re

skills_root = os.path.expanduser('~/.terminal/skills')
claude_dir = os.path.expanduser('~/.claude/skills')
os.makedirs(claude_dir, exist_ok=True)

# 1. Discover all skills with valid SKILL.md
discovered_skills = {}
validation_errors = []

for root, dirs, files in os.walk(skills_root):
    if 'SKILL.md' in files:
        dir_name = os.path.basename(root)
        skill_file = os.path.join(root, 'SKILL.md')
        try:
            with open(skill_file, 'r', encoding='utf-8') as f:
                content = f.read()
            match_name = re.search(r'^name:\s*([^\r\n]+)', content, re.MULTILINE)
            name = match_name.group(1).strip() if match_name else None
            match_desc = re.search(r'^description:\s*([^\r\n]+)', content, re.MULTILINE)
            desc = match_desc.group(1).strip() if match_desc else ''
            
            if not name:
                validation_errors.append(f"{root}: Missing 'name' in frontmatter.")
            elif name != dir_name:
                validation_errors.append(f"{root}: Directory '{dir_name}' does not match frontmatter name '{name}'.")
            else:
                discovered_skills[name] = {
                    'path': root,
                    'description': desc,
                    'is_general': os.path.dirname(root) == skills_root,
                }
        except Exception as e:
            validation_errors.append(f"{root}: Error reading SKILL.md: {e}")

# 2. Reconcile symlinks in ~/.claude/skills
created_links = []
updated_links = []
pruned_links = []

# Check existing entries in claude_dir
for item in os.listdir(claude_dir):
    item_path = os.path.join(claude_dir, item)
    if os.path.islink(item_path):
        target = os.readlink(item_path)
        abs_target = os.path.abspath(os.path.join(claude_dir, target)) if not os.path.isabs(target) else target
        if abs_target.startswith(skills_root):
            if not os.path.exists(abs_target) or not os.path.exists(os.path.join(abs_target, 'SKILL.md')):
                os.unlink(item_path)
                pruned_links.append(item)

# Ensure every discovered skill has a valid symlink
for name, meta in discovered_skills.items():
    link_path = os.path.join(claude_dir, name)
    expected_target = meta['path']
    if not os.path.lexists(link_path):
        os.symlink(expected_target, link_path)
        created_links.append(name)
    elif os.path.islink(link_path):
        current_target = os.readlink(link_path)
        if current_target != expected_target:
            os.unlink(link_path)
            os.symlink(expected_target, link_path)
            updated_links.append(name)

print(f"Total skills discovered: {len(discovered_skills)}")
print(f"Created symlinks: {created_links}")
print(f"Updated symlinks: {updated_links}")
print(f"Pruned dead links: {pruned_links}")
if validation_errors:
    print(f"Validation warnings/errors: {validation_errors}")
```

---

## 5. Output Format & Deliverables

Always return a structured, transparent summary of the sync operation:

```markdown
### 🔄 Skills Registry & Loader Synchronization Summary

#### 📊 Registry Inventory:
- **Total Skills Recognized**: `<N>`
  - **General (Top Level)**: `<N_gen>`
  - **Project-Scoped (`Projects/GR.PRIIS`)**: `<N_proj>`

#### 🔗 Loader Symlinks (`~/.claude/skills`):
- **Newly Linked**:
  - [`<name>`](file:///Users/snuffish/.terminal/skills/<path>): `<Trigger / summary>`
- **Updated / Repointed**: None (or list of updated links)
- **Pruned Dead Links**: None (or list of removed dangling links)

#### ⚙️ Workspace & Documentation Status:
- **`.agents/skills.json`**: Verified (all active project paths present)
- **`.agents/AGENTS.md`**: Synchronized (or up to date)
- **`~/.terminal/skills/README.md`**: Master inventory count updated to `<N>`
- **Git Status (`~/.terminal/skills`)**: Clean (or list untracked/modified skills)

#### 🚀 Active Session Hydration:
The current conversation has dynamically loaded and indexed all `<N>` skills. You can trigger newly added skills immediately (e.g. `/<new-skill-name>`).
```

---

## 6. Verification Checklist

Before reporting completion to the user, ensure:

- [ ] Every directory in `~/.terminal/skills` containing a `SKILL.md` was scanned and validated.
- [ ] No `name` vs folder mismatch was ignored.
- [ ] Every valid skill has an active symlink in `~/.claude/skills/`.
- [ ] No external workspace links in `~/.claude/skills/` were accidentally unlinked.
- [ ] Inventory counts in `~/.terminal/skills/README.md` reflect the exact on-disk state.
- [ ] All new skills are exposed with actionable trigger instructions in the chat response.
