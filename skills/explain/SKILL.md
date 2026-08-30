---
name: explain
description: Deeply explains code, PR review comments, complex expressions, architecture patterns, or design intent across the codebase by tracing symbols, investigating project conventions, and checking conversation/git history.
---

# Skill: `/explain` — Deep Code, Architecture & Intent Explanation

Use this skill whenever the user asks to explain a piece of code, a method, a PR/code review comment, an architectural design choice, an error, or the underlying intent behind a system behavior.

---

## Core Philosophy

A great explanation is not a simple restatement of what the code lines do syntactically. It connects:

1. **What the code is doing** (technical mechanism & symbol definitions).
2. **Why it is done this way** (underlying rationale, constraints, security, performance, or architecture patterns).
3. **What a reviewer or author actually meant** (translating feedback or high-level comments into concrete choices, tradeoffs, and actionable code).

---

## Step 1 — Identify the Target & Question Scope

Identify the exact subject of the inquiry:

- **Specific Code/Expression**: A line range, LINQ query, expression tree, async pipeline, or generic pattern.
- **Reviewer / Team Feedback**: A PR comment, issue comment, or review feedback (e.g. *"Explain what Daniel actually means"*).
- **Architectural / Flow Question**: How a feature works end-to-end between Frontend, Backend, Database, and Worker.
- **"Why" Question**: Why a specific restriction, workaround, or design was implemented.

---

## Step 2 — Trace Real Code & Symbol Definitions (No Guesswork)

**Never guess based on names alone.** Always investigate the real codebase before explaining:

1. **Surrounding Context**: Inspect the full enclosing method, class, or component to understand call conditions and lifecycles.
2. **Definition Tracing**:
   - Trace referenced classes, records, interfaces, and extension methods (e.g. use `grep_search` or `view_file` to find `.Within()`, `EffectiveActions`, `IProfileMetadata`).
   - Check enum definitions, constant groups, and configuration options.
3. **Cross-Layer Mapping**:
   - If explaining a Backend DTO/Endpoint: check how the Frontend consumes it (RTK Query hooks, pages, components).
   - If explaining a Frontend Component: check where data originates (API endpoints, store slices, custom hooks).

---

## Step 3 — Context Recovery (Git & History)

When the question involves recent changes, intent, or review feedback:

1. **Git Context**: Run `git log -n 5 -p <file>` or `git diff` to understand what was recently added, changed, or removed.
2. **Conversation & Decision History**:
   - If diagnosing why code was written or what past consensus was reached, search past transcripts in `<app_data_dir>/brain/` or check knowledge items.
3. **Project Rulebook / Skill Alignment**:
   - Consult relevant project skills (e.g. `backend-ef-core`, `backend-fastendpoints`, `backend-dry`, `frontend-rtk-query`, `frontend-component-patterns`) to see if the pattern adheres to an official repository convention.

---

## Step 4 — Formulate the Explanation & Generate Artifact

1. **Write the Explanation Artifact**:
   - Always create a dedicated markdown artifact in the active conversation directory:
     `<appDataDir>/brain/<conversation-id>/explanation.md`
   - Use `write_to_file` with `ArtifactMetadata` (`UserFacing: true`, `RequestFeedback: false`, `Summary: "..."`).
   - The artifact must be thorough, clean, and well-structured using GitHub-flavored Markdown:
     - Title and context of the explained code/concept.
     - **Core Philosophy**: Explain both *what* it does and *why* it was designed that way.
     - **Step-by-Step Technical Breakdown**: Clear walkthrough with clickable links to source files and symbols (`[Symbol](file:///path/to/file#L10)`).
     - **Design Rationale & Tradeoffs**: Security, performance, consistency, and architecture principles.
     - **Edge Cases & Reviewer Insights**: Potential gotchas, alternatives, or translations of reviewer feedback where applicable.

2. **Report Back in Chat**:
   - In the conversation response, provide:
     - The **TL;DR / Core Takeaway** (1–2 sentences).
     - A direct, clickable link to open the artifact in the IDE:
       `📄 [explanation.md](file://<appDataDir>/brain/<conversation-id>/explanation.md)`
     - Direct anchor links to key sections in the artifact (e.g., `#technical-breakdown`, `#design-rationale--tradeoffs`).
     - A concise overview highlighting critical takeaways without re-dumping the entire artifact body.
