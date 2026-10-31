# PR Comment Formats & Draft Preview

On-demand reference for [SKILL.md](../SKILL.md) › *Step 4 — Turn each item into a PR comment* and *3. Output Format & Deliverables*.

---

## Minor-Findings Block (`kind: "general"`)

The artifact's *🟢 Minor Findings* list becomes **one general comment per PR** (no file anchor) so it reads as a single non-blocking note rather than a dozen threads to resolve. Omit when the artifact has no 🟢 items for that PR or when the PR already has a live minor-findings comment.

- **Title**: `**🟢 Minor findings (non-blocking)**`
- **Scope**: only that PR's items (in a multi-repo review, split by the repo each item cites; cross-repo contract notes go on the PR that owns the contract).
- **Format**: one bullet per item — `` `File.cs:123`: <claim>. `` Resolved findings become a leading `**✅ <what was checked>: <result>.**` bullet.
- **Expand compressed tails**: if the artifact ends with `"+N more of the same kind: …"`, expand them under a short *Smaller still:* sub-list.
- **Paths**: repo-relative `File.cs:123` only; no workspace-root prefixes, local artifact links, or finding numbers.

---

## Draft Preview Format (`draft` mode)

Show each item verbatim as it will be posted, grouped per PR:

````markdown
**Draft — nothing posted yet.**

### <Repo> !<id> "<PR title>" (iteration <n>, `<short-sha>`)

**1 · reply to #<threadId>, then resolve** · `<path>:<line>` (or `, stays active: <reason>`)
> <full comment body, verbatim as in payload>

**2 · new thread** · `<path>:<start>-<end>`
> <full comment body, verbatim as in payload>

Skipped: <key> already posted on a live thread (#<id>) · <key> outside the diff → general comment
````

End the preview with the payload directory's absolute path (`<scratchpad>/pr<id>/`), then prompt the user (*Post all <N>* / *Keep as draft*, or on a host without a question tool: `Reply "post" to send all, "post 1,3" for a subset, or tell me what to change.`).
