---
name: problem
description: "\"Diagnoses something that is failing now: an error message, a failing build, lint or test, a crash, or behaviour that \\\"stopped working\\\", often after a recent change. Audits git status and recent commits, logs, the active files and past conversation transcripts, finds the root cause, writes a fix plan and fixes only after approval. Use for /problem, \\\"this is broken\\\", \\\"why does this fail?\\\", \\\"I get this error\\\", \\\"the tests fail after your change\\\"..\"."
---

# Skill: `/problem` — Troubleshooting, Diagnostics & Context Recovery

Use this skill whenever the user reports an error (compiler error, lint error, failing test, runtime exception, logic bug) or states that something in a previous implementation is not working.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-implementation_plan-<suffix>.md` (suffix from the error, ticket, or bug description, e.g. `-fix-audit-review`, `-auth-token-failure`)
- `../_modules/git-worktrees.md`

---

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| The failure is in the PR's CI pipeline, not local | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |
| Nothing is failing — the code just smells, or past decisions need re-aligning | [`/refine`](../refine/SKILL.md) |
| Research before deciding how to change something | [`/investigate`](../investigate/SKILL.md) |
| Dead code, unused exports, leftover debug statements in one file | [`/clean`](../clean/SKILL.md) |

---

## Step 1 — Analyze the Symptom & Scope

First, identify the exact signature of the failure:

1. **Logs & Output**: Read the compilation logs, test failures, console messages, or stack traces provided by the user.
2. **Key Identifiers**: Extract the filenames, line numbers, classes, functions, variable names, or database tables involved.
3. **Classification**: Is this a build error (compile/lint), a test assertion failure, a database/schema conflict, or a runtime exception?

---

## Step 2 — Audit Current Workspace State (Git Delta)

Before going back in history, establish what is currently modified or committed in the workspace:

1. **Unstaged & Staged Changes**: Run `git status` to see files currently being edited.
2. **Code Diff**: Run `git diff` and `git diff --staged` to see exactly what was recently added, changed, or deleted.
3. **Recent Commits**: Run `git log -n 5` to inspect recent commits on this branch. This helps pin down the exact "previous implementation" changes that may have introduced the issue.

---

## Step 3 — Historical Context Lookup (Transcripts & Brain)

**Step 3 Exit Bound:** Locate the exact commit or conversation turn that introduced the failing code (`git log -S'<symbol>'` or transcript search). Extract the original design requirements before drafting the fix plan in Step 4.

Inspect the conversation history and commit log to reconstruct the original intent:

1. **Identify Current Conversation ID**: under Antigravity, it is in `<user_information>`. Under Claude Code, it is the session UUID: the newest `~/.claude/projects/<workspace-slug>/*.jsonl`, or the UUID in the scratchpad path when the system prompt names one.
2. **Search Transcripts**: **Transcript location depends on the host IDE:**

| Host | Transcripts |
|---|---|
| Claude Code | `~/.claude/projects/<workspace-slug>/<session-id>.jsonl` — one file per session, slug is the workspace path with `/` replaced by `-` (e.g. `-Users-snuffish-Projects-GR`) |
| Antigravity | `<app_data_dir>/brain/<conversation-id>/.system_generated/logs/transcript.jsonl` |

Check which exists before searching; do not assume.
3. **Locate Key Symbols/Files**: Run a recursive search over the transcripts for the active filenames, function names, or error messages:

   ```bash
   # Claude Code
   grep -rnwi "<symbol_or_filename>" ~/.claude/projects/<workspace-slug>/

   # Antigravity
   grep -rnwi "<symbol_or_filename>" ~/.gemini/antigravity-ide/brain/
   ```

4. **Trace the Implementation Logic**:
   - What did the user request in previous turns or conversations?
   - What implementation plan was approved?
   - What logic did the previous agent try to build? Did it make assumptions about API schemas, hooks, or parameters that are now failing?

---

## Step 4 — Verify Symbol Definitions & Mismatches

Errors commonly stem from structural mismatches between components. Perform the following checks:

1. **API / DTO Synchronization**: compare the client's requests with the server's models: the client's data-fetching layer or generated API client against the endpoints it calls. Check that field names, casing and types match (e.g. a GUID typed as `Guid` on one side and `number` on the other).
2. **Validation Schema vs Domain Entity**: compare the client's validation schema with the server's validation rules and the persisted entity (required fields, max lengths, allowed values).
3. **Imports & Aliases**: check imports, path aliases and package entry points against the project's conventions. The project's Profile and pattern skills name the concrete layers, aliases and contract touchpoints (`core` › *Codebase investigation* › *Cross-Layer Mapping*).

---

## Step 5 — Root Cause Analysis & Plan Formulation

Consolidate your findings into a structured Diagnostic report:

1. **Symptom**: The error message and behavior.
2. **Root Cause**: Why did this error occur? (e.g., "A previous change in `use-matching-ticket-draft.ts` modified the returned tuple but did not update the usage in `draft-controller.tsx`").
3. **Historical Decision**: Any relevant design choice from past conversations.
4. **Proposed Fix**: The exact code changes required to resolve the issue.

---

## Step 6 — Implement the Fix via Planning Mode

When preparing to apply the fix:

1. **Enter Planning Mode**: You **MUST** document the changes in `<prefix>-implementation_plan-<suffix>.md` first.
2. **Request User Feedback**: under Antigravity, set `UserFacing = true` and `RequestFeedback = true` in the plan's `ArtifactMetadata`, so the plan opens for review. Under Claude Code, link the plan and its sections in the chat response (`artifact-protocol`) and ask for approval there.
3. **Halt for Approval**: Do not edit any files in the workspace until the user explicitly approves.
4. **Verify**: Run tests and build checks after editing to ensure the problem is fully resolved.
