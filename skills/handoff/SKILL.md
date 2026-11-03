---
name: handoff
description: "Prepares a session handoff artifact (<prefix>-handoff-<suffix>.md) capturing goals, current git state, completed work, decisions, and actionable next steps so work can seamlessly continue in a fresh agent session via /proceed <HANDOFF_ARTIFACT.md>. Use for /handoff, \"write a handoff\", \"hand this off\", \"I'll continue in a new session\", or when a session is getting long and work must resume later."
argument-hint: "[suffix | what will the next session be used for]"
---

# Skill: `/handoff` — Session Handoff & Continuity Manager

Compacts the current session into a high-fidelity workspace handoff artifact (`<prefix>-handoff-<suffix>.md`) at the workspace root. Enables any fresh agent session to pick up immediately without losing context or re-doing verified work, by running `/proceed <HANDOFF_ARTIFACT.md>`.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-handoff-<suffix>.md` at the **workspace root**
- `../_modules/git-worktrees.md`: captures active worktree context

---

## 1. When to Use

| Command | Output | Research / Collection Scope | Primary Use |
| :--- | :--- | :--- | :--- |
| **`/handoff [suffix \| focus]`** | `<prefix>-handoff-<suffix>.md` at workspace root + chat link block | Transcript context, git state, modified files, test outputs | Wrapping up a session, switching agents, branching off to a fresh session |

### When *not* to use

| Situation | Use instead |
| --- | --- |
| Resuming interrupted work from past transcripts or memory | [`/continue`](../continue/SKILL.md) |
| Authorizing and executing the pending next steps | [`/proceed`](../proceed/SKILL.md) |
| Storing a single reusable decision or fact permanently across sessions | [`/remember-this`](../remember-this/SKILL.md) |
| Drafting an implementation plan from scratch before writing code | [`/plan`](../plan/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Capture Current State (Read-only)

Gather the concrete facts from the active workspace and conversation history:
1. **Goal & Scope**: the user's original objective, active ticket/work-item ID, PR, or acceptance criteria. If arguments were provided (`/handoff <focus>`), tailor the pending scope to that focus.
2. **Repository & Worktree State**:
   - Run `git status --porcelain` to record modified, added, untracked, or deleted files.
   - Run `git branch --show-current` and `git rev-parse --short HEAD` (commit subject via `git log -1 --oneline`).
   - If in a linked git worktree, capture its path and branch (`git-worktrees` › *Workspace Lifecycle*).
3. **Completed & Verified Work**:
   - List files created or edited in this session with clickable `path:line` links.
   - List verification commands that ran (linters, test suites, build scripts) and their passing status (`✅`).
4. **Key Decisions & Constraints**:
   - Architectural choices made during the session, user-specified constraints, and approaches evaluated and rejected.
   - Pointers to any related artifacts (`<prefix>-*-<suffix>.md`) already created.
5. **Pending Work & Immediate Next Steps**:
   - Numbered, concrete, actionable steps (`1.`, `2.`, `3.`) describing exactly what the next agent session must execute.
   - Avoid vague steps ("finish up"); specify exact target files, functions, or tests.
6. **Suggested Skills**:
   - Name the specific skills the next agent should invoke (e.g. `implement-feature`, `tdd`, `code-review`, `commit`).
7. **Redaction Check**:
   - Never include sensitive tokens, passwords, API keys, or raw secrets.

### Step 2: Derive Artifact Suffix & Claim Artifact

1. **Derive Suffix**:
   - Priority 1: Argument provided by user (e.g. `/handoff auth-flow` → `-auth-flow`).
   - Priority 2: Work item / PR / ticket ID + slug (`-18176-verksamhetsobjekt`).
   - Priority 3: Current branch or feature name (`-user-session-cleanup`).
   - Priority 4: Task descriptor (2–4 words, `-api-contract-refactor`).
2. **Claim File**:
   - Draft the artifact using `artifact-protocol` › *Claim* at:
     `<workspace-root>/<prefix>handoff-<suffix>.md`
   - Ensure the line 1 ownership marker is present:
     `<!-- artifact-owner: <host>-<model> · session <session-id> · created <ISO-8601 timestamp> -->`
   - Publish atomically (`publish_new_artifact` / collision counter `-1`, `-2`, …).

### Step 3: Write the Handoff Document Skeleton

```markdown
<!-- artifact-owner: <host>-<model> · session <session-id> · created <ISO-8601 timestamp> -->

# Handoff: <Descriptive Title>

**Status:** Awaiting /proceed
**Suffix:** `<suffix>`
**Branch:** `<branch>` at `<short-sha>` (<commit-subject>)
**Worktree:** `<path-or-main>`
**Created:** `<ISO-8601 timestamp>`
**Suggested Skills:** `<skill-1>`, `<skill-2>`

---

## 1. Goal & Context
<Original user request, problem statement, and scope boundaries>

## 2. Work Completed & Verified
- <file link>: <what was changed> · verified by `<command>` ✅
- <verification>: <test/lint results>

## 3. Current Git State & Dirty Files
- Branch: `<branch>`
- Commit: `<sha>`
- Modified / Untracked files:
  - `<file-path>` (<status: M/??/A>)

## 4. Key Decisions & Rationale
- **Decision 1**: <rationale and rejected alternatives>
- **Constraints**: <known boundary conditions or rules>

## 5. Next Steps for `/proceed`
1. <First concrete step to execute>
2. <Second concrete step to execute>
3. <Verification command to run>

## 6. Suggested Skills
- `<skill>`: <why and when the fresh session should invoke it>

---

> **Next Step Gate:** In a fresh or current agent session, run:
> `/proceed <artifact-filename>`
> to authorize and execute the next steps listed above.
```

### Step 4: Emit Chat Response

Render the `artifact-protocol` chat link block:

```markdown
📄 [<artifact-filename>](<host-link-to-file>)
- [Goal & Context](<host-link-L1>) · [Work Completed](<host-link-L2>) · [Next Steps](<host-link-L3>)

**Handoff captured.**
- **Completed**: <1-2 bullets on what's done & verified>
- **Pending**: <1-2 bullets on what the next session will execute>
- **Git State**: `<branch>` at `<sha>` (<n> dirty files)

To continue in a fresh agent session, start the session and run:
`/proceed <artifact-filename>`
```

---

## 3. Verification & Validation

- [ ] `<prefix>-handoff-<suffix>.md` is written directly to the workspace root with a valid `artifact-owner` marker and contextual suffix.
- [ ] No code modifications, staging, or outward writes occurred during handoff execution (`core` read-only until `/proceed`).
- [ ] Git state (branch, commit, uncommitted files) is accurately captured without guessing.
- [ ] Next steps are concrete, numbered, and executable by `/proceed`.
- [ ] Sensitive credentials/tokens are completely redacted.
- [ ] Chat link block uses the host's native link format with verified line numbers.
