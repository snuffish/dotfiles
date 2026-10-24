---
name: plan-preview
description: Reopens an implementation plan in the host planning preview panel.
disable-model-invocation: true
---

# Skill: `/plan-preview` — Reopen the Planning Preview

Shows an existing plan in the host's planning preview again, so the user can read, comment on and approve it there instead of in a raw markdown file.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — reads one, and writes only the host's own plan file

- The preview is opened by `ExitPlanMode`. It takes no content: it reads the plan file named in the plan-mode system message. Read that path from the system message every time. Never guess it, and never assume `~/.claude/plans/` (the `plansDirectory` setting can move it).
- Copy the plan without changing it. This skill shows the plan. It does not rewrite, summarize or reformat it.
- Never edit source code in this skill. What happens after the preview closes is set by *Step 4*.

---

## 1. When to Use

### When *not* to use

- To get a clickable link to the plan file, or to draft or change a plan, use the [`plan`](../plan/SKILL.md) skill.
- On a host without `ExitPlanMode` (Antigravity IDE, or any host whose tool list lacks it), there is no planning preview. Say so in one line and give the plan's link as [`plan`](../plan/SKILL.md) › *Case A* builds it.

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the plan to show

Take the first source that applies:

1. **Argument.** A path opens that file. A suffix opens the newest member of the workspace-root family `*-implementation_plan-<suffix>*.md` (any host or model prefix, since this only reads it). Order the family by the owner marker as `artifact-protocol` › *Claim* › *Readers* describes. If the argument matches nothing, list the nearest matches and stop.
2. **The session's current plan file.** If this session is in plan mode, or was earlier, and the plan file named in the plan-mode system message still has content, that is the plan whose preview was closed. Reopen it as it is: skip *Step 2*'s copy and go to *Step 3*.
3. **The plan this conversation just produced.** The most recent markdown plan this conversation wrote or linked (a `<prefix>-implementation_plan-<suffix>.md`, or another plan file an agent returned). If the plan exists only as a chat reply, use that reply's text.
4. **The workspace-root plan family.** Scan `<workspace-root>/*-implementation_plan-*.md`. Prefer the family whose suffix matches the current branch or topic (`artifact-protocol` › *Mandatory Contextual Suffix*). If several families still qualify, list them numbered (file, owner marker or modification time, first heading) and let the user pick. If only one qualifies, take it.

If no source yields a plan, say that no plan was found and offer [`plan`](../plan/SKILL.md) to draft one. Stop.

### Step 2: Enter plan mode and load the plan file

1. **Enter plan mode.** If the session is not in plan mode, call `EnterPlanMode`. The user approves the switch. If they decline, stop and give the plan's link instead.
2. **Read the plan-file path** from the plan-mode system message.
3. **Look at the target before writing.** Read the plan file.
   - It is empty, or already holds this plan: go on.
   - It holds a different plan that exists nowhere else (no workspace artifact has the same content): ask before replacing it. The user may want *that* plan previewed instead.
4. **Write the plan into the plan file** exactly as the source has it, with one exception: drop the first line if it is the `<!-- artifact-owner: … -->` marker. The marker identifies the artifact's owner. The host's plan file is not that artifact.

The source artifact is never edited here, whoever owns it.

### Step 3: Open the preview

Call `ExitPlanMode`. The host renders the plan file in its planning preview. In VS Code this is the Plan preview panel; in the terminal it is the plan approval prompt.

### Step 4: Act on the user's choice

The preview returns the user's decision as the `ExitPlanMode` result:

| Choice | What it means | Next action |
|---|---|---|
| **Approve** (any "yes" option) | Explicit approval of this plan (`core` › *Planning mode first*) | Implement the plan. If it came from a Command that owns implementation (`/implement-feature`), resume that Command at its step after plan approval. Before code changes, re-check that the plan's starting state still matches the workspace (branch, files it names). |
| **Keep planning / reject with feedback** | The plan needs changes | Stay in plan mode. Hand the feedback to [`plan`](../plan/SKILL.md) › *Case B*, which follows `artifact-protocol` › *Ownership* (it updates an artifact this session owns, or writes a new one). Then run this skill again on the result. |
| **Closed without choosing / tool error** | Nothing decided | Report it, give the plan's link, and offer to reopen. |

---

## 3. Output Format & Deliverables

No artifact. In chat, after `ExitPlanMode` returns:

```markdown
Opened the planning preview for:

📄 **[<plan-file-name>.md](<plan-file-name>.md)** — <source: argument | current plan file | just produced | newest in family>

<the user's choice and the next action from Step 4>
```

Link the plan's source with the host's link format (`artifact-protocol` › *Host-Specific Link Formats & Section Anchors*), never the host's plan-file path. The source is the file the user keeps. When the plan came from a chat reply, say so instead of linking.

---

## 4. Verification & Validation

- The preview opened only if `ExitPlanMode` returned without error. Never say it is open on any other evidence.
- After *Step 2*, the plan file's body matches the source, apart from the dropped owner marker. Diff the two when the source is a file.
- `git status` shows no change to the source artifact or to any source file.
