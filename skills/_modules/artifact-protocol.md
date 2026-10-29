# artifact-protocol

How every Command names, places and links the markdown artifacts it writes at the workspace root: host and model prefix, mandatory contextual suffix, session ownership and collision-safe creation (no session ever overwrites another's artifact), link formats, PR thread links and the canonical artifact catalog.

---

## Artifact Location, Host & Model Prefix Resolution & Mandatory Contextual Suffix

Claude Code and Antigravity IDE share one workspace root, and multiple agents, subagents, or developer workflows may run concurrently or consecutively across different features, pull requests, and bug fixes — frequently using different underlying AI models (e.g. Gemini 3.8 Flash vs Gemini 2.5 Pro, Claude 3.7 Sonnet vs Claude 3.5 Sonnet).
- An **unprefixed** filename means whichever host runs second silently overwrites the other host's work.
- A **model-less** prefix (e.g. bare `antigravity-code_review.md` or `claude-implementation_plan.md`) causes different models or subsequent sessions on the same platform to collide and overwrite findings.
- An **unsuffixed generic** filename guarantees that different tasks or PR reviews overwrite each other.
- Even a fully prefixed and suffixed name is shared by **every session** of the same host and model on the same task. Naming alone cannot stop a second session from overwriting the first. *Ownership* and *Claim* (below) can.

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
| Claude Code | *"You are Claude Code"* | Opus 5.5 | `claude-opus-5.5-` | `<workspace-root>/claude-opus-5.5-<artifact>-<suffix>.md` |
| Antigravity IDE | *"You are Antigravity"* | Gemini 3.8 Flash | `antigravity-gemini-3.8-flash-` | `<workspace-root>/antigravity-gemini-3.8-flash-<artifact>-<suffix>.md` |
| Any other host | *(none of above)* | Active model | `<host>-<model>-` (or `<model>-`) | `<workspace-root>/<prefix>-<artifact>-<suffix>.md` |

- **Model Detection**:
  - **Claude Code**: the system prompt names the model ("You are powered by the model named Opus 5.5"). Slugify that name: "Opus 5.5" → `opus-5.5`, "Sonnet 5.5" → `sonnet-5.5`. `ANTHROPIC_MODEL` is usually unset, so do not rely on it. Fallback: `claude`.
  - **Antigravity IDE**: inspect the active model selection or metadata from user settings or context (e.g. `gemini-3.8-flash`). Fallback: `gemini`.
- **Model Slug Format**: Lowercase alphanumeric and periods/hyphens (e.g., `gemini-3.8-flash`, `opus-5.5`).

2. **Mandatory Contextual Suffix (Anti-Overwrite Invariant)**:
   - **Always append a descriptive kebab-case suffix (`-<suffix>`)** to every artifact.
   - **Never generate unsuffixed generic artifacts** (such as bare `antigravity-gemini-3.8-flash-implementation_plan.md`).
   - Suffix derivation priority:
     1. **Work Item / PR / Ticket ID + Slug**: If associated with an explicit work item, ticket, or PR, prefix the slug with that ID (e.g. `-18176-verksamhetsobjekt`, `-29982-verksamhetsobjekt`, `-1480-009204`).
     2. **Branch or Feature Name**: If working on a git branch, use a kebab-case slug of the branch name (e.g. branch `feature/new-users-audit` → `-new-users-audit`, `bugfix/draft-close-dialog` → `-draft-close-dialog`).
     3. **Topic / Task Descriptor**: If running on a general task or request, derive a concise (2–4 words, kebab-case) topic slug from the task or user prompt (e.g. `-begar-prefix`, `-ticket-category-config`).
3. **Ownership (No-Overwrite Invariant)**: a session may update an artifact only when **this session owns it**. It owns it when this session created it, which its owner marker proves (*Claim*). Every other artifact is read-only to it. That includes artifacts from another host or model, and also artifacts from **another session of the same host and model**, such as an earlier session on the same PR or a parallel one. A re-run in a new session writes a new file (*Claim* gives it the next free name). It never rewrites the old one. Only these exceptions exist:
   - **The user names the file and asks for it to be updated** in this conversation ("update `claude-…-code_review-18715-….md`"). A general request such as "review it again" is not that. Re-read the file immediately before the edit and keep its owner marker unchanged.
   - **Record lines** that a Command's own steps define, such as `/pr-post-comments` *Posted to PR*, the `/create-ticket` id line, or the **Status** line of a `skill_gap` file (`core` › *Skill gaps*). These only append to or flip that one line or row. They never rewrite other content.
   - **Status fields** that the artifact's own Command declares (e.g. `/pr-feedback-review` › *6.4 — Status fields*). A later step flips them to the new state under rule 7, and touches nothing else.

   A file with no owner marker (written before this rule) belongs to no session. Treat it as read-only unless this conversation created it.
4. **Claim (atomic create; counter on collision)**: file-writing tools overwrite silently, and two sessions can check for "does it exist?" at the same moment. So a new artifact is never created by checking first and writing second. Draft it in a session-private path (the host's scratchpad, else `mktemp`), then publish it with an exclusive create. Under `set -C` (noclobber), `>` refuses an existing file at the OS level (`O_EXCL`), so claiming the name and writing it are one step:

   ```bash
   # $1 = draft file, $2 = target path without ".md"; prints the path actually written
   publish_new_artifact() {
     local p="$2.md" n=1
     until ( set -C; cat "$1" > "$p" ) 2>/dev/null; do n=$((n + 1)); p="$2-$n.md"; done
     printf '%s\n' "$p"
   }
   ```

   - **Collision counter**: when `<prefix>-<base>-<suffix>.md` is taken, the artifact becomes `<prefix>-<base>-<suffix>-2.md`, then `-3`, and so on. A gap left by a deleted file may be reused: the slot is empty, so nothing is overwritten. Readers order the family by the owner marker, not by the counter.
   - **Owner marker**: the draft's first line is
     `<!-- artifact-owner: <host>-<model> · session <session-id> · created <ISO-8601 timestamp> -->`
     Markdown preview does not show it. `<session-id>` is the host's session or conversation id: in Claude Code, the session UUID in the scratchpad path or `~/.claude/projects/<project>/<uuid>.jsonl`; in Antigravity, the conversation id. If the host exposes neither, use one `uuidgen` value generated at the first write and reused for the rest of the conversation. Before any later update, read the marker and update only if it names this session.
   - **Later updates by the owner** use the normal edit tools. Re-run the anchor `grep` afterwards, because line numbers shift.
   - **Use the path that was actually written**, as printed by the function, in every chat link and every follow-up step. If a counter was added, say so in the chat response, e.g. "`…-2.md`: the base name is owned by another session."
   - **Readers** (`/artifacts`, `/pr-post-comments`, `/squash-code-review`, anything that picks "the latest artifact for this PR") treat `<name>.md`, `<name>-2.md`, … as one family. They pick the newest by the marker's `created` timestamp, else by modification time, and list the whole family when the user has to choose.
5. **Single Identity Rule**: Never write multiple host/model variants in one turn.
6. **Clickability Rule**: Always write directly to the **workspace root**. That location is what makes links clickable across IDEs. The one exception is `skill_gap` files, which go to `~/.terminal/skill-gaps/` whatever the workspace (`core` › *Skill gaps*). Link them by absolute path, with no scheme.
7. **Status Sync Rule (no half-updated artifact)**: an artifact often states one fact in several places: a header `Status:` line, a summary matrix column, a per-item status line, a checklist. When any step records progress in an artifact (a fix applied under `/proceed`, a commit pushed, a reply posted, a thread resolved), it updates **every** place that states that fact, in the same edit. Ticking a checklist item while the matrix still says "Not addressed" is a defect. The Command that writes the artifact lists those places as its *Status fields*. After the edit, `grep` the artifact for the old state's marker (e.g. `⏸`, `Not addressed`, `uncommitted`) and resolve every hit that is now stale. Analysis that was true when written (a thread's *Technical Analysis*) stays as written, labelled with the iteration or date it describes; add a dated note beside it instead of rewriting it, and treat a labelled hit with such a note as history, not as stale.

---

## Host-Specific Link Formats & Section Anchors

Chat links and document anchors must follow strict formatting rules depending on the host:

| Host | Chat Link Syntax | Example |
|---|---|---|
| **Antigravity IDE** | Absolute path with `file://` scheme *(relative links render dead/unclickable)* | `[antigravity-gemini-3.8-flash-implementation_plan-auth.md](file://<workspace-root>/antigravity-gemini-3.8-flash-implementation_plan-auth.md#L8)` |
| **Claude Code, IDE extension** | Workspace-relative path without scheme *(`file://` URIs render dead)* | `[claude-opus-5.5-implementation_plan-auth.md](claude-opus-5.5-implementation_plan-auth.md#L8)` |
| **Claude Code, terminal CLI** | Antigravity IDE editor URL: `antigravity-ide://file/` + absolute path + `:<line>`, spaces as `%20` *(a click opens the file in Antigravity IDE; relative paths open nothing from the terminal)* | `[claude-opus-5.5-implementation_plan-auth.md](antigravity-ide://file/<workspace-root>/claude-opus-5.5-implementation_plan-auth.md:8)` |

Tell the two Claude Code hosts apart by `$CLAUDE_CODE_ENTRYPOINT`: `cli` is the terminal; anything else (`claude-vscode`, …) is the IDE extension. Check it once per session.

### Section Anchor / Fragment Rules:
- **Chat Links (All Hosts)**: Point at a line, **never** at a heading slug (`#context--goal` fails in Claude Code). Use `#L<line>` (e.g. `#L8` or `#L8-L20`), except in a terminal-CLI editor URL, which takes `:<line>` and no range. Read the actual line numbers from the file after writing:
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
| `implementation_plan-<suffix>.md` | `claude-opus-5.5-implementation_plan-begar-prefix.md` | `antigravity-gemini-3.8-flash-implementation_plan-begar-prefix.md` | `/plan`, `/problem`, `/refine`, `/implement-feature`, `/pr-fix-pipeline` | Technical design, phase breakdown, task checklist, gating approval |
| `code_review-<suffix>.md` | `claude-opus-5.5-code_review-18176-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-code_review-category-demand-statistics.md` | `/code-review` | Code quality audit, severity findings (Critical/Important/Minor), diffs |
| `squashed_code_review-<suffix>.md` | `claude-opus-5.5-squashed_code_review-18176-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-squashed_code_review-18176-verksamhetsobjekt.md` | `/squash-code-review` | Two or more code reviews of one change squashed into one verified review, with a reconciliation table and folded-in PR threads |
| `pr_feedback_review-<suffix>.md` | `claude-opus-5.5-pr_feedback_review-18176-backend.md` | `antigravity-gemini-3.8-flash-pr_feedback_review-18176-backend.md` | `/pr-feedback-review` | PR comment triage matrix, technical resolutions, draft responses |
| `investigation-<suffix>.md` | `claude-opus-5.5-investigation-draft-close-dialog.md` | `antigravity-gemini-3.8-flash-investigation-draft-close-dialog.md` | `/investigate`, `/pr-fix-pipeline` | Pre-plan research: current-state map, prior art, constraints, options, confidence ledger |
| `explanation-<suffix>.md` | `claude-opus-5.5-explanation-matching-ticket.md` | `antigravity-gemini-3.8-flash-explanation-matching-ticket.md` | `/explain` | Deep architectural and code intent breakdown |
| `suggestion-<suffix>.md` | `claude-opus-5.5-suggestion-cache-invalidation-strategy.md` | `antigravity-gemini-3.8-flash-suggestion-pdf-export-library.md` | `/suggestion deep` | Ranked approaches with trade-offs, a recommendation and next steps |
| `assumption_check-<suffix>.md` | `claude-opus-5.5-assumption_check-skill-modules.md` | `antigravity-gemini-3.8-flash-assumption_check-skill-modules.md` | `/verify-assumptions` | Claim-by-claim verification against primary sources, verdicts and the decisions they affect |
| `what_am_i_missing-<suffix>.md` | `claude-opus-5.5-what_am_i_missing-municipality-sync.md` | `antigravity-gemini-3.8-flash-what_am_i_missing-municipality-sync.md` | `/what-am-I-missing` | Blind spots, failure modes, invariant audits |
| `spec_verification-<suffix>.md` | `claude-opus-5.5-spec_verification-18176-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-spec_verification-18176-verksamhetsobjekt.md` | `/spec-verification` | Requirement-by-requirement traceability against the work item, PR or plan |
| `manual_test_plan-<suffix>.md` | `claude-opus-5.5-manual_test_plan-31071-unverified-addresses.md` | `antigravity-gemini-3.8-flash-manual_test_plan-31071-unverified-addresses.md` | `/manual-testing` | Runnable manual test plan: setup, logins, test data, risk-ordered scenarios, regression watchlist |
| `conflict_resolution-<suffix>.md` | `claude-opus-5.5-conflict_resolution-feature-x-into-main.md` | `antigravity-gemini-3.8-flash-conflict_resolution-feature-x-into-main.md` | `/resolve-conflicts` | Per-hunk resolution record when a merge or rebase crosses the threshold for a written record |
| `expressive-<suffix>.md` | `claude-opus-5.5-expressive-matching-filters.md` | `antigravity-gemini-3.8-flash-expressive-matching-filters.md` | `/expressive` | Readability sweep findings and proposed declarative rewrites |
| `walkthrough-<suffix>.md` | `claude-opus-5.5-walkthrough-29982-verksamhetsobjekt.md` | `antigravity-gemini-3.8-flash-walkthrough-29982-verksamhetsobjekt.md` | `/implement-feature` | Verification results, screenshots, completed summary |
| `organize_plan-<suffix>.md` | `claude-opus-5.5-organize_plan-matching-components.md` | `antigravity-gemini-3.8-flash-organize_plan-matching-components.md` | `/organize` | Directory/module structure refactoring proposal |
| `clean_report-<suffix>.md` | `claude-opus-5.5-clean_report-audit-endpoint.md` | `antigravity-gemini-3.8-flash-clean_report-audit-endpoint.md` | `/clean` | Multi-file dead-code pruning & sanitation report |
| `skills_sync_report-<suffix>.md` | `claude-opus-5.5-skills_sync_report-full-audit.md` | `antigravity-gemini-3.8-flash-skills_sync_report-full-audit.md` | `/sync-skills` | Registry discovery & loader synchronization audit |
| `health_check-<suffix>.md` | `claude-opus-5.5-health_check-backend.md` | `antigravity-gemini-3.8-flash-health_check-frontend.md` | `priis-backend-health-check`, `priis-frontend-health-check` | Convention-drift scorecard per inspection area |
| `skill_gap-<suffix>.md` | `claude-opus-5.5-skill_gap-widget-local-env-port.md` | `antigravity-gemini-3.8-flash-skill_gap-plan-status-values.md` | Any Command, per `core` › *Skill gaps* | One registry skill fact that proved wrong, with evidence, the proposed edit and an open/fixed status; written to `~/.terminal/skill-gaps/`, not the workspace root |
| `export-<suffix>.<ext>` | `claude-opus-5.5-export-code-review-18815-local-env-scripts.md` | `antigravity-gemini-3.8-flash-export-explanation-matching-ticket.html` | `/export-file` | Standalone copy of conversation content (`.md`, `.html` or `.txt`); written to the current working directory unless the user names a location |

*(Older unprefixed, un-modeled, or unsuffixed files written before the full convention should still be recognized during scans).*
