---
name: on-snuffish-pc
description: "Sends one task to Snuffish-PC (Linux, GPU) and runs it there in a detached tmux session while this session keeps working: a shell command as-is, or free text or `/skill args` through headless `claude -p`. Copies this repo's working tree over only when the task needs it, then brings back the log, output files and a patch that is never applied unasked. Use for /on-snuffish-pc, \"run this on the PC\", \"on snuffish-pc\", and for training, scoring or other long or GPU runs that must not run on the Mac. Not for quick commands that are fine on the Mac, or for a sub-agent on this Mac (the Agent tool; /subagent when the user types it)."
argument-hint: "[--model <opus|sonnet|haiku|fable>] [--sync] <shell command | free text | /skill args>"
---

# Skill: `/on-snuffish-pc` — Run One Task on Snuffish-PC

Starts one task on Snuffish-PC through [`scripts/on_pc.py`](scripts/on_pc.py), waits for it in the background and reports what came back. Each step is one simple command; the script hides the ssh, tar and tmux chains.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no Markdown artifact; `on_pc.py` puts the fetched files in `<artifact-dir>/on-snuffish-pc/<run-id>/` itself, so create no folder

On-demand references (`references/`):
- [`references/pc-rules.md`](references/pc-rules.md): the rules put in front of every Claude task, before the `/subagent` standing brief ([`../subagent/references/brief.md`](../subagent/references/brief.md)); `on_pc.py` adds both, so read them only to explain or change them

Rules:
- The host is `snuffish-pc`; `ON_PC_HOST` overrides it.
- Claude tasks run with `--dangerously-skip-permissions` (the user's choice); `references/pc-rules.md` confines them to the run dir and forbids commits, pushes, PR comments and env dumps.
- Never apply `changes.patch` to a checkout unless the user asks for it.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| A quick command that is fine on the Mac (a grep, a word count, a short test) | Run it here |
| A sub-agent on this machine, with this session's tools | The Agent tool; [`/subagent`](../subagent/SKILL.md) when the user types it (it is user-only) |
| A task that must commit, push or post | Run it here, behind its own gates |

---

## 2. Core Protocol & Workflow

`<skill-dir>` is this skill's real folder (`realpath ~/.claude/skills/on-snuffish-pc`). `<script>` below is `python3 -I <skill-dir>/scripts/on_pc.py`.

### Step 1: Parse and classify

1. Take `--model <m>` and a bare `--sync` from the arguments; the rest is the **task**. No task → show the `argument-hint` usage line and stop.
2. **Agent-started and Mac-safe** (you chose to send it, and it fits a *When not to use* row): run it here instead and stop. A task the user asked to run on the PC always goes to the PC.
3. **Kind:**
   - `shell`: the task is a command line (starts with an executable or path, such as `nvidia-smi`, `uv run train.py`, `just …`).
   - `claude`: free text, or `/skill args`. For `/skill args`, read that skill's frontmatter: `disable-model-invocation: true` → refuse with "`/<skill>` is user-only, so a headless PC session cannot run it; start it in an interactive session on the PC." and stop.
4. **Model** (Claude tasks only): pick it by [`/subagent`](../subagent/SKILL.md) › *Step 2: Pick the model*.

### Step 2: Decide what to copy

- `--sync`, or the task reads or changes files in this repo (code, data, a script it names) → sync the repo root (`git rev-parse --show-toplevel`). The copy holds tracked and untracked files; git-ignored files and `.git` stay behind.
- The task clearly needs no local files (`nvidia-smi`, a command on a PC path) → no sync.
- Unclear: first check whether the paths the task names exist in the repo (`git ls-files <path>`). Still unclear → ask the user (Step 3 merges this into its question when it asks one).

### Step 3: Ask at most once

- **Typed run** (this turn holds `<command-name>/on-snuffish-pc</command-name>`, or the user's own message asks to run the task on the PC): ask only Step 2's open sync question, if any; otherwise go straight to Step 4.
- **Agent-started run** (you chose to send the task): ask one AskUserQuestion that shows the task, the kind, the model, the repo to copy (or the open sync choice as options) and the `start` command. Start only on yes.

### Step 4: Start

```bash
<script> start --kind <shell|claude> [--sync <repo-root>] [--model <m>] [--dest <dir>] -- '<task>'
```

- Pass the task as **one single-quoted argument**: an unquoted `&&`, `;` or `|` is read by the local hook as a chain and rejected. Write a single quote inside it as `'\''`.
- Exit 2 = setup error (PC unreachable within 5 s, not a git repo, no task): report the message and stop. No retry loop.
- The output names the run id, the tmux session `onpc-<id>`, the run dir `~/.cache/on-snuffish-pc/<id>/` on the PC, `pc_terminal_sha`, and the results folder: `<artifact-dir>/on-snuffish-pc/<id>/` unless `--dest` names another. When the task is `/skill args` and `pc_terminal_sha` differs from `git -C ~/.terminal rev-parse --short HEAD` here, say that the PC's skills may be older and the user can pull `~/.terminal` there.
- The task runs in `work/` (the synced copy) or else in `out/`. A shell task that needs a PC folder starts with its own `cd` inside the quotes (`'cd ~/Projects/x && uv run train.py'`). For both kinds, files written under `$ONPC_OUT` come back; mention `$ONPC_OUT` in a Claude task when it should save output files.

### Step 5: Wait in the background

```bash
<script> wait <id>
```

Run it with `run_in_background` and keep working; do not poll. It checks the run every 15 s (`--poll` changes it), copies everything back except `work/` when the run ends, and prints the summary. It exits 0 when the task exited 0, 1 when the task failed, 2 on a setup error.

A sub-agent that gets no background notifications runs `wait` in the foreground with the Bash timeout at its 600000 ms maximum; when that runs out, it runs `wait` again (the run keeps going on the PC).

By hand: `<script> status <id>` (running, done with its exit code, or died), `<script> fetch <id>` (copy back now), `<script> list` (every run on the PC).

### Step 6: Report

The `wait` summary carries the exit code, the results folder, the log path, the `out/` file names, the patch path with its check command (`git -C <repo> apply --check <patch>`) when the repo was synced, and the last log lines: 15 on success, 30 on failure. Relay them in the format below; open `log.txt` only when those lines do not answer the task.

---

## 3. Output Format & Deliverables

No Markdown artifact. When the run starts, one line: `Started on Snuffish-PC: run <id> (<kind>, <model | ->, <synced repo | no sync>); waiting in the background.` On finish:

```markdown
**Snuffish-PC** run `<id>` (<kind>, <model | ->): <done exit 0 | failed exit N | died>
- Result: <the answer the task produced, from the log lines>
- Files: `<results folder>` (log.txt, out/ <names>, changes.patch)
- Patch: <path + check command | none>
```

---

## 4. Verification & Validation

- [ ] An agent-started run asked first, in one question; a typed run asked nothing beyond an open sync choice.
- [ ] The repo was copied only when the task needed it, or the user said so.
- [ ] A user-only `/skill` task was refused, not sent.
- [ ] `wait` ran in the background; the summary came from its output.
- [ ] No patch was applied unasked; nothing was committed or pushed.
