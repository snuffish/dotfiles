# Command Skill Template

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
- `../_modules/pr-host.md`   <only if the Command reads a pull request or work item>
- `../_modules/pr-counterpart.md`   <only if the Command resolves a pull request>
- `../_modules/fan-out.md`   <only if the Command spawns parallel sub-agents>
- `../_modules/outward-writes.md`   <only if the Command pushes, posts, or writes to a tracker/PR>

On-demand references (`references/`):
- [`references/<file>.md`](references/<file>.md) — <when to load>

<Command-specific rules, as bullets>

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| <a request that sounds similar but belongs to a neighbour> | [`/<neighbour>`](../<neighbour>/SKILL.md) |

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
