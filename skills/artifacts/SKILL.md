---
name: artifacts
description: Discovers and displays recent artifacts across the current and recent conversation sessions, allowing the user to select and target a specific artifact to inspect, review (/review), update, or execute (/proceed).
---

# Skill: `/artifacts` — Artifact Explorer & Targeting

Enables the user to inspect, list, and target recent artifacts (implementation plans, walkthroughs, design documents, research notes) generated across current and recent sessions in Antigravity IDE.

---

## 1. When to Use

Invoke this skill whenever:
- The user issues the `/artifacts` command.
- The user asks to see recent artifacts or plans (e.g. *"Show my recent plans"*, *"Which artifacts exist?"*).
- The user wants to select/target a specific artifact from this or previous sessions to review, edit, or execute.

---

## 2. Discovery Protocol

Artifacts live in one of two places depending on which IDE wrote them.

**Primary — the workspace root.** This is where every skill writes now (`code_review.md`,
`implementation_plan.md`, `walkthrough.md`, `explanation.md`, `what_am_i_missing.md`), and
it is the only location whose links are clickable in Claude Code.

**Legacy — the Antigravity brain directory**, `<appDataDir>/brain/<conversation-id>/`,
where `<appDataDir>` is typically `/Users/snuffish/.gemini/antigravity-ide`.

### Step 1: Scan Workspace-Root Artifacts

```bash
ls -lt *.md
```

### Step 2: Scan Legacy Conversation Artifacts
1. Check the active conversation directory:
   `<appDataDir>/brain/<current-conversation-id>/`
2. Look for all top-level markdown documents (excluding hidden folders like `.system_generated/`, `.user_uploaded/`, and temporary `scratch/` files).
3. Check corresponding `*.metadata.json` files for human-readable summaries and metadata.

### Step 3: Scan Recent Conversation Sessions
1. Inspect the conversation IDs provided in the `<conversation_history>` block of the prompt.
2. For the most recent conversations (top 5–10), check their artifact directory:
   `<appDataDir>/brain/<past-conversation-id>/`
3. Identify existing artifact markdown files. If needed, a quick shell command from the workspace can list them:
   ```bash
   # From workspace root, list recently modified markdown artifacts in the brain directory
   find /Users/snuffish/.gemini/antigravity-ide/brain -maxdepth 2 -name "*.md" -not -path "*/.system_generated/*" -not -path "*/scratch/*" | head -n 20
   ```

---

## 3. Presenting & Selecting Artifacts

Present the discovered artifacts in a clean, structured table, followed by an interactive selection prompt:

```markdown
# 📂 Recent Artifacts

| # | Artifact | Conversation / Session | Summary / Goal | Path |
|---|---|---|---|---|
| 1 | `implementation_plan.md` | Workspace root | Extract OperationObject mutations with grouped registration | [view](implementation_plan.md) |
| 2 | `walkthrough.md` | Workspace root | Verification results and walkthrough of changes | [view](walkthrough.md) |
| ... | ... | ... | ... | ... |
```

### Interactive Targeting
To let the user target an artifact:
1. If there are multiple options, use the `ask_question` tool with options for the most relevant/recent artifacts, allowing the user to select one with a single click.
2. Alternatively, present the numbered list and ask the user which one they would like to target.

---

## 4. Actions on the Targeted Artifact

Once an artifact is selected / targeted:
1. **Read & Summarize**: Provide a concise summary of the targeted artifact's status, open questions, and proposed changes.
2. **Offer Next Steps**:
   - **Review**: *"Run `/review` to conduct a strict read-only audit of this plan."*
   - **Proceed**: *"Type `/proceed` to begin implementing this plan."*
   - **Refine / Edit**: *"Tell me what modifications you'd like to make to the plan."*
   - **View Full Details**: Clickable file link to the artifact markdown file.

> [!IMPORTANT]
> **Link format.** Use a **workspace-relative** path with no scheme —
> `[code_review.md](code_review.md)`. An absolute `file:///...` URI renders as dead text,
> as does any path outside the workspace root, so artifacts still sitting in the legacy
> brain directory cannot be linked — offer to copy them to the workspace root instead.
> Section anchors must be **line numbers** (`#L42`), never heading slugs.
