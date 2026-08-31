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

**Primary — the workspace root.** This is where every skill writes now, and it is the only
location whose links are clickable in Claude Code.

Filenames are **host-prefixed**, because Claude Code and Antigravity IDE share this root and
an unprefixed name would let one host overwrite the other's work. The five artifacts are:

| Base name | Claude Code writes | Antigravity IDE writes | Written by |
|---|---|---|---|
| `code_review.md` | `claude-code_review.md` | `antigravity-code_review.md` | `/code-review` |
| `implementation_plan.md` | `claude-implementation_plan.md` | `antigravity-implementation_plan.md` | `/plan`, `/problem`, `/refine`, `/implement-feature` |
| `walkthrough.md` | `claude-walkthrough.md` | `antigravity-walkthrough.md` | `/implement-feature` |
| `explanation.md` | `claude-explanation.md` | `antigravity-explanation.md` | `/explain` |
| `what_am_i_missing.md` | `claude-what_am_i_missing.md` | `antigravity-what_am_i_missing.md` | `/what-am-I-missing` |

Unprefixed files are older artifacts written before the prefix convention, or ones from a
host that is neither — list them too rather than hiding them.

**Legacy — the Antigravity brain directory**, `<appDataDir>/brain/<conversation-id>/`,
where `<appDataDir>` is typically `/Users/snuffish/.gemini/antigravity-ide`.

### Step 1: Scan Workspace-Root Artifacts

`/artifacts` is the one skill that reads **across** hosts — the point is to show the user
everything, including what the other IDE produced. Do not filter to your own prefix:

```bash
ls -lt *.md
```

Group the results by base artifact rather than by filename, so the two hosts' versions of
the same document sit next to each other, and label which host wrote each one. When two
hosts have both produced the same artifact, say so explicitly and show both timestamps —
that is usually the thing the user actually wants to know.

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

| # | Artifact | Location · Host | Summary / Goal | Link |
|---|---|---|---|---|
| 1 | `claude-implementation_plan.md` | Workspace root · Claude Code | Extract OperationObject mutations with grouped registration | [view](claude-implementation_plan.md) |
| 2 | `antigravity-implementation_plan.md` | Workspace root · Antigravity | Same plan, older revision from the other host | [view](file://<workspace-root>/antigravity-implementation_plan.md) |
| 3 | `claude-walkthrough.md` | Workspace root · Claude Code | Verification results and walkthrough of changes | [view](claude-walkthrough.md) |
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
> **Host-Specific Link Formats (Antigravity IDE vs Claude Code):**
> - **Antigravity IDE**: Chat requires absolute paths with the `file://` scheme:
>   `[antigravity-code_review.md](file://<workspace-root>/antigravity-code_review.md#L42)`.
>   *(Relative links without `file://` render as unclickable/dead text in Antigravity).*
> - **Claude Code**: Chat requires workspace-relative paths without scheme:
>   `[claude-code_review.md](claude-code_review.md#L42)`.
>   *(Absolute `file:///...` URIs render as dead text in Claude Code).*
> - **Section anchors in chat links (both hosts)**: Must be **line numbers** (`#L42` or `#L42-L50`), never heading slugs. (For intra-document links within a markdown file itself, use HTML anchor tags `<a id="..."></a>` and semantic `#anchor` targets).
> - Link each artifact in **your own** host's format, whichever host wrote it. A Claude
>   session listing `antigravity-code_review.md` still links it workspace-relative; the
>   prefix names the author, the link format follows the reader.
> - Artifacts still sitting in the legacy brain directory cannot be linked in Claude Code — offer to copy them to the workspace root instead.
