---
name: create-prompt
description: "Turns a one-line intent ('DRY and simplify this PR before commit') into one short, paste-ready prompt that invokes the best-fitting skill with its real arguments, scoped to the live branch or diff and ending at a verify-and-stop step; `--variants` adds 2–3 alternatives (other skill, depth or plan-first). Prints and stops; never runs it. Use for /create-prompt, 'write a prompt for', 'make this a better prompt', 'turn this into a prompt', 'improve my prompt'. Also use it on your own when the user's request is vague (no clear action, scope or done-state, e.g. 'clean this up', 'fix the tests', 'make it better') before doing any work. Not for clear, specific requests (just do them), nor for Google Stitch UI prompts (use /enhance-prompt), tickets (use /create-ticket) or implementation plans (use /plan)."
argument-hint: "<what you intend to do> [--variants] [--file]"
---

# Skill: `/create-prompt` — Intent → One Prompt

Takes what the user intends to do and returns the one prompt that gets it done best: the right skill, its exact syntax, the real scope, and a clear stop point. Short enough to read in five seconds.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`, and only a literal `/proceed` opens the gate (_Gate_ below)
- `../_modules/artifact-protocol.md`: writes no artifact by default; with `--file`, writes `<prefix>-prompt-<suffix>.md` at the workspace root

---

## Gate — print, never run

The deliverable is the prompt. Running it is a separate decision the user makes after reading it.

1. Stop at the printed prompt. Don't invoke the target skill, spawn agents or edit files. The read-only lookups in steps 2–3 are the only commands this skill runs.
2. Only a user message that **starts with** `/proceed` runs the prompt (`/proceed N` picks variant N; a bare `/proceed` runs the recommended one). "Go ahead", "looks good", answering the open questions or "use your recommendations" all mean _refine_, not _run_.
3. Follow-up input refines: apply it, reprint the one prompt block (the chosen or recommended variant) and the `Next:` line, nothing else.

---

## Workflow

### 1. Read the intent

Pull out four things from the arguments: the **action** (simplify, review, fix, test, document, ship…), the **scope** (this PR, branch, uncommitted changes, a path), the **stop point** ("before commit" means stop before committing) and any **constraint** the user stated.

Scope is almost always resolvable from git, so don't ask about it. Ask one multiple-choice question only when the action itself is unclear ("fix it", "make it better" with nothing to anchor on).

**Started on your own** (the user sent a vague request, not `/create-prompt`): their message is the intent. Don't do the requested work and don't ask first; the sharper prompt *is* the clarifying question. Open the output with one line saying why (`Your request can be read several ways; here is a sharper version.`), put the real forks under **Open questions**, and stop at the gate like any other run.

### 2. Pick the skill

This decides whether the run succeeds, so spend the effort here rather than on wording.

1. **Candidates** are the skills in your available-skills listing; that is the set the user's session will have (a skill turned off in settings is missing on purpose, even if another skill's text points to it). Shortlist the 2–3 whose descriptions best match the action.
2. **Read each shortlisted `SKILL.md`**: frontmatter, headings, options or flags section. Descriptions summarise; the body tells you what it actually does, what it writes, and its real flags. Built-in skills with no readable file go on their description, or on their name when the listing shows none; say so in the `Skill:` line (with `--variants`, in that variant's header).
3. **Choose by these rules**, in order:
   - A skill's own "Not for X (use /y)" line is authoritative. If it redirects your action elsewhere, follow it.
   - The action is the skill's main job, not something it does on the side.
   - In a project with its own skills, prefer the most specific one that covers the action. If a general Command has a `<command>-<project>-profile`, invoke the Command; it loads the profile itself.
   - Reference skills (conventions, patterns, no workflow) are never the command. Name them in the prompt as rules to apply.
   - Outward actions (commit, push, PR, comments, tracker writes) appear only when the intent asks for them. Otherwise the prompt ends before them.
   - If no skill genuinely fits, write a plain prompt. A forced skill is worse than none.
4. **Use its exact syntax**: argument-hint, modifiers (`deep`, `live`, `--file`), scope phrasing it documents. Never invent a flag.

### 3. Ground the scope (read-only, cheap)

- `git branch --show-current` and `git status -s`. For PR or branch scope, `git merge-base origin/main HEAD` and `git diff --stat <base>...HEAD` to see which top-level areas changed.
- Put real values in the prompt (branch name, base, changed areas). Use a placeholder only when the value can't be known.
- When the user names an area ("the audit endpoint tests"), resolve it by name across the repo (`git ls-files`, `find`), not just the first folder that matches: such files are often spread over several folders.
- When the intent is to change code, find the verify step the project documents (its CLAUDE.md, or a verify skill) and name it. When the intent stops before a fix (review, diagnosis, research), `Done when` is that deliverable (report, root cause, findings), not a verify step.
- Ground boundaries, not findings. Don't pre-audit the diff or list candidate files; the run discovers those.

### 4. Write the prompt

Aim for at most 6 lines and about 60 words:

```text
/<skill> <args>
Scope: <concrete range or paths>
Goal: <the outcome, one line>
Rules: <1–3 constraints; a reason only where it isn't obvious>
Done when: <verify step>; then stop — <what not to do yet>
```

Drop a line that has nothing to say. Then cut every phrase that doesn't change what the run does:

- what the target skill already instructs (it loads its own SKILL.md),
- what the repo's CLAUDE.md already says (the run loads it),
- generic advice ("be thorough", "write clean code", "follow best practices"),
- politeness and preamble.

### 5. Output

Exactly this, nothing before or after (except the one opening line when started on your own):

````markdown
**Skill:** `/<skill>` — <why, ≤15 words; name the runner-up if it was close>

```text
<the prompt>
```

**Open questions** <only if a real fork exists; omit the heading otherwise>

- <question> — recommend: <answer>

Next: paste it, or `/proceed` to run it here.
````

---

## Options

### `--variants`

Print 2–3 prompts instead of one, for when the user wants to choose the approach. Each variant must differ in **what the run does**, along one of these axes:

- **Skill**: the runner-up from step 2, when it was close (e.g. `/simplify` vs `/expressive`).
- **Depth**: a quick pass vs the skill's thorough mode (`deep`, a wider scope, more lenses).
- **Plan-first**: discover and plan, then stop for approval before any edit.

Two variants may share an axis (two candidate skills). Variants that differ only in wording or emphasis are one variant; print fewer rather than pad. Every variant keeps the step 4 shape and line budget. Mark exactly one **(Recommended)**.

Output, replacing step 5's single block:

````markdown
**1. <approach, 2–4 words> (Recommended)**: `/<skill>` — <when to pick it, ≤12 words>

```text
<prompt>
```

**2. <approach, 2–4 words>**: `/<skill>` — <when to pick it>

```text
<prompt>
```

**Open questions** <only if any>

Next: paste one, or `/proceed N` to run it here (bare `/proceed` runs 1).
````

### `--file`

Also write the same content to `<prefix>-prompt-<suffix>.md` and add its link above the `Next:` line.

---

## Example

`/create-prompt I want to DRY and simplify this PR before commit`, on branch `feature/22470_audit-log` in a repo with a backend DRY reference skill and a verify skill, uncommitted backend changes:

````markdown
**Skill:** `/simplify` — its job is reuse and simplification of changed code; `/expressive` only reshapes conditionals.

```text
/simplify
Scope: feature/22470_audit-log vs merge-base origin/main, plus uncommitted changes (backend/ only).
Goal: remove duplication and needless complexity; behaviour unchanged.
Rules: apply priis-backend-dry patterns.
Done when: priis-verify passes; then stop — don't commit.
```

Next: paste it, or `/proceed` to run it here.
````
