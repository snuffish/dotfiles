---
name: artifacts
description: Discovers, inspects, and targets workspace artifacts across sessions. Also serves as the central Universal Artifact Protocol (single source of truth for host prefix resolution, link formats, and artifact specifications across all skills).
---

# Skill: `/artifacts` — Universal Artifact Protocol & Explorer

The central source of truth for workspace artifact creation, host prefix resolution, link formatting, and artifact exploration across Claude Code, Antigravity IDE, and other AI coding assistants.

---

## 1. Universal Artifact Protocol (Single Source of Truth)

All skills generating or linking workspace artifacts must conform strictly to the following standards.

### 1.1 Artifact Location, Host & Model Prefix Resolution & Mandatory Contextual Suffix

Claude Code and Antigravity IDE share one workspace root, and multiple agents, subagents, or developer workflows may run concurrently or consecutively across different features, pull requests, and bug fixes — frequently using different underlying AI models (e.g. Gemini 3.8 Flash vs Gemini 2.5 Pro, Claude 3.7 Sonnet vs Claude 3.5 Sonnet).
- An **unprefixed** filename means whichever host runs second silently overwrites the other host's work.
- A **model-less** prefix (e.g. bare `antigravity-code_review.md` or `claude-implementation_plan.md`) causes different models or subsequent sessions on the same platform to collide and overwrite findings.
- An **unsuffixed generic** filename guarantees that different tasks or PR reviews overwrite each other.

**Universal Naming Pattern:**
```text
<workspace-root>/<prefix>-<base_artifact_name>-<suffix>.md
```
Where `<prefix>` is `<host>-<model>-`:
```text
<workspace-root>/<host>-<model>-<base_artifact_name>-<suffix>.md
```

#### Rules:
1. **Resolve Prefix (`<host>-<model>-`) Once Before Writing**:
Detect the active host and slugify the active AI model name:

| Running as | System Prompt Indicator | Active Model Indicator | Prefix (`<host>-<model>-`) | Artifact Target Path Example |
|---|---|---|---|---|
| Claude Code | *"You are Claude"* | Claude 3.7 Sonnet | `claude-sonnet-3.7-` | `<workspace-root>/claude-sonnet-3.7-<artifact>-<suffix>.md` |
| Claude Code | *"You are Claude"* | Claude 3.5 Sonnet | `claude-sonnet-3.5-` | `<workspace-root>/claude-sonnet-3.5-<artifact>-<suffix>.md` |
| Antigravity IDE | *"You are Antigravity"* | Gemini 3.8 Flash | `antigravity-gemini-3.8-flash-` | `<workspace-root>/antigravity-gemini-3.8-flash-<artifact>-<suffix>.md` |
| Antigravity IDE | *"You are Antigravity"* | Gemini 2.5 Pro | `antigravity-gemini-2.5-pro-` | `<workspace-root>/antigravity-gemini-2.5-pro-<artifact>-<suffix>.md` |
| Any other host | *(none of above)* | Active model | `<host>-<model>-` (or `<model>-`) | `<workspace-root>/<prefix>-<artifact>-<suffix>.md` |

- **Model Detection**:
  - **Antigravity IDE**: Inspect active model selection/metadata from user settings or context (e.g. `gemini-3.8-flash`, fallback: `gemini`).
  - **Claude Code**: Inspect environment (`ANTHROPIC_MODEL`), CLI options, or system prompt (e.g. `sonnet-3.7`, `sonnet-3.5`, fallback: `sonnet`).
- **Model Slug Format**: Lowercase alphanumeric and periods/hyphens (e.g., `gemini-3.8-flash`, `sonnet-3.7`).

2. **Mandatory Contextual Suffix (Anti-Overwrite Invariant)**:
   - **Always append a descriptive kebab-case suffix (`-<suffix>`)** to every artifact.
   - **Never generate unsuffixed generic artifacts** (such as bare `antigravity-gemini-3.8-flash-implementation_plan.md`).
   - Suffix derivation priority:
     1. **Work Item / PR / Ticket ID + Slug**: If associated with an explicit work item, ticket, or PR, prefix the slug with that ID (e.g. `-18176-verksamhetsobjekt`, `-29982-verksamhetsobjekt`, `-1480-009204`).
     2. **Branch or Feature Name**: If working on a git branch, use a kebab-case slug of the branch name (e.g. branch `feature/new-users-audit` → `-new-users-audit`, `bugfix/draft-close-dialog` → `-draft-close-dialog`).
     3. **Topic / Task Descriptor**: If running on a general task or request, derive a concise (2–4 words, kebab-case) topic slug from the task or user prompt (e.g. `-begar-prefix`, `-ticket-category-config`).
3. **Idempotent Same-Task Updates**: Within the *same* ongoing task, branch, or PR review, an agent running with that model may update that specific suffixed artifact rather than creating runaway duplicates, while preserving all artifacts from other models and tasks.
4. **Single Identity Rule**: Never write multiple host/model variants in one turn.
5. **No Cross-Host / Cross-Model Overwrite Rule**: Never overwrite another host's or another model's active artifact — leave them intact.
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
| `implementation_plan-<suffix>.md` | `claude-sonnet-3.7-implementation_plan-begar-prefix.md` | `antigravity-gemini-3.8-flash-implementation_plan-begar-prefix.md` | `/plan`, `/problem`, `/refine`, `/implement-feature` | Technical design, phase breakdown, task checklist, gating approval |
| `code_review-<suffix>.md` | `claude-sonnet-3.7-code_review-18176-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-code_review-category-demand-statistics.md` | `/code-review` | Code quality audit, severity findings (Critical/Important/Minor), diffs |
| `pr_feedback_review-<suffix>.md` | `claude-sonnet-3.7-pr_feedback_review-18176-backend.md` | `antigravity-gemini-3.8-flash-pr_feedback_review-18176-backend.md` | `/pr-feedback-review` | PR comment triage matrix, technical resolutions, draft responses |
| `investigation-<suffix>.md` | `claude-sonnet-3.7-investigation-draft-close-dialog.md` | `antigravity-gemini-3.8-flash-investigation-draft-close-dialog.md` | `/investigate` | Pre-plan research: current-state map, prior art, constraints, options, confidence ledger |
| `explanation-<suffix>.md` | `claude-sonnet-3.7-explanation-matching-ticket.md` | `antigravity-gemini-3.8-flash-explanation-matching-ticket.md` | `/explain` | Deep architectural and code intent breakdown |
| `what_am_i_missing-<suffix>.md` | `claude-sonnet-3.7-what_am_i_missing-municipality-sync.md` | `antigravity-gemini-3.8-flash-what_am_i_missing-municipality-sync.md` | `/what-am-I-missing` | Blind spots, failure modes, invariant audits |
| `walkthrough-<suffix>.md` | `claude-sonnet-3.7-walkthrough-29982-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-walkthrough-29982-verksamhetsobjekt.md` | `/implement-feature` | Verification results, screenshots, completed summary |
| `organize_plan-<suffix>.md` | `claude-sonnet-3.7-organize_plan-matching-components.md` | `antigravity-gemini-3.8-flash-organize_plan-matching-components.md` | `/organize` | Directory/module structure refactoring proposal |
| `clean_report-<suffix>.md` | `claude-sonnet-3.7-clean_report-audit-endpoint.md` | `antigravity-gemini-3.8-flash-clean_report-audit-endpoint.md` | `/clean` | Multi-file dead-code pruning & sanitation report |
| `skills_sync_report[-<suffix>].md` | `claude-sonnet-3.7-skills_sync_report.md` | `antigravity-gemini-3.8-flash-skills_sync_report.md` | `/reload-skills` | Registry discovery & loader synchronization audit |

*(Older unprefixed, un-modeled, or unsuffixed files written before the full convention should still be recognized during scans).*

---

## 2. Artifact Explorer & Interactive Targeting (Skill Command `/artifacts`)

Enables the user to inspect, list, and target recent artifacts generated across current and recent sessions.

### When to Use
- The user issues `/artifacts`.
- The user asks: *"Show my recent plans"*, *"Which artifacts exist?"*, or *"Target an artifact"*.

### Discovery Protocol

#### Step 1: Scan Workspace-Root Artifacts
`/artifacts` is the one skill that reads **across** hosts, models, and suffixes to show the user everything:
```bash
ls -lt *.md
```
Parse filenames into:
- **Host**: `claude`, `antigravity`, or `(standalone)`
- **AI Model**: e.g. `gemini-3.8-flash`, `sonnet-3.7`, `gemini-2.5-pro`, `sonnet-3.5`
- **Base Type**: `implementation_plan`, `code_review`, `pr_feedback_review`, `investigation`, etc.
- **Suffix / Topic**: The trailing identifier (e.g. `category-demand-statistics`, `18176-verksamhetsobjekt`, `begar-prefix`)

#### Step 2: Scan Legacy Conversation Artifacts (Antigravity Only)
1. Check active conversation: `<appDataDir>/brain/<current-conversation-id>/` (excluding hidden `.system_generated/` and `scratch/`).
2. Check past conversations from `<conversation_history>` (top 5–10) in `<appDataDir>/brain/<past-id>/`.

---

### Presenting & Selecting Artifacts

Present discovered artifacts in a structured table:

```markdown
# 📂 Recent Artifacts

| # | Artifact | Host · Model | Topic / Suffix | Summary / Goal | Link |
|---|---|---|---|---|---|
| 1 | `antigravity-gemini-3.8-flash-code_review-category-demand-statistics.md` | Antigravity · Gemini 3.8 Flash | `category-demand-statistics` | Category demand statistics code review | [view](file://<workspace-root>/antigravity-gemini-3.8-flash-code_review-category-demand-statistics.md) |
| 2 | `claude-sonnet-3.7-code_review-18176-verksamhetsobjekt.md` | Claude Code · Sonnet 3.7 | `18176-verksamhetsobjekt` | PR #18176 code review | [view](claude-sonnet-3.7-code_review-18176-verksamhetsobjekt.md) |
| 3 | `antigravity-gemini-3.8-flash-implementation_plan-begar-prefix.md` | Antigravity · Gemini 3.8 Flash | `begar-prefix` | Begär-prefix refactor plan | [view](file://<workspace-root>/antigravity-gemini-3.8-flash-implementation_plan-begar-prefix.md) |
| 4 | `claude-sonnet-3.7-walkthrough-29982-verksamhetsobjekt.md` | Claude Code · Sonnet 3.7 | `29982-verksamhetsobjekt` | Verification results | [view](claude-sonnet-3.7-walkthrough-29982-verksamhetsobjekt.md) |
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
