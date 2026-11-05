# PR Comment Formats & Draft Preview

On-demand reference for [SKILL.md](../SKILL.md) › *Step 4 — Turn each item into a PR comment* and *3. Output Format & Deliverables*.

---

## Minor-Findings Block (`kind: "general"`)

The artifact's *🟢 Minor Findings* list becomes **one general comment per PR** (no file anchor) so it reads as a single non-blocking note rather than a dozen threads to resolve. Omit when the artifact has no 🟢 items for that PR or when the PR already has a live minor-findings comment.

- **Title**: `**🟢 Minor findings (non-blocking)**`
- **Scope**: only that PR's items (in a multi-repo review, split by the repo each item cites; cross-repo contract notes go on the PR that owns the contract).
- **Format**: one bullet per item — `` `File.cs:123`: <claim>. `` Resolved findings become a leading `**✅ <what was checked>: <result>.**` bullet.
- **Expand compressed tails**: if the artifact ends with `"+N more of the same kind: …"`, expand them under a short *Smaller still:* sub-list.
- **Paths**: repo-relative `File.cs:123` only; no absolute-path prefixes, local artifact links, or finding numbers.

---

## Draft Preview Format (`draft` mode)

Open with one table row per item so the user can pick keys at a glance, then show each item: its anchored code, then its body verbatim as it will be posted. Group per PR:

````markdown
**Draft — nothing posted yet.** <Repo> !<id> "<PR title>" · iteration <n> · `<short-sha>`

| Key | Kind | Severity · title | Anchor | After posting |
|---|---|---|---|---|
| 1 | new thread | 🟡 <title> | `<path>:<start>-<end>` | active |
| r1 | reply to #<threadId> | — | `<thread's path>:<line>` | resolved / active: <reason> |
| g1 | general | 🟢 Minor findings (<n>) | — | active |

---

#### 1 · new thread · `<path>:<start>-<end>`

```<lang>
<start> │ <anchored line, from git show <head>:<path>>
<end>   │ <anchored line>
```

> <full comment body, verbatim as in payload>

---

#### r1 · reply to #<threadId> · `<path>:<line>`

> <full reply body, verbatim as in payload>

---

**Skipped:** <key> already on live thread #<id> · <key> outside the diff → general comment
````

- **Anchored code**: the lines the thread will highlight, read with *Step 3*'s command at the pinned head, so the user sees what the comment points at. Show them for a new thread, and for a reply on a thread that has a `threadContext`; omit the block for a general comment or a file-level thread. Number each line, tag the fence with the file's language (`md`, `cs`, `tsx`, …), and cut a line over 160 characters to its first 160 plus ` …` (preview only; the payload anchors the whole line). For a range over 12 lines, show the first 5 and the last 5 around a `⋮` line.
- **Body**: the payload text verbatim in a blockquote, attribution line and bold title line included.
- **Separators**: a `---` rule between items, so each body is visibly bounded.

End the preview with the payload directory's absolute path (`<scratchpad>/pr<id>/`), then prompt the user (*Post all <N>* / *Keep as draft*, or on a host without a question tool: `Reply "post" to send all, "post 1,3" for a subset, or tell me what to change.`).
