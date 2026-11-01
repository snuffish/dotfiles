---
name: create-prompt
description: "Turns rough intent into a paste-ready prompt invoking the best-fitting skill with real arguments scoped to the git branch or diff. Prints and stops without executing. Use for /create-prompt, 'write a prompt for', or 'turn this into a prompt'. Also invoke automatically when a user request is vague (no clear action, scope, or done-state, e.g. 'clean this up', 'fix the tests', 'make it better') before doing work. For UI generation use /enhance-prompt; for tickets use /create-ticket; for plans use /plan."
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

On-demand references (`references/`):
- [`references/skill-selection.md`](references/skill-selection.md) — candidate selection rules, priority hierarchy, and syntax grounding
- [`references/variants.md`](references/variants.md) — variant axes, generation rules, and multi-prompt output format for `--variants`
- [`references/examples.md`](references/examples.md) — end-to-end prompt generation examples

---

## Gate — print, never run

The deliverable is the prompt. Running it is a separate decision the user makes after reading it.

1. Stop at the printed prompt. Don't invoke the target skill, spawn agents or edit files. The read-only lookups in steps 2–3 are the only commands this skill runs.
2. Only a user message that **starts with** `/proceed` runs the prompt (`/proceed N` picks variant N; a bare `/proceed` runs the recommended one). "Go ahead", "looks good", answering the unresolved questions or "use your recommendations" all mean _refine_, not _run_.
3. Follow-up input refines: apply it, reprint the one prompt block (the chosen or recommended variant) and the `Next:` line, nothing else.

---

## Workflow

### 1. Read the intent

Extract four components from the intent: the **action** (simplify, review, fix, test, document, ship…), **scope** (PR, branch, uncommitted diff, specific path), **stop point** ("before commit" stops before committing), and any explicit **constraints**.

- Scope is almost always resolvable from git; do not ask about it. Ask one multiple-choice question only when the action itself is unclear ("fix it", "make it better" with no context).
- **Started on your own** (user sent a vague request): their message is the intent. Do not perform the work or ask first; the sharper prompt *is* the clarifying question. Open with one line explaining why (`Your request can be read several ways; here is a sharper version.`), put real forks under **Unresolved questions:**, and stop at the gate.

### 2. Pick the skill

Follow [`references/skill-selection.md`](references/skill-selection.md):
1. Shortlist 2–3 candidate skills from your available-skills listing matching the action.
2. Inspect shortlisted `SKILL.md` frontmatter, headings, and options.
3. Apply selection rules: respect authoritative redirections, match primary purpose, prefer project-specific profiles over generic commands, cite reference skills under rules rather than invoking them, and fall back to plain prompts if no skill fits.
4. Ground the exact documented syntax and argument hints.

### 3. Ground the scope (read-only, cheap)

- Query git state: `git branch --show-current`, `git status -s`, and for PRs/branches `git merge-base origin/main HEAD` and `git diff --stat <base>...HEAD`.
- Inject concrete names and ranges into the prompt; use placeholders only when unknowable.
- Resolve user-named areas across the repo (`git ls-files`, `find`).
- For code changes, name the documented verification step (`CLAUDE.md` or a verify skill). For read-only tasks, `Done when` is the deliverable itself.
- Ground boundaries, not pre-audited findings.

### 4. Write the prompt

Aim for at most 6 lines and ~60 words:

```text
/<skill> <args>
Scope: <concrete range or paths>
Goal: <the outcome, one line>
Rules: <1–3 constraints; a reason only where it isn't obvious>
Done when: <verify step>; then stop — <what not to do yet>
```

Drop empty lines. Prune generic advice, politeness, target skill internal instructions, and conventions already covered by `CLAUDE.md`.

### 5. Output

Output only this structure (plus opening rationale if triggered autonomously):

````markdown
**Skill:** `/<skill>` — <why, ≤15 words; name the runner-up if it was close>

```text
<the prompt>
```

**Unresolved questions:** <what I must decide, each with your recommendation. Leave this block out when there are none.>

- <question> — recommend: <answer>

Next: paste it, or `/proceed` to run it here.
````

---

## Options

- **`--variants`**: Generate 2–3 prompt alternatives along distinct axes (Skill, Depth, Plan-first). Use the guidelines and multi-block output format in [`references/variants.md`](references/variants.md).
- **`--file`**: Write the generated prompt output to `<prefix>-prompt-<suffix>.md` at the workspace root and include its link above `Next:`.

See [`references/examples.md`](references/examples.md) for concrete prompt examples.
