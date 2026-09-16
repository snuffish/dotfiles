---
name: artifacts
description: Discovers, inspects, and targets workspace artifacts across sessions. Also serves as the central Universal Artifact Protocol (single source of truth for host prefix resolution, link formats, and artifact specifications across all skills).
---

# Skill: `/artifacts` — Universal Artifact Protocol & Explorer

The central source of truth for workspace artifact creation, host prefix resolution, link formatting, and artifact exploration across Claude Code, Antigravity IDE, and other AI coding assistants.

---

## 1. Universal Artifact Protocol (Single Source of Truth)

All skills generating or linking workspace artifacts must conform strictly to the following standards.

### 1.1 Artifact Location, Host Prefix Resolution & Mandatory Contextual Suffix

Claude Code and Antigravity IDE share one workspace root, and multiple agents, subagents, or developer workflows may run concurrently or consecutively across different features, pull requests, and bug fixes.
- An **unprefixed** filename means whichever host runs second silently overwrites the other host's work.
- An **unsuffixed generic** filename (e.g. `antigravity-code_review.md` or `claude-implementation_plan.md`) guarantees that subsequent agents, concurrent tasks, or different PR reviews silently overwrite previous artifacts.

**Universal Naming Pattern:**
```text
<workspace-root>/<prefix>-<base_artifact_name>-<suffix>.md
```

#### Rules:
1. **Resolve Prefix Once Before Writing**, based on the assistant's identity from the system prompt:

| Running as | System Prompt Indicator | Prefix | Artifact Target Path |
|---|---|---|---|
| Claude Code | *"You are Claude"* | `claude-` | Workspace root: `<workspace-root>/claude-<artifact>-<suffix>.md` |
| Antigravity IDE | *"You are Antigravity"* | `antigravity-` | Workspace root: `<workspace-root>/antigravity-<artifact>-<suffix>.md` |
| Any other host | *(none of the above)* | *(none)* | Workspace root: `<workspace-root>/<artifact>-<suffix>.md` |

2. **Mandatory Contextual Suffix (Anti-Overwrite Invariant)**:
   - **Always append a descriptive kebab-case suffix (`-<suffix>`)** to every artifact.
   - **Never generate unsuffixed generic artifacts** (such as bare `antigravity-implementation_plan.md` or `claude-code_review.md`).
   - Suffix derivation priority:
     1. **Work Item / PR / Ticket ID + Slug**: If associated with an explicit work item, ticket, or PR, prefix the slug with that ID (e.g. `-18176-verksamhetsobjekt`, `-29982-verksamhetsobjekt`, `-1480-009204`).
     2. **Branch or Feature Name**: If working on a git branch, use a kebab-case slug of the branch name (e.g. branch `feature/new-users-audit` → `-new-users-audit`, `bugfix/draft-close-dialog` → `-draft-close-dialog`).
     3. **Topic / Task Descriptor**: If running on a general task or request, derive a concise (2–4 words, kebab-case) topic slug from the task or user prompt (e.g. `-begar-prefix`, `-ticket-category-config`).
3. **Idempotent Same-Task Updates**: Within the *same* ongoing task, branch, or PR review, an agent may update that specific suffixed artifact rather than creating runaway duplicates, while preserving all artifacts from other tasks.
4. **Single Identity Rule**: Never write both host filenames in one session.
5. **No Cross-Host Overwrite Rule**: Never read or overwrite the other host's active artifact — if `antigravity-implementation_plan-begar-prefix.md` exists while running as Claude, leave it intact.
6. **Clickability Rule**: Always write directly to the **workspace root**. That location is what makes links clickable across IDEs.

---

### 1.2 Host-Specific Link Formats & Section Anchors

Chat links and document anchors must follow strict formatting rules depending on the host:

| Host | Chat Link Syntax | Example |
|---|---|---|
| **Antigravity IDE** | Absolute path with `file://` scheme *(relative links render dead/unclickable)* | `[antigravity-plan-auth.md](file://<workspace-root>/antigravity-implementation_plan-auth.md#L8)` |
| **Claude Code** | Workspace-relative path without scheme *(`file://` URIs render dead)* | `[claude-plan-auth.md](claude-implementation_plan-auth.md#L8)` |

#### Section Anchor / Fragment Rules:
- **Chat Links (Both Hosts)**: Always use `#L<line>` (e.g. `#L8` or `#L8-L20`), **never** heading slugs (`#context--goal` fails in Claude Code). Read the actual line numbers from the file after writing:
  ```bash
  grep -n '^#\{1,3\} ' <prefix>-<artifact>-<suffix>.md
  ```
- **Intra-Document Links (Inside Markdown Files)**: Use standard HTML anchor tags `<a id="..."></a>` and semantic `#anchor` targets, never `#L<line>`.
- **Cross-Host Reading**: When listing or referencing an artifact written by the *other* host, format the link for **your own** active host (the reader).

---

### 1.3 PR Discussion Thread Links (Dual Navigation)

When artifacts reference discussion threads or comments from a pull request (such as in `pr_feedback_review` or `code_review`), every thread reference must provide **dual navigation**:

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

| Base Filename Pattern | Claude Code Example | Antigravity IDE Example | Written / Managed By | Primary Purpose |
|---|---|---|---|---|
| `implementation_plan-<suffix>.md` | `claude-implementation_plan-begar-prefix.md` | `antigravity-implementation_plan-begar-prefix.md` | `/plan`, `/problem`, `/refine`, `/implement-feature` | Technical design, phase breakdown, task checklist, gating approval |
| `code_review-<suffix>.md` | `claude-code_review-18176-verksamhetsobjekt.md` | `antigravity-code_review-18176-verksamhetsobjekt.md` | `/code-review` | Code quality audit, severity findings (Critical/Important/Minor), diffs |
| `pr_feedback_review-<suffix>.md` | `claude-pr_feedback_review-18176-backend.md` | `antigravity-pr_feedback_review-18176-backend.md` | `/pr-feedback-review` | PR comment triage matrix, technical resolutions, draft responses |
| `investigation-<suffix>.md` | `claude-investigation-draft-close-dialog.md` | `antigravity-investigation-draft-close-dialog.md` | `/investigate` | Pre-plan research: current-state map, prior art, constraints, options, confidence ledger |
| `explanation-<suffix>.md` | `claude-explanation-matching-ticket.md` | `antigravity-explanation-matching-ticket.md` | `/explain` | Deep architectural and code intent breakdown |
| `what_am_i_missing-<suffix>.md` | `claude-what_am_i_missing-municipality-sync.md` | `antigravity-what_am_i_missing-municipality-sync.md` | `/what-am-I-missing` | Blind spots, failure modes, invariant audits |
| `walkthrough-<suffix>.md` | `claude-walkthrough-29982-verksamhetsobjekt.md` | `antigravity-walkthrough-29982-verksamhetsobjekt.md` | `/implement-feature` | Verification results, screenshots, completed summary |
| `organize_plan-<suffix>.md` | `claude-organize_plan-matching-components.md` | `antigravity-organize_plan-matching-components.md` | `/organize` | Directory/module structure refactoring proposal |
| `clean_report-<suffix>.md` | `claude-clean_report-audit-endpoint.md` | `antigravity-clean_report-audit-endpoint.md` | `/clean` | Multi-file dead-code pruning & sanitation report |
| `skills_sync_report[-<suffix>].md` | `claude-skills_sync_report.md` | `antigravity-skills_sync_report.md` | `/reload-skills` | Registry discovery & loader synchronization audit |

*(Older unprefixed or unsuffixed files written before the suffix convention should still be recognized during scans).*

---

## 2. Artifact Explorer & Interactive Targeting (Skill Command `/artifacts`)

Enables the user to inspect, list, and target recent artifacts generated across current and recent sessions.

### When to Use
- The user issues `/artifacts`.
- The user asks: *"Show my recent plans"*, *"Which artifacts exist?"*, or *"Target an artifact"*.

### Discovery Protocol

#### Step 1: Scan Workspace-Root Artifacts
`/artifacts` is the one skill that reads **across** hosts and suffixes to show the user everything:
```bash
ls -lt *.md
```
Parse filenames into:
- **Host**: `claude-` (Claude Code), `antigravity-` (Antigravity IDE), or `(standalone)`
- **Base Type**: `implementation_plan`, `code_review`, `pr_feedback_review`, `investigation`, etc.
- **Suffix / Topic**: The trailing identifier (e.g. `18176-verksamhetsobjekt`, `begar-prefix`)

#### Step 2: Scan Legacy Conversation Artifacts (Antigravity Only)
1. Check active conversation: `<appDataDir>/brain/<current-conversation-id>/` (excluding hidden `.system_generated/` and `scratch/`).
2. Check past conversations from `<conversation_history>` (top 5–10) in `<appDataDir>/brain/<past-id>/`.

---

### Presenting & Selecting Artifacts

Present discovered artifacts in a structured table:

```markdown
# 📂 Recent Artifacts

| # | Artifact | Location · Host | Topic / Suffix | Summary / Goal | Link |
|---|---|---|---|---|---|
| 1 | `claude-code_review-18176-verksamhetsobjekt.md` | Workspace root · Claude Code | `18176-verksamhetsobjekt` | PR #18176 code review | [view](claude-code_review-18176-verksamhetsobjekt.md) |
| 2 | `antigravity-implementation_plan-begar-prefix.md` | Workspace root · Antigravity | `begar-prefix` | Begär-prefix refactor plan | [view](file://<workspace-root>/antigravity-implementation_plan-begar-prefix.md) |
| 3 | `claude-walkthrough-29982-verksamhetsobjekt.md` | Workspace root · Claude Code | `29982-verksamhetsobjekt` | Verification results | [view](claude-walkthrough-29982-verksamhetsobjekt.md) |
```

#### Interactive Targeting
- If multiple options exist, use `ask_question` or present a numbered list allowing the user to pick an artifact with a single click.

---

### Actions on Targeted Artifact

Once an artifact is selected:
1. **Summarize**: Concise status, open questions, and proposed changes.
2. **Next Steps**:
   - **Review**: *"Run `/review <suffix>` to conduct a strict read-only audit of this plan."*
   - **Proceed**: *"Type `/proceed` to begin implementing this plan."*
   - **Refine / Edit**: *"Tell me what modifications you'd like to make to the plan."*
   - **View Details**: Provide a clickable direct link to open the file in the IDE.
