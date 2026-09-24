---
name: explain
description: Explains code, PR review comments, complex expressions, architecture patterns, or design intent across the codebase. Supports fast, concise explanations (/explain) and comprehensive, deep-dive artifact generation (/explain detailed).
---

# Skill: `/explain` — Code, Architecture & Intent Explanation

Explains code, methods, PR/code review comments, architectural design choices, or system behaviors. Operates in two distinct modes based on the user's invocation:

1. **`/explain` (Default — Simple & Fast)**: Direct, clear, and concise in-chat explanation. Zero artifact overhead, minimal latency.
2. **`/explain detailed` (In-Depth)**: Comprehensive deep-dive covering cross-layer tracing, git history, and design tradeoffs, backed by a dedicated workspace-root artifact.

---

## 1. Invocation Modes & Gating

| Command | Output Location | Research Scope | Target Latency |
| :--- | :--- | :--- | :--- |
| **`/explain`** (bare or with code target) | Direct in-chat response (no artifact written) | Focused: immediate enclosing function/type & direct symbols | **Fast** (minimal tool calls, immediate response) |
| **`/explain detailed`** (or "explain in depth/detail") | Workspace-root artifact (`<prefix>-explanation-<suffix>.md`) + chat summary | Comprehensive: symbol definitions, cross-layer flow, git log context | **Thorough** (deep multi-step investigation) |

---

## 2. Mode 1: `/explain` — Simple & Fast (Default)

Use when the user runs `/explain` (without "detailed"), asks "explain this", or asks for a quick breakdown.

### Operating Standards:
- **No Artifact Created**: Do **NOT** write an explanation file to disk. Keep execution fast and lightweight.
- **Fast Focused Investigation**:
  - Read only the immediate target lines and enclosing scope.
  - Avoid heavy multi-step searches, git blame/log commands, or full cross-layer audits unless an unknown symbol prevents basic comprehension.
- **In-Chat Response Structure**:
  - **What it is**: 1–2 sentences explaining the symbol, prop, or expression in plain English.
  - **What it does / Why it is here**: 2–4 concise bullet points explaining the mechanism and purpose in the component.
  - Use clickable file and symbol links (`[Symbol](file:///path/to/file.tsx#L123)`).
  - Keep the whole answer readable in 30 seconds.

---

## 3. Mode 2: `/explain detailed` — In-Depth Analysis

Use when the user specifies `/explain detailed`, asks to "explain in detail/depth", or asks for an exhaustive architectural breakdown.

### Operating Standards:
- **Target Artifact**: `<prefix>-explanation-<suffix>.md` at the **workspace root** (where `<prefix>` is `<host>-<model>-`, e.g. `antigravity-gemini-3.8-flash-` or `claude-sonnet-3.7-`).
- **Anti-Overwrite Rule**: Always include the active AI model in `<prefix>` and append a descriptive kebab-case `<suffix>` derived from the target symbol, question, or topic. Never write unsuffixed or un-modeled generic files.
- Adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.

### Deep Investigation Pass:
1. **Surrounding Context & Symbol Definitions**:
   - Trace referenced classes, records, interfaces, and helper functions across layers.
   - Inspect backend endpoints, DTOs, or frontend store slices/hooks that interact with the target.
2. **Context Recovery (Git & History)**:
   - Check `git log -n 5 -p <file>` or PR history to understand recent intent, past bug fixes, or design compromises.
3. **Write the Dedicated Artifact**:
   - Write `<prefix>-explanation-<suffix>.md` at the **workspace root** containing:
     - **Executive Summary / Core Concept**.
     - **Technical Call Flow & Architecture** (with Mermaid diagrams where useful).
     - **Step-by-Step Technical Walkthrough** with clickable links to source files and line ranges.
     - **Design Rationale & Tradeoffs** (performance, security, UX, failure modes).
     - **Edge Cases & Reviewer Insights**.
4. **Report Back in Chat**:
   - Provide a 1–2 sentence **TL;DR**.
   - Provide a clickable link to open the artifact in the IDE:
     - Antigravity IDE: `📄 [antigravity-<model>-explanation-<suffix>.md](file://<workspace-root>/antigravity-<model>-explanation-<suffix>.md)`
     - Claude Code: `📄 [claude-<model>-explanation-<suffix>.md](claude-<model>-explanation-<suffix>.md)`
   - Provide clickable anchor links to key sections in the artifact.
   - Highlight 2–3 critical takeaways without duplicating the full document.
