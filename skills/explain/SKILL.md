---
name: explain
description: Explains code, PR review comments, complex expressions, architecture patterns, or design intent across the codebase. Supports fast, concise in-chat explanations (/explain) and `deep`, which researches the three explanation axes (Mechanism, Rationale, Context) in parallel sub-agents and writes a workspace-root artifact (/explain deep).
---

# Skill: `/explain` — Code, Architecture & Intent Explanation

Explains code, methods, PR/code review comments, architectural design choices, or system behaviors. Operates in two distinct modes based on the user's invocation:

1. **`/explain` (Default — Simple & Fast)**: Direct, clear, and concise in-chat explanation. Zero artifact overhead, minimal latency.
2. **`/explain deep` (In-Depth, parallel)**: Comprehensive deep-dive backed by a dedicated workspace-root artifact. The three explanation axes — *Mechanism*, *Rationale*, *Context* — are each researched by an isolated parallel sub-agent and then aggregated, so the "how", the "why" and the "who depends on it" cannot blur into one another.

There is no intermediate mode. A request for "explain in detail/depth" or an exhaustive breakdown is `/explain deep`.

---

## 1. Invocation Modes & Gating

| Command | Output Location | Research Scope | Target Latency |
| :--- | :--- | :--- | :--- |
| **`/explain`** (bare or with code target) | Direct in-chat response (no artifact written) | Focused: immediate enclosing function/type & direct symbols | **Fast** (minimal tool calls, immediate response) |
| **`/explain deep`** (or "explain in depth/detail") | Workspace-root artifact (`<prefix>-explanation-<suffix>.md`) + chat summary; header names the mode and head SHA | Comprehensive: three parallel sub-agents, one per axis (see *Mode 2*) | **Thorough** (multi-step investigation, parallelised) |

The three axes every deep explanation covers, one sub-agent each:

- **Mechanism** — what the code does: the call and data flow at head, step by step, with `path:line` for every hop; state machines, transactions, filters, and the failure paths.
- **Rationale** — why it is the way it is: git history of the touched files, PR descriptions and review threads, work items, ADRs, comments that explain a constraint, alternatives that were rejected and why.
- **Context** — who depends on it: callers and consumers across layers and repos, contracts it participates in (cross-repo enums, OpenAPI shape, hub URLs), the tests that pin it, and what would break if it changed.

Suggest `deep` in the chat response (do not switch silently) when a bare `/explain` target turns out to span both repos or more than ~5 files, or when the question is a "why" whose answer lives in history rather than in the code.

---

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Research with options and a confidence ledger *before* a change | [`/investigate`](../investigate/SKILL.md) |
| Judging a diff, not understanding it | [`/code-review`](../code-review/SKILL.md) |
| Finding what a design has overlooked | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |
| Writing documentation for other readers | [`code-documentation`](../code-documentation/SKILL.md) |

---

## 2. Mode 1: `/explain` — Simple & Fast (Default)

Use when the user runs `/explain` (without `deep`), asks "explain this", or asks for a quick breakdown.

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

## 3. Mode 2: `/explain deep` — In-Depth, Parallel Axes

Use when the user specifies `/explain deep`, asks to "explain in detail/depth", or asks for an exhaustive architectural breakdown.

### Operating Standards:
- **Target Artifact**: `<prefix>-explanation-<suffix>.md` at the **workspace root** (where `<prefix>` is `<host>-<model>-`, e.g. `antigravity-gemini-3.8-flash-` or `claude-sonnet-3.7-`).
- **Anti-Overwrite Rule**: Always include the active AI model in `<prefix>` and append a descriptive kebab-case `<suffix>` derived from the target symbol, question, or topic. Never write unsuffixed or un-modeled generic files.
- Adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **Read-only**: no edits, no checkouts, no installs, builds or tests — for you and for every sub-agent.

### Orchestration

1. **Resolve the target yourself first**: the exact symbols, files and line ranges, the repo(s) involved, the head SHA (`git rev-parse --short HEAD`, and whether the tree is clean), and any PR / work item / earlier workspace-root artifact that already discusses the topic. Sub-agents must not re-discover the target.
2. **Spawn the three sub-agents in parallel** (one message, three calls). Each prompt includes: the repo path(s), the resolved target (`path:line` ranges), the head SHA, the list of related artifacts at the workspace root, and its axis brief.
   - **Mechanism** — "Trace what this code does at head, hop by hop: entry points, the call and data flow across layers, state transitions, transactions and query filters it runs under, and every failure path. Read whole files where needed. Cite `path:line` for each hop. Produce (a) a numbered walkthrough and (b) a Mermaid sequence or flow diagram source. Say what you could not confirm by reading. Under 700 words plus the diagram."
   - **Rationale** — "Explain why it is the way it is. Use `git log --follow -p` on the touched files, PR descriptions and review threads if a CLI is authenticated (`az repos pr list --source-branch`, `gh pr view`), linked work items, ADRs/docs, and comments that state constraints. Report: the decisions that shaped it, the alternatives that were considered or rejected and why, and any constraint that is no longer true. Quote the source (commit, thread id, doc) for each. Never infer intent from a branch name. Under 600 words."
   - **Context** — "Report who depends on it: callers and consumers across layers and repos (grep for the symbols, follow DI registrations), the contracts it participates in (cross-repo enum values, OpenAPI snapshot, SignalR hub URL, sv-SE text), the tests that pin its behaviour, and what would break if its signature or semantics changed. Flag anything in the workspace-root `CLAUDE.md` contracts list it touches. Under 500 words."
3. **Aggregate** into the single artifact (structure below). **Re-open every `path:line` the sub-agents cite** before it goes into the artifact — sub-agent output is evidence, not a verdict — and drop or mark as unconfirmed anything you cannot see yourself. Where two axes disagree (Rationale says a constraint exists, Mechanism shows the code no longer honours it), say so explicitly: that gap is usually the most useful sentence in the explanation.

### Artifact Structure

Write `<prefix>-explanation-<suffix>.md` at the **workspace root** containing, in this order:

- **Header**: target, repo(s), head SHA, mode (`deep`), related artifacts.
- **Executive Summary / Core Concept**.
- **Technical Call Flow & Architecture** (from *Mechanism*; Mermaid diagram where useful).
- **Step-by-Step Technical Walkthrough** (from *Mechanism*) with clickable links to source files and line ranges.
- **Design Rationale & Tradeoffs** (from *Rationale*: performance, security, UX, failure modes; each decision with its source).
- **Consumers & Contracts** (from *Context*: callers, cross-repo contracts, pinning tests, what breaks if it changes).
- **Edge Cases & Reviewer Insights** (from all three; include every axis disagreement found in aggregation).

### Report Back in Chat

- Provide a 1–2 sentence **TL;DR**.
- Provide a clickable link to open the artifact in the IDE:
  - Antigravity IDE: `📄 [antigravity-<model>-explanation-<suffix>.md](file://<workspace-root>/antigravity-<model>-explanation-<suffix>.md)`
  - Claude Code: `📄 [claude-<model>-explanation-<suffix>.md](claude-<model>-explanation-<suffix>.md)`
- Provide clickable anchor links to key sections in the artifact.
- Name the mode (`deep`) and the head SHA.
- Highlight 2–3 critical takeaways without duplicating the full document.
