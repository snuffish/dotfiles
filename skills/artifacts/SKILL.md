---
name: artifacts
description: Discovers, inspects, and targets workspace artifacts across sessions. Also serves as the central Universal Artifact Protocol (single source of truth for host prefix resolution, link formats, and artifact specifications across all skills).
---

# Skill: `/artifacts` — Universal Artifact Protocol & Explorer

The central source of truth for workspace artifact creation, host prefix resolution, link formatting, and artifact exploration across Claude Code, Antigravity IDE, and other AI coding assistants.

---

## 1. Universal Artifact Protocol (Single Source of Truth)

All skills generating or linking workspace artifacts must conform strictly to the following standards.

### 1.1 Artifact Location & Host Prefix Resolution

Claude Code and Antigravity IDE share one workspace root. An unprefixed filename means whichever host runs second silently overwrites the other's work.

**Rules:**
1. **Resolve prefix once before writing**, based on the assistant's identity from the system prompt:

| Running as | System Prompt Indicator | Prefix | Artifact Target Path |
|---|---|---|---|
| Claude Code | *"You are Claude"* | `claude-` | Workspace root: `<workspace-root>/claude-<artifact>.md` |
| Antigravity IDE | *"You are Antigravity"* | `antigravity-` | Workspace root: `<workspace-root>/antigravity-<artifact>.md` |
| Any other host | *(none of the above)* | *(none)* | Workspace root: `<workspace-root>/<artifact>.md` |

2. **Single Identity Rule**: Never write both filenames in one session.
3. **No Overwrite Rule**: Never read or overwrite the other host's active artifact — if `antigravity-implementation_plan.md` exists while running as Claude, leave it intact.
4. **Clickability Rule**: Always write directly to the **workspace root**. That location is what makes links clickable across IDEs.

---

### 1.2 Host-Specific Link Formats & Section Anchors

Chat links and document anchors must follow strict formatting rules depending on the host:

| Host | Chat Link Syntax | Example |
|---|---|---|
| **Antigravity IDE** | Absolute path with `file://` scheme *(relative links render dead/unclickable)* | `[antigravity-plan.md](file://<workspace-root>/antigravity-plan.md#L8)` |
| **Claude Code** | Workspace-relative path without scheme *(`file://` URIs render dead)* | `[claude-plan.md](claude-plan.md#L8)` |

#### Section Anchor / Fragment Rules:
- **Chat Links (Both Hosts)**: Always use `#L<line>` (e.g. `#L8` or `#L8-L20`), **never** heading slugs (`#context--goal` fails in Claude Code). Read the actual line numbers from the file after writing:
  ```bash
  grep -n '^#\{1,3\} ' <prefix>-<artifact>.md
  ```
- **Intra-Document Links (Inside Markdown Files)**: Use standard HTML anchor tags `<a id="..."></a>` and semantic `#anchor` targets, never `#L<line>`.
- **Cross-Host Reading**: When listing or referencing an artifact written by the *other* host, format the link for **your own** active host (the reader).

---

### 1.3 PR Discussion Thread Links (Dual Navigation)

When artifacts reference discussion threads or comments from a pull request (such as in `pr_feedback_review.md` or `code_review.md`), every thread reference must provide **dual navigation**:

1. **Intra-Document Navigation**: Navigates locally within the markdown file to the thread's detailed analysis section: `[#<id>](#thread-<id>)`.
2. **Direct Remote Link**: Directly opens the specific discussion thread in the remote host (Azure DevOps or GitHub):
   - **Azure DevOps**: `<prWebUrl>?discussionId=<threadId>`  
     *(e.g. `https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{prId}?discussionId=106813`)*
   - **GitHub**: `<prWebUrl>#discussion_r<commentId>` or `<prWebUrl>#issuecomment-<id>`

#### Formatting Standards:
- **In Tables & Triage Matrices**: Keep the internal anchor and append the remote link in parentheses:
  ```markdown
  | [#106813](#thread-106813) ([devops](https://dev.azure.com/.../pullrequest/18176?discussionId=106813)) | `File.cs:42` | ...
  ```
- **In Section Headings**: Include the direct remote link on the thread number, wrapped in the intra-document anchor:
  ```markdown
  ### <a id="thread-106813"></a>Thread [#106813](https://dev.azure.com/.../pullrequest/18176?discussionId=106813): Revoke permissions when terminated
  ```

---

### 1.4 Canonical Artifact Catalog

| Base Filename | Claude Code | Antigravity IDE | Written / Managed By | Primary Purpose |
|---|---|---|---|---|
| `implementation_plan.md` | `claude-implementation_plan.md` | `antigravity-implementation_plan.md` | `/plan`, `/problem`, `/refine`, `/implement-feature` | Technical design, phase breakdown, task checklist, gating approval |
| `code_review.md` | `claude-code_review.md` | `antigravity-code_review.md` | `/code-review` | Code quality audit, severity findings (Critical/Important/Minor), diffs |
| `pr_feedback_review.md` | `claude-pr_feedback_review.md` | `antigravity-pr_feedback_review.md` | `/pr-feedback-review` | PR comment triage matrix, technical resolutions, draft responses |
| `explanation.md` | `claude-explanation.md` | `antigravity-explanation.md` | `/explain` | Deep architectural and code intent breakdown |
| `what_am_i_missing.md` | `claude-what_am_i_missing.md` | `antigravity-what_am_i_missing.md` | `/what-am-I-missing` | Blind spots, failure modes, invariant audits |
| `walkthrough.md` | `claude-walkthrough.md` | `antigravity-walkthrough.md` | `/implement-feature` | Verification results, screenshots, completed summary |

*(Unprefixed files are older artifacts written before the prefix convention, or from standalone hosts — treat them as valid artifacts).*

---

## 2. Artifact Explorer & Interactive Targeting (Skill Command `/artifacts`)

Enables the user to inspect, list, and target recent artifacts generated across current and recent sessions.

### When to Use
- The user issues `/artifacts`.
- The user asks: *"Show my recent plans"*, *"Which artifacts exist?"*, or *"Target an artifact"*.

### Discovery Protocol

#### Step 1: Scan Workspace-Root Artifacts
`/artifacts` is the one skill that reads **across** hosts to show the user everything:
```bash
ls -lt *.md
```
Group results by base artifact name rather than filename so both host versions sit side-by-side with their timestamps.

#### Step 2: Scan Legacy Conversation Artifacts (Antigravity Only)
1. Check active conversation: `<appDataDir>/brain/<current-conversation-id>/` (excluding hidden `.system_generated/` and `scratch/`).
2. Check past conversations from `<conversation_history>` (top 5–10) in `<appDataDir>/brain/<past-id>/`.

---

### Presenting & Selecting Artifacts

Present discovered artifacts in a structured table:

```markdown
# 📂 Recent Artifacts

| # | Artifact | Location · Host | Summary / Goal | Link |
|---|---|---|---|---|
| 1 | `claude-implementation_plan.md` | Workspace root · Claude Code | Grouped endpoint registration | [view](claude-implementation_plan.md) |
| 2 | `antigravity-implementation_plan.md` | Workspace root · Antigravity | Same plan, earlier revision | [view](file://<workspace-root>/antigravity-implementation_plan.md) |
| 3 | `claude-walkthrough.md` | Workspace root · Claude Code | Verification results | [view](claude-walkthrough.md) |
```

#### Interactive Targeting
- If multiple options exist, use `ask_question` or present a numbered list allowing the user to pick an artifact with a single click.

---

### Actions on Targeted Artifact

Once an artifact is selected:
1. **Summarize**: Concise status, open questions, and proposed changes.
2. **Next Steps**:
   - **Review**: *"Run `/review` to conduct a strict read-only audit of this plan."*
   - **Proceed**: *"Type `/proceed` to begin implementing this plan."*
   - **Refine / Edit**: *"Tell me what modifications you'd like to make to the plan."*
   - **View Details**: Provide a clickable direct link to open the file in the IDE.
