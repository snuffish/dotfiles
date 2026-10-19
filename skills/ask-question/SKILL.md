---
name: ask-question
description: Answers a side question asked in the middle of a session without derailing the work in flight. Hands the question to a read-only background sub-agent with a self-contained brief, keeps the main task going, then relays a short, evidence-backed answer when the sub-agent reports back. Answers trivial questions inline from context already in the conversation. Never edits files, changes the plan or switches tasks because of the question. Trigger on /ask-question <question>, "quick question while you work", "side question", "don't stop, but…", "btw, how does X work?".
---

# Skill: `/ask-question` — Side Question Without Interrupting

Answers a question the user asks mid-session while the current work keeps going. The question is researched by a read-only background sub-agent so the main thread keeps its focus and its context window; the answer comes back as a short, clearly marked block, and the main task picks up where it was.

---

## Modules

Read these before step 1:
- `~/.terminal/skills/_modules/core.md`: read-only until `/proceed`
- `~/.terminal/skills/_modules/artifact-protocol.md`: writes no artifact — the answer lives in chat
- `~/.terminal/skills/_modules/git-worktrees.md`

- **No artifact.** The answer lives in chat. A question that needs a written deep-dive belongs to [`/explain deep`](../explain/SKILL.md) or [`/investigate`](../investigate/SKILL.md) — suggest it, do not switch silently.
- **Read-only, for you and the sub-agent.** No edits, writes, installs, builds, tests, migrations, `git checkout`/`stash`/`commit`, or tracker/PR writes. Reading files, `git log`/`diff`/`show`/`blame`, code-index queries and web lookups are fine.
- **The main task is not disturbed.** The question never changes the plan, the todo list, the branch, the files being edited or the order of work. If the answer reveals a problem with the work in flight, flag it and ask — never pivot on your own.
- **Worktree invariant applies.** If a `git-worktrees` worktree is active, hand its `[worktree-context]` block to the sub-agent so it reads the right tree.

---

## 1. When to Use

Invoke this skill whenever:

- The user runs `/ask-question <question>`.
- The user asks something unrelated to (or adjacent to) the current step and signals they do not want the work to stop: "quick question while you work", "side question", "don't stop, but…", "btw…".

### When *not* to use

| Situation | Use instead |
|---|---|
| The question is really a change request ("can you also make X do Y?") | Treat it as a new instruction for the main task — confirm scope first |
| A how-should-we-do-X decision with trade-offs | [`/suggestion`](../suggestion/SKILL.md) |
| An exhaustive explanation worth keeping | [`/explain deep`](../explain/SKILL.md) |
| Research that gates the next change | [`/investigate`](../investigate/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Triage — inline or delegated

Answer **inline**, without a sub-agent, when the answer is already in the conversation (a file you read, a command output, a decision the user made) and fits in a few sentences with no new tool calls. Delegation costs a cold start; do not pay it for "what was the name of that file again?".

Everything else is **delegated**: anything that needs reading code, history, docs or the web.

### Step 2: Write a self-contained brief

The sub-agent sees nothing of this conversation. Its prompt must carry everything it needs:

- **The question**, verbatim.
- **Where to look**: absolute repo path(s), current branch and head SHA (`git -C <repo> rev-parse --short HEAD`), and whether the tree has uncommitted changes — say that the working tree is mid-edit, so answers describe the in-progress state, not `main`.
- **What is in flight**, in one sentence, and the files and symbols already known to be relevant (`path:line`). This saves the sub-agent from re-discovering them.
- **Decisions already made** in the conversation that bear on the question.
- **The workspace's code-search tooling**: if the repo has a code index (e.g. a `.codegraph/` directory), tell the sub-agent to query it before grepping.
- **The contract**: "Read-only — do not edit, write, build, test, install or run git commands that change state. Answer in at most ~200 words: the direct answer first, then 1–5 `path:line` (or URL) citations, then anything you could not confirm. Do not propose changes unless the question asks for them."

### Step 3: Dispatch in the background and carry on

- Spawn **one** sub-agent per question, in the background, using a read-only research agent type where the host offers one (e.g. Claude Code's `Explore`; `general-purpose` only when the question needs the web or a tool `Explore` lacks).
- Several questions at once → one sub-agent each, all spawned in the same message.
- Tell the user in one line that the question is dispatched and what you are continuing with, then **resume the in-flight work immediately**. If nothing was in flight, just wait for the result.
- Never poll, sleep or predict the answer while waiting. The host notifies you when the sub-agent finishes.

### Step 4: Relay the answer

When the sub-agent reports back:

1. **Spot-check** one cited `path:line` if the answer will drive a decision. Sub-agent output is evidence, not a verdict; mark anything you could not confirm.
2. **Relay** it in the format below, at the next natural break in the main work (between tool calls, not in the middle of a multi-file edit).
3. **Flag, don't act**, if the answer contradicts something the main task assumes ("this means the migration I'm writing targets the wrong table — want me to adjust?").
4. **Resume** the main task.

Follow-ups on the same question go to the **same** sub-agent (e.g. `SendMessage` in Claude Code) so it keeps its context; a new question gets a fresh one.

---

## 3. Output Format & Deliverables

On dispatch (one line):

> ❓ Looking into *"<question, shortened>"* in the background — continuing with *current step*.

On answer:

```markdown
> **❓ <question>**
>
> <direct answer, 1–4 sentences>
>
> - [file.ts:42](path/to/file.ts#L42) — <what this line shows>
> - …
>
> <*Unconfirmed:* … — only if something could not be verified>

↩ Back to <current step>.
```

Keep it readable in 30 seconds. If the honest answer needs more than ~200 words, give the short version and offer `/explain deep`.

---

## 4. Verification & Validation

- `git status` in every repo touched is unchanged by the question — the sub-agent wrote nothing.
- The main task's next step is the same one it was before the question arrived.
- Every citation in the relayed answer is a real `path:line` (spot-checked when it matters) or is marked unconfirmed.
