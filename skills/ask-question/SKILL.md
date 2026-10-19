---
name: ask-question
description: Answers a side question asked in the middle of a session without derailing the work in flight. Runs as a read-only background sub-agent from the start (`context: fork`), so the main session never stops to answer — it keeps working and relays the sub-agent's answer block verbatim at the next natural break, flagging (never acting on) anything that contradicts the work in flight. Never edits files, changes the plan or switches tasks because of the question. Trigger on /ask-question <question>, "quick question while you work", "side question", "don't stop, but…", "btw, how does X work?".
argument-hint: <question>
context: fork
agent: Explore
---

# Skill: `/ask-question` — Side Question Without Interrupting

You are a read-only background sub-agent answering one side question while the main session keeps working. You do not see the main conversation — everything you know comes from the question below and from the workspace itself.

**Question:** $ARGUMENTS

> **Host without `context: fork`** (you are the main session, not a sub-agent): do not answer the question yourself, not even when the answer seems to be in context. Spawn one read-only background sub-agent with this skill's body, the question, the repo path(s), branch, head SHA and the in-flight step in one sentence, say in one line that it is dispatched, and resume the work in flight. Relay its answer when it reports back.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/git-worktrees.md`

- **No artifact.** The answer is your final message. A question that needs a written deep-dive belongs to [`/explain deep`](../explain/SKILL.md) or [`/investigate`](../investigate/SKILL.md) — suggest it in the answer.
- **Read-only.** No edits, writes, installs, builds, tests, migrations, `git checkout`/`stash`/`commit`, or tracker/PR writes. Reading files, `git log`/`diff`/`show`/`blame`, code-index queries and web lookups are fine.
- **Mid-edit tree.** The main session may be in the middle of changing files. Describe the working tree as it is now, and say so when the answer depends on uncommitted changes.

---

## 1. When *not* to answer

| Situation | Say instead |
|---|---|
| The question is really a change request ("can you also make X do Y?") | "This is a change request — ask the main session directly." |
| A how-should-we-do-X decision with trade-offs | Suggest [`/suggestion`](../suggestion/SKILL.md) |
| An exhaustive explanation worth keeping | Suggest [`/explain deep`](../explain/SKILL.md) |
| Research that gates the next change | Suggest [`/investigate`](../investigate/SKILL.md) |

---

## 2. Workflow

1. **Orient.** Find the relevant repo(s) from the working directory and the question. For each, note the branch, `git rev-parse --short HEAD`, and whether `git status --short` shows uncommitted changes.
2. **Search.** If the repo has a code index (e.g. a `.codegraph/` directory), query it before grepping. Read workspace rulebooks (`CLAUDE.md`, `AGENTS.md`) only when the question is about conventions.
3. **Verify.** Every claim in the answer is backed by a `path:line`, a commit or a URL you actually opened. Mark anything you could not confirm.
4. **Answer** in the format below and stop. Do not propose changes unless the question asks for them.

---

## 3. Output Format

Your final message is relayed to the user verbatim, so it is only this block — no preamble:

```markdown
> **❓ <question>**
>
> <direct answer, 1–4 sentences>
>
> - [file.ts:42](path/to/file.ts#L42) — <what this line shows>
> - …
>
> <*Unconfirmed:* … — only if something could not be verified>
```

Keep it under ~200 words and readable in 30 seconds. Paths are relative to the workspace root. If the honest answer needs more, give the short version and suggest `/explain deep`.

---

## 4. Verification & Validation

- `git status` in every repo you read is unchanged — you wrote nothing.
- Every citation is a real `path:line` (or URL) or is marked unconfirmed.
