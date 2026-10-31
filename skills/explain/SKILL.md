---
name: explain
description: "Explains code, PR review comments, complex expressions, architecture patterns, or design intent across the codebase. Supports fast, concise in-chat explanations (/explain) and `deep`, which researches the three explanation axes (Mechanism, Rationale, Context) in parallel sub-agents and writes a workspace-root artifact (/explain deep)."
---

# Skill: `/explain` — Code, Architecture & Intent Explanation

Explains code, methods, PR/code review comments, architectural design choices, or system behaviors in two modes (no intermediate mode; "explain in detail/depth" is `/explain deep`):
1. **`/explain` (Default — Simple & Fast)**: Focused in-chat explanation of the immediate enclosing scope and direct symbols; writes no artifact.
2. **`/explain deep` (In-Depth, parallel)**: Researches *Mechanism*, *Rationale*, and *Context* in three isolated parallel sub-agents and aggregates into `<prefix>-explanation-<suffix>.md`.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-explanation-<suffix>.md` in `/explain deep` only (suffix derived from the target symbol, question, or topic); bare `/explain` writes no artifact
- `../_modules/pr-counterpart.md`
- `../_modules/fan-out.md` (`deep` mode)

On-demand references (`references/`):
- [`references/deep-axes.md`](references/deep-axes.md) — sub-agent axis briefs and artifact structure for `/explain deep`

---

## 1. Axes & Neighbor Routing

The three axes every `deep` explanation covers, one sub-agent each:
- **Mechanism** — what the code does: call and data flow at head, step by step with `path:line`, state machines, transactions, filters, and failure paths.
- **Rationale** — why it is the way it is: git history, PR descriptions/threads, work items, ADRs, comments stating constraints, and rejected alternatives.
- **Context** — who depends on it: callers and consumers across layers/repos, contracts (*Contract touchpoints*), pinning tests, and what would break if it changed.

Suggest `deep` in chat (never switch silently) when a bare `/explain` target spans both repos or >5 files, or when the question is a "why" answered in history.

| Situation | Use instead |
|---|---|
| Research with options and a confidence ledger *before* a change | [`/investigate`](../investigate/SKILL.md) |
| Judging a diff, not understanding it | [`/code-review`](../code-review/SKILL.md) |
| Finding what a design has overlooked | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |
| Writing documentation for other readers | [`code-documentation`](../code-documentation/SKILL.md) |

---

## 2. Mode 1: `/explain` — Simple & Fast (Default)

- **No artifact written**: read only the immediate target lines and enclosing scope; avoid multi-step searches or git history unless an unknown symbol blocks comprehension.
- **In-chat structure** (readable in ~30 seconds): **What it is** (1–2 plain-English sentences) + **What it does / Why it is here** (2–4 concise bullets), with clickable file/symbol links (`artifact-protocol` › *Host-Specific Link Formats*).

---

## 3. Mode 2: `/explain deep` — In-Depth, Parallel Axes

1. **Resolve the target first** (`fan-out` › *Brief contract*): exact symbols, files and line ranges, repo(s), head SHA (`git rev-parse --short HEAD` + dirty check), related workspace-root artifacts, and any PR counterpart (`pr-counterpart` › *Counterpart discovery*).
2. **Spawn the three axis sub-agents in parallel** per `fan-out` and [`references/deep-axes.md`](references/deep-axes.md).
3. **Verify & aggregate** (`fan-out` › *Aggregation*): write `<prefix>-explanation-<suffix>.md` at the **workspace root** using the structure in [`references/deep-axes.md`](references/deep-axes.md). Highlight any disagreement between axes (e.g. Rationale cites a constraint that Mechanism shows the code no longer honours).
4. **Report in chat**: a 1–2 sentence **TL;DR**, the `artifact-protocol` › _Chat link block_ with real section line numbers (`grep -n`), the mode (`deep`) and head SHA, and 2–3 takeaways without duplicating the document.
