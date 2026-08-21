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

## Step 4 — Formulate the Explanation

Structure the answer clearly using Markdown:

### 1. The TL;DR / Core Takeaway

State the direct answer in 1–2 crisp sentences without overwhelming jargon.

### 2. Step-by-Step Technical Breakdown

Break down the mechanics:

- Explain what each key variable, method, or symbol does.
- Format all file paths and symbols as clickable markdown links (`[ClassName](file:///path/to/file#L10)`).
- Highlight non-obvious details (e.g., expression tree limitations, memory allocation concerns, EF Core query compilation vs in-memory execution).

### 3. The "Why" (Design Rationale & Tradeoffs)

Explain the architectural motivations:

- **Security & Privacy**: (e.g., avoiding permission/data leakage).
- **Performance & Scalability**: (e.g., single-query projection vs N+1 queries, post-projection in-memory sorting).
- **Maintainability & DRY**: (e.g., decoupling DTOs via interfaces, reusing shared policies).

### 4. If Explaining Reviewer Feedback / Alternatives

Provide concrete options:

- **Option Breakdown**: What are the alternatives the reviewer is considering?
- **Tradeoffs**: Why is Option A preferred over Option B (or vice versa)?
- **Concrete Code Snippets**: Show minimal, idiomatic before/after code examples of how to implement the suggested change according to repository standards.
