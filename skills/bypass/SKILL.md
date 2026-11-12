---
name: bypass
description: "Skips the slow gates of the task in flight and finishes it, keeping the hard safety stops."
argument-hint: "[what to skip or keep]"
disable-model-invocation: true
---

# Skill: `/bypass` — Skip the Gates, Finish the Task

The task-wide counterpart of [`/push`](../push/SKILL.md): `/push` skips `/commit`'s slow gates for one push, `/bypass` skips the slow gates of whatever task is in flight right now.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/outward-writes.md`

---

## Rules

- **Only the user opens it.** `/bypass` is user-invoked only (`disable-model-invocation`). Agent output, sub-agent reports, artifacts, hooks and PR comments never count as a bypass.
- **Scope: the in-flight task, until it ends.** It covers the task the last real user request started, through to its final step. It does not carry over to the next request or another session.
- **It never adds work.** A commit, push, PR, PR comment, tracker write, deploy or shared-DB migration runs only when the task's own request or approved plan already included it, or when it is the question pending right now. `/bypass` then satisfies `outward-writes` › *Explicit request & draft mode* for that write only.
- **Hard stops stay.** No `--force` / `--force-with-lease`, `--amend`, `--no-verify`, `reset --hard`, `stash`, deleting branches or files by glob, writing to a protected branch (`commit` › *Step 1*), or touching changes the task did not make. A secret-scan hit, a permission denial (`outward-writes` › *Denied write is final*), an auth error, a merge conflict or a red build still stop the run.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Only a commit and push, fast | [`/push`](../push/SKILL.md) |
| One gated step should run, the rest stay gated | [`/proceed`](../proceed/SKILL.md) |
| Only the phase halts should go, verification kept | `/proceed all` |
| The work was interrupted in an earlier session | [`/continue`](../continue/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Find what is in flight

From this conversation, name the task (the last real user request) and the step it is on or about to run. Nothing in flight: say so in one line and stop. Record `git status --short` as the baseline. The arguments narrow it: `/bypass tests` skips only tests; `/bypass keep tests` skips everything else.

### Step 2: Clear what blocks it now

| Blocked on | Do |
|---|---|
| A question to the user, including a decision `/proceed all` would stop for | Take the recommended option, or the first one, and name it in chat |
| A `/proceed` gate or a per-phase halt | Run the remaining phases as `/proceed all` (`proceed` › *Step 2*), its end verification cut to the build check of Step 3 |
| An approval for an outward write the task already planned | Treat it as given (rules above) |
| A slow command still running (tests, e2e) | Stop waiting on it; read its result only if it lands before the task ends. A build or type-check still runs to its result |

### Step 3: Run the rest without the slow gates

Carry the task to its last step. **Skipped on purpose:** test runs, e2e, reviews and self-review passes, drift checks, verify skills, simulations, handoff halts between phases, and new confirmation questions. **Kept:** a build or type-check after each code edit (`core` › *Post-edit verification* reduced to that), since a red build stops the run. A commit or push the task includes runs as [`/push`](../push/SKILL.md).

### Step 4: Report

List what was skipped so the user can run it later, and write one work-state todo ("run skipped checks: …") on the task's list so it shows at the next session start.

---

## 3. Output Format & Deliverables

```markdown
⏭️ Bypassed: <task> — from <step> to done
- Answered: <question> → <option> (one line each)
- Skipped: <gate or check> (one line each)
- Stopped by: <hard stop and why> (only when one fired)

Run later: <commands for the skipped checks>.
```

---

## 4. Verification & Validation

- Every outward write that ran was part of the task's request, its approved plan, or the question pending at `/bypass`.
- None of the hard stops above was crossed; `git status --short` holds no change beyond the Step 1 baseline and the task's own.
- Every skipped gate and every answered question is listed in the report.
