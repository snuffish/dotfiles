---
name: remember-this
description: "Saves a decision, choice, preference or correction from the current conversation into the host's persistent file memory: splits it into one fact per file, updates instead of duplicating, links related memories and indexes each in MEMORY.md. Use for /remember-this, \"remember this\", \"remember this choice\", \"save this decision\", \"don't forget that\", \"keep this for next time\". Not for resuming work (use /continue) or repo docs."
argument-hint: "[what to remember — defaults to the latest decision in this conversation]"
---

# Skill: `/remember-this` — Persist a Decision to Memory

Turns what the user just settled in this conversation into durable memory files that later sessions recall, without duplicating or contradicting what is already stored.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — the deliverable is memory files

- **Writes only the memory directory** (plus any `core` › *Skill gaps* file). No repo edits, commits or tracker writes.
- **Saving is not approval.** Remembering a choice opens no gate: a pending `/proceed` item, prompt or plan stays waiting (`core` › *The `/proceed` gate*).
- **The host's memory instructions win.** The memory directory, file format, types and index rules come from the host's system prompt (Claude Code: the `# Memory` section). This skill only adds the steps below. If the host names no memory directory, say so and stop.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Resume interrupted work | [`/continue`](../continue/SKILL.md) |
| A rule the whole team should follow | The repo's `CLAUDE.md` / `AGENTS.md`, through a normal change |
| A skill gave wrong instructions | `core` › *Skill gaps* (fix the skill, not a memory) |

---

## 2. Core Protocol & Workflow

### Step 1: Pin down "this"

- With arguments, remember exactly what they name.
- Without, take the most recent thing the user decided, chose, corrected or stated as a preference — including answers to questions you asked and any modifications they attached ("yes, but …").
- Unanswered questions where you gave a recommendation count only if the user accepted them as a group ("yes"); otherwise leave them out.
- If two unrelated candidates fit, ask one multiple-choice question. Otherwise do not ask.
- A point the decision left open is saved as "not decided", never filled in with your guess.

Done when every fact to save is listed, each traceable to a user message in this conversation.

### Step 2: Split into facts

One file per fact, typed by the host's memory types (`user`, `feedback`, `project`, `reference`). A fact is one subject, not one sentence:

- All decisions about one piece of work → one `project` file.
- A rule the user stated that reaches beyond that work (e.g. "never put X in team docs") → its own `feedback` memory, linked from the `project` one.
- Store the decision, not the deliverable: a long prompt, plan or report stays in its file; the memory names its path if it was saved, or says it was not.
- Leave out what the repo already records (code, git history, `CLAUDE.md`) and what only matters to this conversation.
- Never store credentials, tokens, connection strings or other secrets; name where they live instead.

### Step 3: Deduplicate

1. Read the index (`MEMORY.md`) and every memory file whose name or line looks related.
2. For each fact: leave it **unchanged** when an existing file already says it, **update** the existing file that covers it, or **create** a new one. When an existing file contradicts the fact:
   - The new decision is already in effect and changes part of the file → **update** those lines in place.
   - The new decision is already in effect and makes the whole file wrong → **replace** it. Ask one yes/no question naming the file to delete, the `[[links]]` other files hold to it, and a short `project` memory recording what was dropped and when. On yes: delete the file and its index line, remove those links, write the note.
   - The new decision is still pending (planned, gated, not built) → keep the old file, since it still describes today; add a line naming the planned change, and link both ways.

   A decision is in effect unless the user says it is planned for later.

Done when no two memory files hold the same meaning.

### Step 4: Write

Per the host's format, plus:

- `name`: kebab-case slug, unique in the directory; the file name is `<name>.md`.
- `description`: one line that tells a future session when the memory is relevant.
- Body: the fact first; for `feedback` and `project`, then `**Why:**` (quote or paraphrase the user, with the absolute date; when the user only accepted your recommendation, give its reasoning as "accepted recommendation: …") and `**How to apply:**`.
- Dates absolute (`2026-10-28`), never "today" or "last week".
- Link related memories with `[[name]]` both ways: when the other file lacks the reverse link, add that one link to it and change nothing else there.
- On an update, keep any extra frontmatter keys the file already carries (e.g. `modified`, `originSessionId`) and refresh a `modified` timestamp when there is one, from `date -u +%Y-%m-%dT%H:%M:%SZ`.

### Step 5: Index

Add or update one line per memory in `MEMORY.md`: `- [Title](<name>.md) — <hook>`. No memory content in the index.

---

## 3. Output Format & Deliverables

In chat, short:

- One bullet per file: created / updated / deleted / unchanged, its path, and the fact in one line.
- What was deliberately not saved, and why (if anything).
- If a gated step was waiting before this ran, end with the last line of that Command's output, verbatim (e.g. `create-prompt`'s `Next: …` line).

---

## 4. Verification & Validation

Before reporting:

- Each written file exists, parses as frontmatter + body, and its `name` matches its file name.
- `MEMORY.md` has exactly one line per memory file, and none for deleted files; no file still links to a deleted one.
- Every `[[name]]` in a file you wrote either resolves to a file or is a deliberate forward link. Broken links in files you did not touch are reported, not fixed.
