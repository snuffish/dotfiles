---
name: problem
description: Triggered when the user reports an error, bug, or compiler/lint/test failure, particularly from a previous implementation. Audits git status, recent changes, logs, active file context, and previous conversation transcripts to diagnose issues and plan a fix.
---

# Skill: `/problem` — Troubleshooting, Diagnostics & Context Recovery

Use this skill whenever the user reports an error (compiler error, lint error, failing test, runtime exception, logic bug) or states that something in a previous implementation is not working.

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

To understand the original intent, design decisions, and requirements of the code that is failing, you must inspect the conversation history:

1. **Identify Current Conversation ID**: Locate the conversation ID in `<user_information>`.
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

1. **API / DTO Synchronization**: Compare frontend requests and backend models.
   - Frontend RTK Query endpoints (`src/store/api/endpoint-builders/`) vs Backend controllers/endpoints.
   - Check if response field casing or types (e.g. `Guid` vs `string`, casing of keys) match.
2. **Validation Schema vs Domain Entity**: Compare frontend validation schemas (e.g. Zod validators) with backend validation rules (e.g. FluentValidation rules) and the EF entities.
3. **Imports & Aliases**: Check imports, path aliases (e.g. `~api`, `~components`), and library namespace dependencies. Ensure third-party package conventions are strictly followed (e.g., import `zod/v4` instead of `zod`).

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

1. **Enter Planning Mode**: You **MUST** document the changes in `implementation_plan.md` first.
2. **Request User Feedback**: Set `UserFacing = true` and `RequestFeedback = true`.
3. **Halt for Approval**: Do not edit any files in the workspace until the user explicitly approves.
4. **Verify**: Run tests and build checks after editing to ensure the problem is fully resolved.
