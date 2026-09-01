---
name: create-skill
description: Orchestrates, designs, scaffolds, validates, and registers a new skill into the skills registry. Adheres to the root skill architecture, enforces naming and gating conventions, wires core/artifacts protocols, and updates the README inventory.
---

# Skill: `/create-skill` — Skill Creator & Registry Orchestrator

Systematically designs, scaffolds, validates, and registers new skills in the local skill registry (`~/.terminal/skills`). Enforces adherence to the **[`core`](../core/SKILL.md)** operating standards and the **[`artifacts`](../artifacts/SKILL.md)** protocol.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/create-skill` (with or without arguments).
- The user asks to *"create a new skill"*, *"scaffold a skill"*, *"add a skill for X"*, or *"author a new skill"*.

---

## 2. Step-by-Step Creation Workflow

### Step 1 — Scope & Placement Resolution

Determine where the new skill belongs:

| Placement | Directory Target | Use Case | Naming Convention |
|---|---|---|---|
| **General (Top Level)** | `skills/<name>/` | Tech-stack, tool, or workflow reusable across any project | Single kebab-case name (e.g. `docker`, `rust-best-practices`, `git-bisect`) |
| **Project-Scoped** | `skills/Projects/<Project>/<name>/` | Specific to a single product/repository (e.g. GR.PRIIS) | Prefixed kebab-case (`backend-*`, `frontend-*`, `source-command-*`) |

#### Description & Gating Rules:
- **General Skills**: Write a crisp, unambiguous `description` explaining the exact trigger conditions.
- **Project-Scoped Skills**: MUST include project gating in the `description`:
  - Open with: `[Project: <ProjectName>]`
  - Close with: `Load ONLY when working on the <ProjectName> project or in the <RepoName> repository.`

---

### Step 2 — Structure & Architecture Wiring

Every new `SKILL.md` must follow this standard structure:

```markdown
---
name: <exact-directory-name>
description: <concise trigger description with gating if project-scoped>
---

# Skill: `/<name>` — <Human-Readable Title>

<1-2 sentences summarizing what this skill does and its primary domain/purpose.>

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](<relative-path-to-core>/core/SKILL.md)** operating standards and the **[artifacts](<relative-path-to-artifacts>/artifacts/SKILL.md)** delivery protocol.
<!-- If writing a markdown artifact, declare it here: -->
- **Target Artifact**: `<prefix>-<artifact_name>.md` at the **workspace root**.

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/<name>`.
- [Specific trigger phrase 1]
- [Specific trigger phrase 2]

---

## 2. Core Protocol & Workflow

### Step 1: Context Gathering & Discovery
[Specific instructions on what files, symbols, or history to inspect]

### Step 2: Analysis & Execution
[Specific procedure, rules, and technical conventions]

---

## 3. Output Format & Deliverables

[Structure of chat response and/or workspace markdown artifact]

---

## 4. Verification & Validation

[Instructions on how the agent and user verify the work (tests, builds, commands)]
```

#### Relative Path Rules for Root References:
- Top-level skills (`skills/<name>/`): use `../core/SKILL.md` and `../artifacts/SKILL.md`.
- Project skills (`skills/Projects/<Project>/<name>/`): use `../../core/SKILL.md` and `../../artifacts/SKILL.md`.

---

### Step 3 — File Scaffolding

1. Create the target folder:
   - General: `skills/<name>/`
   - Project: `skills/Projects/<Project>/<name>/`
2. Write `SKILL.md` containing the structured content formulated in Step 2.
3. If the skill requires reference files or templates, place them in a subfolder (e.g. `skills/<name>/references/` or `skills/<name>/templates/`).

---

### Step 4 — Registry Inventory Update

Update [`skills/README.md`](../README.md):
1. Increment total skill count and group count in the summary line and inventory table.
2. Add the new skill name to the appropriate table row in alphabetical order.

---

### Step 5 — Verification & Activation

1. **Verify Integrity**:
   - Ensure the directory name **exactly matches** the `name:` field in frontmatter.
   - Verify all relative markdown links resolve without broken paths.
2. **Symlink / Activation Output**:
   - Present the user with the exact symlink command to activate the new skill in their live flat loader (e.g. Claude Code):
     ```bash
     ln -s ~/.terminal/skills/<path-to-skill> ~/.claude/skills/<name>
     ```
   - Or display the JSON entry for `.agents/skills.json` if using Antigravity / workspace loader.
