---
name: refine
description: Triggered by /refine or requests to find odd behaviors, code smells, or improvements. Uses previous conversation history and transcripts to align with past decisions.
---

# Skill: `/refine` — Code Refinement & Historical Alignment

This skill provides a systematic workflow for auditing code, finding odd behaviors, identifying design/performance improvements, and aligning changes with the historical context of previous conversations in this repository.

Instead of defining standalone guidelines, this skill **composes and delegates to existing project-specific skills** to ensure consistent rules are applied.

---

## 1. Triggering & Purpose

This skill is invoked when:

- The user uses the `/refine` command or requests to "refine" a file, class, or feature.
- The user asks to find odd behaviors, improvements, or other weird stuff in the codebase.
- The agent needs to align its current coding tasks with past decisions, custom styles, or specific context recorded in previous conversations.

---

## 2. Phase 1: Context & Conversation History Lookup

Before proposing any refinement, you **MUST** investigate past conversation transcripts to see if the files, patterns, or errors have been discussed previously.

### Step-by-Step Search Protocol

1. **Identify Conversation ID**: The current conversation ID is available in the `<user_information>` block. All transcripts are stored in `<app_data_dir>/brain/<conversation-id>/.system_generated/logs/transcript.jsonl`.
2. **Scan the Brain Directory**: Run recursive `grep` commands on `<app_data_dir>/brain/` using terminal commands (e.g., `run_command` with `grep`) to search for references to the target code being refined:
   - The names of files, classes, methods, or components you are currently auditing/refining.
   - Specific keywords, APIs, or error messages related to the code.
   - Generic search command (replace `<target_name_or_keyword>` with your active file or search term):

     ```bash
     grep -rnwi "<target_name_or_keyword>" <app_data_dir>/brain/ --exclude-dir=node_modules
     ```

3. **Analyze Past Transcripts**:
   - Locate the folder of relevant past conversations.
   - Use `grep -C 5` or `head`/`tail` to examine the steps (`USER_INPUT`, `PLANNER_RESPONSE`) inside `transcript.jsonl` or `transcript_full.jsonl`.
   - Identify:
     - What was the problem?
     - Why did the user prefer a specific approach? (e.g., did they ask to "skip format", avoid a certain package, or enforce a specific naming convention?)
     - What was the final accepted fix?

---

## 3. Phase 2: Delegating to Existing Skills (Guideline Reuse)

For auditing criteria and guidelines, **DO NOT** reinvent the rules. Instead, dynamically load and consult the active skills in the local registry that match the project, language, and frameworks you are currently refining:

### General & Review Guidelines

- **Code Review Standards**: Load and read [code-review](../code-review/SKILL.md) to reuse the diff-gathering strategy, key review dimensions (Correctness, Security, Readability), and severity definitions (🔴 Critical, 🟡 Important, 🟢 Minor).

### Project & Tech-Specific Guidelines

- Identify the languages, frameworks, and architecture used by the target files (e.g. C#/.NET, TypeScript/React, SQL, Python, etc.).
- Scan the registered active skills (including project-scoped skills under `Projects/` directories in the registry) and load the ones relevant to the target files (e.g. data access, forms, styling, endpoint conventions, and unit tests).
- Follow the loaded standards exactly to detect patterns, code smells, or deviations.

---

## 4. Phase 3: Formulating the Refinement Plan

After completing the analysis and cross-referencing with both the history and existing skills, present your findings to the user:

1. **Problem/Odd Behavior**: What is weird, inefficient, or buggy.
2. **Historical Context / Skill Link**: Cite the conversation ID or specific referenced skill that informs this finding.
3. **Why it Matters**: The impact (e.g., memory allocations, database locks, test failure).
4. **Refined Solution**: A clean, proposed code diff showing how to fix it.

## 5. Mandatory Planning Mode Workflow

When proposing or implementing refinements, you **MUST ALWAYS** enter `Planning Mode` before modifying any source code files. Follow this sequence:

1. **Create the Implementation Plan**: Document your findings, historical context, and proposed modifications in the `implementation_plan.md` artifact (saved under the active conversation directory `<app_data_dir>/brain/<conversation-id>/implementation_plan.md`).
2. **Request Feedback**: Set `UserFacing = true` and `RequestFeedback = true` in the plan's `ArtifactMetadata`.
3. **Halt for Approval**: Stop and wait for the user's explicit approval/feedback on the proposed changes. Do not modify any code files in the workspace until the plan is approved.
4. **Execute**: Once the user approves, proceed to edit the files and implement the refinements.
