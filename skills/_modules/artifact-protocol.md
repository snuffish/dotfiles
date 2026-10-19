# artifact-protocol

How every Command names, places and links the markdown artifacts it writes at the workspace root: host and model prefix, mandatory contextual suffix, link formats, PR thread links and the canonical artifact catalog.

---

## Artifact Location, Host & Model Prefix Resolution & Mandatory Contextual Suffix

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

### Rules:
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

## Host-Specific Link Formats & Section Anchors

Chat links and document anchors must follow strict formatting rules depending on the host:

| Host | Chat Link Syntax | Example |
|---|---|---|
| **Antigravity IDE** | Absolute path with `file://` scheme *(relative links render dead/unclickable)* | `[antigravity-plan-auth.md](file://<workspace-root>/antigravity-implementation_plan-auth.md#L8)` |
| **Claude Code** | Workspace-relative path without scheme *(`file://` URIs render dead)* | `[claude-plan-auth.md](claude-implementation_plan-auth.md#L8)` |

### Section Anchor / Fragment Rules:
- **Chat Links (Both Hosts)**: Always use `#L<line>` (e.g. `#L8` or `#L8-L20`), **never** heading slugs (`#context--goal` fails in Claude Code). Read the actual line numbers from the file after writing:
  ```bash
  grep -n '^#\{1,3\} ' <prefix>-<artifact>-<suffix>.md
  ```
- **Intra-Document Links (Inside Markdown Files)**: Use standard HTML anchor tags `<a id="..."></a>` and semantic `#anchor` targets, never `#L<line>`.
- **Cross-Host Reading**: When listing or referencing an artifact written by the *other* host, format the link for **your own** active host (the reader).

---

## PR Discussion Thread Links (Dual Navigation)

When artifacts reference discussion threads or comments from a pull request (such as in `pr_feedback_review` or `code_review`), every thread reference must provide **dual navigation**:

1. **Intra-Document Navigation**: Navigates locally within the markdown file to the thread's detailed analysis section: `[#<id>](#thread-<id>)`.
2. **Direct Remote Link**: Directly opens the specific discussion thread in the remote host (Azure DevOps or GitHub):
   - **Azure DevOps**: `<prWebUrl>?discussionId=<threadId>`  
     *(e.g. `https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{prId}?discussionId=106813`)*
   - **GitHub**: `<prWebUrl>#discussion_r<commentId>` or `<prWebUrl>#issuecomment-<id>`

### Formatting Standards:
- **In Tables & Triage Matrices**: Keep the internal anchor and append the remote link in parentheses:
  ```markdown
  | [#106813](#thread-106813) ([devops](https://dev.azure.com/.../pullrequest/18176?discussionId=106813)) | `File.cs:42` | ...
  ```
- **In Section Headings**: Include the direct remote link on the thread number, wrapped in the intra-document anchor:
  ```markdown
  ### <a id="thread-106813"></a>Thread [#106813](https://dev.azure.com/.../pullrequest/18176?discussionId=106813): Revoke permissions when terminated
  ```

---

## Canonical Artifact Catalog

| Base Filename Pattern | Claude Code Example | Antigravity IDE Example | Written / Managed By | Primary Purpose |
|---|---|---|---|---|
| `implementation_plan-<suffix>.md` | `claude-sonnet-3.7-implementation_plan-begar-prefix.md` | `antigravity-gemini-3.8-flash-implementation_plan-begar-prefix.md` | `/plan`, `/problem`, `/refine`, `/implement-feature`, `/pr-fix-pipeline` | Technical design, phase breakdown, task checklist, gating approval |
| `code_review-<suffix>.md` | `claude-sonnet-3.7-code_review-18176-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-code_review-category-demand-statistics.md` | `/code-review` | Code quality audit, severity findings (Critical/Important/Minor), diffs |
| `pr_feedback_review-<suffix>.md` | `claude-sonnet-3.7-pr_feedback_review-18176-backend.md` | `antigravity-gemini-3.8-flash-pr_feedback_review-18176-backend.md` | `/pr-feedback-review` | PR comment triage matrix, technical resolutions, draft responses |
| `investigation-<suffix>.md` | `claude-sonnet-3.7-investigation-draft-close-dialog.md` | `antigravity-gemini-3.8-flash-investigation-draft-close-dialog.md` | `/investigate`, `/pr-fix-pipeline` | Pre-plan research: current-state map, prior art, constraints, options, confidence ledger |
| `explanation-<suffix>.md` | `claude-sonnet-3.7-explanation-matching-ticket.md` | `antigravity-gemini-3.8-flash-explanation-matching-ticket.md` | `/explain` | Deep architectural and code intent breakdown |
| `suggestion-<suffix>.md` | `claude-sonnet-3.7-suggestion-cache-invalidation-strategy.md` | `antigravity-gemini-3.8-flash-suggestion-pdf-export-library.md` | `/suggestion` | Ranked approaches with trade-offs, a recommendation and next steps |
| `assumption_check-<suffix>.md` | `claude-sonnet-3.7-assumption_check-skill-modules.md` | `antigravity-gemini-3.8-flash-assumption_check-skill-modules.md` | `/verify-assumptions` | Claim-by-claim verification against primary sources, verdicts and the decisions they affect |
| `what_am_i_missing-<suffix>.md` | `claude-sonnet-3.7-what_am_i_missing-municipality-sync.md` | `antigravity-gemini-3.8-flash-what_am_i_missing-municipality-sync.md` | `/what-am-I-missing` | Blind spots, failure modes, invariant audits |
| `spec_verification-<suffix>.md` | `claude-sonnet-3.7-spec_verification-18176-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-spec_verification-18176-verksamhetsobjekt.md` | `/spec-verification` | Requirement-by-requirement traceability against the work item, PR or plan |
| `conflict_resolution-<suffix>.md` | `claude-sonnet-3.7-conflict_resolution-feature-x-into-main.md` | `antigravity-gemini-3.8-flash-conflict_resolution-feature-x-into-main.md` | `/resolve-conflicts` | Per-hunk resolution record when a merge or rebase crosses the threshold for a written record |
| `expressive-<suffix>.md` | `claude-sonnet-3.7-expressive-matching-filters.md` | `antigravity-gemini-3.8-flash-expressive-matching-filters.md` | `/expressive` | Readability sweep findings and proposed declarative rewrites |
| `walkthrough-<suffix>.md` | `claude-sonnet-3.7-walkthrough-29982-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-walkthrough-29982-verksamhetsobjekt.md` | `/implement-feature` | Verification results, screenshots, completed summary |
| `organize_plan-<suffix>.md` | `claude-sonnet-3.7-organize_plan-matching-components.md` | `antigravity-gemini-3.8-flash-organize_plan-matching-components.md` | `/organize` | Directory/module structure refactoring proposal |
| `clean_report-<suffix>.md` | `claude-sonnet-3.7-clean_report-audit-endpoint.md` | `antigravity-gemini-3.8-flash-clean_report-audit-endpoint.md` | `/clean` | Multi-file dead-code pruning & sanitation report |
| `skills_sync_report[-<suffix>].md` | `claude-sonnet-3.7-skills_sync_report.md` | `antigravity-gemini-3.8-flash-skills_sync_report.md` | `/reload-skills` | Registry discovery & loader synchronization audit |
| `health_check-<suffix>.md` | `claude-sonnet-3.7-health_check-backend.md` | `antigravity-gemini-3.8-flash-health_check-frontend.md` | `source-command-backend-health-check`, `source-command-frontend-health-check` | Convention-drift scorecard per inspection area |

*(Older unprefixed, un-modeled, or unsuffixed files written before the full convention should still be recognized during scans).*
