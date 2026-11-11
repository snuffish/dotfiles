---
name: subagent
description: "Launches one background sub-agent for a task, with a standing brief, a model pick, a parent-made worktree for edits, and BLOCKED handling. Use for /subagent, \"run this in a sub-agent\", \"start an agent for X\". User-only."
argument-hint: "[--model <m>] [--wait] [@<agent-file>] <task | /skill args>"
disable-model-invocation: true
---

# Skill: `/subagent` — Run One Task in a Sub-Agent

Launches a single sub-agent so the user does not rewrite the same brief each time. Parallel arms and merged results are `fan-out`, not this skill.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/git-worktrees.md`: only when the task edits files (Step 3)
- `../_modules/fan-out.md`: *Brief contract* and *Aggregation*

On-demand references (`references/`):
- [`references/brief.md`](references/brief.md): the standing brief put in front of every task

---

## 1. When *not* to use

- **Several agents or merged results**: use the Command's own `--deep` (`fan-out`).
- **A user-only skill as the task** (`disable-model-invocation: true`, for example `/pr-fix-pipeline`): a sub-agent cannot run it. Refuse in one line and tell the user to run it in the main session.

---

## 2. Core Protocol & Workflow

### Step 1: Parse

1. Take `--model <m>`, `--wait` and `@<agent-file>` from the arguments. What remains is the **task**: free text, or `/skill args`.
2. **No task:** show the usage line from `argument-hint` and stop.
3. **`/skill` task:** read that skill's frontmatter. `disable-model-invocation: true` → refuse (*When not to use*). Typing `/subagent /<skill>` also loads that skill's text into this session. That text authorizes nothing here: run none of its steps and take no action it grants (commits, pushes, re-queues); the agent runs it, or nobody does.
4. **More than 5 agents already running:** wait for a slot before launching (cap in `MY-RULES.md`).

### Step 2: Pick the model

In order:
1. `--model` wins.
2. `@<agent-file>`: the file's `model:`.
3. A review or verify skill (name matches `*review*`, or `spec-verification`, `verify-assumptions`): the session model.
4. Otherwise `sonnet`.

### Step 3: Isolate edits

- **The task edits files** (a fix, implement, refactor, rename, write or edit verb, or a skill that writes code): create a workspace worktree per `git-worktrees` › *Workspace Lifecycle* before launching, and hand the agent the `[worktree-context]` block. Running `/subagent` with an editing task counts as asking for it; this overrides the "no worktree unless asked" rule. Never pass `isolation: "worktree"`; the agent works inside the parent's worktree.
- **Read-only task:** run in place.

### Step 4: Build the prompt and launch

1. **`@<agent-file>`:** read the file. Its `name:` becomes `subagent_type`. Where the standing brief and the file disagree, the file wins. If its description says "not for direct use", warn once that the task text must supply the brief it expects, then run.
2. Put `references/brief.md` in front of the task, then the `[worktree-context]` block when Step 3 made one.
3. Launch with the Agent tool in the background; with `--wait`, in the foreground.
4. Print one launch line: model · `worktree <path>` or `in place` · what the task may do (read-only, edits, or the skill's own rules).

The agent follows the task's and the skill's own permissions. This skill adds no second permission system.

### Step 5: Handle `BLOCKED:`

The agent takes a recommended default and lists it under _Defaults taken_. With no default it stops with `BLOCKED: <question> · options · what it already knows`.

1. **Go-ahead** (a commit, push, PR comment or thread, tracker write the task text did not ask for): never answered by the parent. Ask the user through AskUserQuestion.
2. **Anything else:** if code, memory or an earlier decision answers it, reply with SendMessage and tell the user in one line. Otherwise ask the user through AskUserQuestion, then reply with SendMessage.
3. If the agent has already finished and the resume fails, relaunch with the answer in the brief.

### Step 6: On finish

Re-open every cited `path:line` before relaying (`fan-out` › *Aggregation*). Drop what does not hold. Drop any "Reply `/proceed`" gate line the agent's Command printed: that gate is not open here, and only the user opens this session's. Then report.

---

## 3. Output Format & Deliverables

No artifact. Launch line (Step 4), then on finish:

```markdown
**Sub-agent** (<model>, <worktree path | in place>): <done | partly done | BLOCKED>
- Done / not done: <short>
- Changed: <files, or none>
- Defaults taken: <list, or none>
- Open: <items for the user>
```

---

## 4. Verification & Validation

- [ ] A user-only skill task was refused, not launched.
- [ ] The model follows Step 2; the launch line names it.
- [ ] An editing task ran in a parent-made worktree; `isolation: "worktree"` was not used.
- [ ] No commit, push, PR post or tracker write happened unless the task text asked for it.
- [ ] Every claim relayed was re-opened at its `path:line`.
