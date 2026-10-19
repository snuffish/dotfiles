---
name: create-skill
description: Orchestrates, designs, scaffolds, validates, and registers a new Registry entry — a Command, Reference or Profile skill — into the skills registry. Resolves the kind first, enforces naming and gating conventions, wires the Modules a Command depends on, and updates the README inventory.
---

# Skill: `/create-skill` — Skill Creator & Registry Orchestrator

Systematically designs, scaffolds, validates, and registers new skills in the local skill registry (`~/.terminal/skills`). Every entry is one of the kinds defined in `~/.terminal/GLOSSARY.md`; the kind decides the template.

---

## Modules

Read these before step 1:
- `~/.terminal/skills/_modules/core.md`
- `~/.terminal/skills/_modules/artifact-protocol.md`: writes no artifact — the deliverable is the new skill directory

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/create-skill` (with or without arguments).
- The user asks to *"create a new skill"*, *"scaffold a skill"*, *"add a skill for X"*, or *"author a new skill"*.

### When *not* to use

A shared contract that several Commands depend on and that never runs on its own is a **Module**, not a skill. Write it as `skills/_modules/<name>.md` (plain markdown, no frontmatter, never symlinked; see `~/.terminal/docs/adr/0001-modules-live-outside-skill-loaders.md`) and add it to the `## Modules` section of each Command that uses it.

---

## 2. Step-by-Step Creation Workflow

### Step 1 — Kind, Scope & Placement Resolution

**Kind** (ask if the request does not make it obvious):

| Kind | What it is | Gets a `## Modules` section? |
|---|---|---|
| **Command** | Carries out a workflow, invoked by name or by a matching request (`/code-review`, `squash-ef-core-migrations`) | Yes |
| **Reference** | Knowledge the model loads by topic, never run as a workflow (`modern-csharp`, `backend-ef-core`) | No — inherits standards through `core` › *Precedence* |
| **Profile** | Project-specific facts one Command reads to adapt to that project (`implement-feature-priis-profile`) | No |

**Scope.** By default, **skills should be general, universal, and project-agnostic**. They should encapsulate reusable engineering patterns, architectural disciplines, workflows, and tools that function across any codebase, language, or stack.

| Placement | Directory Target | Use Case | Naming Convention |
|---|---|---|---|
| **General (Default / Standard)** | `skills/<name>/` | Universal workflows, architectural patterns, tooling, or disciplines that apply to any project | Single kebab-case name (e.g. `organize`, `code-review`, `expressive`, `problem`) |
| **Project-Scoped (Explicit Request Only)** | `skills/Projects/<Project>/<name>/` | Only when the user explicitly requests rules restricted to a single specific repository/product, and always for a Profile | Prefixed kebab-case (`backend-*`, `frontend-*`, `source-command-*`, `implement-feature-<project>-profile`) |

Never place a skill under `skills/_modules/`; that directory holds Modules only and must never contain a `SKILL.md`.

#### Description & Trigger Rules:
- **General Skills (Default)**: Write a crisp, domain-focused `description` detailing the exact trigger conditions, intent, and capabilities. Do NOT bind or gate the description to any specific project.
- **Project-Scoped Skills**: Only use project gating if the user explicitly demands product-specific isolation. Otherwise, write universal descriptions that allow the skill to be leveraged everywhere.

---

### Step 2 — Structure & Architecture Wiring

#### Command template

```markdown
---
name: <exact-directory-name>
description: <concise, universal trigger description and domain capabilities>
---

# Skill: `/<name>` — <Human-Readable Title>

<1-2 sentences summarizing what this skill does and its primary domain/purpose.>

---

## Modules

Read these before step 1:
- `~/.terminal/skills/_modules/core.md`<: read-only until `/proceed` — for research, review and diagnostic Commands>
- `~/.terminal/skills/_modules/artifact-protocol.md`: writes `<prefix>-<artifact_name>-<suffix>.md`   <or: writes no artifact — reason>
- `~/.terminal/skills/_modules/git-worktrees.md`<: snapshot by default | workspace by default — only if the Command reads or edits a repository>
- `~/.terminal/skills/_modules/pr-counterpart.md`   <only if the Command resolves a pull request>

<Command-specific rules, as bullets>

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

#### Module wiring rules:
- List only the Modules the Command uses directly; a Module's own `## Modules` section pulls in what it needs.
- Paths are always absolute (`~/.terminal/skills/_modules/<name>.md`). A relative link breaks when the skill is read through its `~/.claude/skills/<name>` symlink.
- Refer to a section inside a Module by name, never by number: `` `git-worktrees` › *Workspace Lifecycle* ``.
- A Command that writes an artifact adds its base name to `artifact-protocol` › *Canonical Artifact Catalog*.

#### Reference and Profile template

Same frontmatter and title, then the content sections directly — no `## Modules` section. A project-scoped description starts with `[Project: <Project>]` and ends with its `Load ONLY when …` gate.

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
2. Add the new skill name to the row for its kind and placement, in alphabetical order.

---

### Step 5 — Verification & Activation

1. **Verify Integrity**:
   - Ensure the directory name **exactly matches** the `name:` field in frontmatter.
   - Verify every `## Modules` path exists and every relative link to another skill resolves.
2. **Symlink / Activation Output**:
   - Present the user with the exact symlink command to activate the new skill in their live flat loader (e.g. Claude Code):
     ```bash
     ln -s ~/.terminal/skills/<path-to-skill> ~/.claude/skills/<name>
     ```
   - Or display the JSON entry for `.agents/skills.json` if using Antigravity / workspace loader.
   - Or run [`/reload-skills`](../reload-skills/SKILL.md), which symlinks every registry skill into the flat loader, prunes dead links and refreshes the README inventory in one pass.
