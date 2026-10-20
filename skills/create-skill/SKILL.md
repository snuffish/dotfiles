---
name: create-skill
description: Orchestrates, designs, scaffolds, validates, and registers a new Registry entry — a Command, Reference or Profile skill — into the skills registry. Resolves the kind first, enforces naming and gating conventions, wires the Modules a Command depends on, and updates the README inventory. Use on /create-skill or when adding a Command, Reference or Profile to this registry; for evals, benchmarks or description tuning use skill-creator.
---

# Skill: `/create-skill` — Skill Creator & Registry Orchestrator

Systematically designs, scaffolds, validates, and registers new skills in the local skill registry (the parent of this skill's real folder, which holds `_modules/`). Every entry is one of the kinds defined in the repo-root [`GLOSSARY.md`](../../GLOSSARY.md); the kind decides the template.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — the deliverable is the new skill directory

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/create-skill` (with or without arguments).
- The user asks to *"create a new skill"*, *"scaffold a skill"*, *"add a skill for X"*, or *"author a new skill"*.

### When *not* to use

A shared contract that several Commands depend on and that never runs on its own is a **Module**, not a skill. Write it as `skills/_modules/<name>.md` (plain markdown, no frontmatter, never symlinked; see [ADR-0001](../../docs/adr/0001-modules-live-outside-skill-loaders.md) and [ADR-0002](../../docs/adr/0002-module-paths-relative-to-real-skill-folder.md)) and add it to the `## Modules` section of each Command that uses it.

---

## 2. Step-by-Step Creation Workflow

### Step 1 — Kind, Scope & Placement Resolution

**Kind** (ask if the request does not make it obvious):

| Kind | What it is | Gets a `## Modules` section? |
|---|---|---|
| **Command** | Carries out a workflow, invoked by name or by a matching request (`/code-review`, `squash-ef-core-migrations`) | Yes |
| **Reference** | Knowledge the model loads by topic, never run as a workflow (`modern-csharp`, `priis-backend-ef-core`) | No — inherits standards through `core` › *Precedence* |
| **Profile** | Project-specific facts a Command reads to adapt to that project: a base profile (`priis-profile`) plus one Command profile per Command (`implement-feature-priis-profile`, `code-review-priis-profile`) | No |

**Scope.** By default, **skills should be general, universal, and project-agnostic**. They should encapsulate reusable engineering patterns, architectural disciplines, workflows, and tools that function across any codebase, language, or stack.

| Placement | Directory Target | Use Case | Naming Convention |
|---|---|---|---|
| **General (Default / Standard)** | `skills/<name>/` | Universal workflows, architectural patterns, tooling, or disciplines that apply to any project | Single kebab-case name (e.g. `organize`, `code-review`, `expressive`, `problem`) |
| **Project-Scoped (Explicit Request Only)** | `skills/Projects/<Project>/<name>/` | Only when the user explicitly requests rules restricted to a single specific repository/product, and always for a Profile | Prefixed kebab-case: `<project>-<app>-*` (e.g. `priis-backend-*`, `priis-frontend-*`), `<project>-profile`, `<command>-<project>-profile` |

Never place a skill under `skills/_modules/`; that directory holds Modules only and must never contain a `SKILL.md`.

#### Description & Trigger Rules:
- **General Skills (Default)**: Write a crisp, domain-focused `description` detailing the exact trigger conditions, intent, and capabilities. Do NOT bind or gate the description to any specific project.
- **Project-Scoped Skills**: always gated. The description opens with `[Project: <Project>]` and closes with `Load ONLY when working on the <Project> project or in the <workspace> repository.` A skill under `Projects/` that loads everywhere pollutes every other project's sessions.
- **What, then when.** Put the key use case first, then the trigger phrases ("Use for /x, 'phrase', 'phrase'"). The router sees only the description; a "When to Use" list in the body never helps triggering.
- **Name the neighbour.** When another skill overlaps, end with "Not for X (use /y)."
- **Keep it short.** At most 1024 characters (Agent Skills spec). Claude Code truncates at 1,536, and when the shared listing overflows its budget it drops descriptions, least-used skills first.
- **`disable-model-invocation: true`** for a Command only the user should start (e.g. `/proceed`), and `argument-hint` for its arguments. Both are Claude Code keys; Antigravity documents only `name` and `description`, so never make safety depend on them alone.
- **Lean body.** Keep `SKILL.md` to the workflow; move catalogs, templates and long examples into `references/` and link them.

---

### Step 2 — Structure & Architecture Wiring

#### Command template

```markdown
---
name: <exact-directory-name>
description: <what it does, then when to use it (trigger phrases), then "Not for X (use /y)"; ≤1024 chars>
---

# Skill: `/<name>` — <Human-Readable Title>

<1-2 sentences summarizing what this skill does and its primary domain/purpose.>

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`<: read-only until `/proceed` — for research, review and diagnostic Commands>
- `../_modules/artifact-protocol.md`: writes `<prefix>-<artifact_name>-<suffix>.md`   <or: writes no artifact — reason>
- `../_modules/git-worktrees.md`<: snapshot by default | workspace by default — only if the Command reads or edits a repository>
- `../_modules/pr-counterpart.md`   <only if the Command resolves a pull request>

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
- In a skill, Module paths are relative to the skill's real folder: `../_modules/<name>.md` at the top level, `../../../_modules/<name>.md` under `Projects/<Project>/`. Keep the preamble sentence above the list verbatim: the base directory may be the `~/.claude/skills/<name>` symlink, and joining `..` onto it as a string misses `_modules/`, so the paths are resolved through `realpath` ([ADR-0002](../../docs/adr/0002-module-paths-relative-to-real-skill-folder.md)).
- In a Module, references to another Module are relative (`[git-worktrees.md](git-worktrees.md)`). A Module is never symlinked, so it is always read from its real folder.
- A link from one skill to another is relative (`[code-review](../code-review/SKILL.md)`) only when both sit in the same group, both top level or both in the same `Projects/<Project>/`. Across groups, no relative path works through both the registry tree and the flat `~/.claude/skills` loader, so name the skill instead ("the `implement-feature` skill").
- Never write a machine path (`/Users/<name>/…`, `C:\Users\…`). Use `~/…`, a relative link, or a placeholder the skill defines (`<registry>`, `<workspace-root>`).
- Refer to a section inside a Module by name, never by number: `` `git-worktrees` › *Workspace Lifecycle* ``.
- A Command that writes an artifact adds its base name to `artifact-protocol` › *Canonical Artifact Catalog*.

#### Reference and Profile template

Same frontmatter and title, then the content sections directly — no `## Modules` section. A project-scoped description starts with `[Project: <Project>]` and ends with its `Load ONLY when …` gate.

A Profile follows `project-profile` (`skills/_modules/project-profile.md`, [ADR-0003](../../docs/adr/0003-profile-resolution-is-a-module.md)): the project's base profile `<project>-profile` answers the Module's *Shared fields*; a Command profile `<command>-<project>-profile` answers only the fields in that Command's *Project profile* table, points to the base profile by field name, and lists its *Precedence overrides*. Create the base profile first if the project has none. The Command it serves must list `project-profile` in its `## Modules`.

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
   - Verify every relative link to another skill resolves. [`/sync-skills`](../sync-skills/SKILL.md) lints this, the `## Modules` paths and the description length (Step 1).
2. **Symlink / Activation Output**:
   - Present the user with the exact symlink command to activate the new skill in their live flat loader (e.g. Claude Code):
     ```bash
     ln -s "<registry>/<path-to-skill>" ~/.claude/skills/<name>
     ```
     `<registry>` is the parent of this skill's real folder: `dirname "$(realpath <base directory>)"`.
   - Or display the JSON entry for `.agents/skills.json` if using Antigravity / workspace loader.
   - Or run [`/sync-skills`](../sync-skills/SKILL.md), which links general skills and Profiles into the flat loader, keeps project References out unless allow-listed, prunes dead links and refreshes the README inventory in one pass.
   - Claude Code picks up a newly linked skill within the running session; no restart is needed.
