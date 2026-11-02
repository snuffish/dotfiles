# `/explain --deep` — Sub-Agent Briefs & Artifact Structure

## Parallel Sub-Agent Briefs

Spawn the three read-only sub-agents in parallel (`fan-out` › *Brief contract*). Each prompt includes the repo path(s), the resolved target (`path:line` ranges), the head SHA, the list of related workspace-root artifacts, and its axis brief:

- **Mechanism** — "Trace what this code does at head, hop by hop: entry points, the call and data flow across layers, state transitions, transactions and query filters it runs under, and every failure path. Read whole files where needed. Cite `path:line` for each hop. Produce (a) a numbered walkthrough and (b) a Mermaid sequence or flow diagram source. Say what you could not confirm by reading. Report only what the aggregation needs: one entry per hop with its citation, nothing else."
- **Rationale** — "Explain why it is the way it is. Use `git log --follow -p` on the touched files, PR descriptions and review threads if a CLI is authenticated (`az repos pr list --source-branch`, `gh pr view`), linked work items, ADRs/docs, and comments that state constraints. Report: the decisions that shaped it, the alternatives that were considered or rejected and why, and any constraint that is no longer true. Quote the source (commit, thread id, doc) for each. Never infer intent from a branch name. Report only what the aggregation needs: one entry per decision with its citation, nothing else."
- **Context** — "Report who depends on it: callers and consumers across layers and repos (grep for the symbols, follow DI registrations), the contracts it participates in (shared enum values, an API snapshot or generated client, realtime hub or event names, user-facing text and its locale; the project's Profile lists them as *Contract touchpoints*), the tests that pin its behaviour, and what would break if its signature or semantics changed. Flag anything in the workspace-root `CLAUDE.md` contracts list it touches. Report only what the aggregation needs: one entry per dependent with its citation, nothing else."

## Artifact Structure (`<prefix>-explanation-<suffix>.md`)

Write at the **workspace root** via `artifact-protocol` › *Claim* containing, in this order:

1. **Header**: target, repo(s), head SHA, mode (`deep`), related artifacts.
2. **Executive Summary / Core Concept**.
3. **Technical Call Flow & Architecture** (from *Mechanism*; Mermaid diagram where useful).
4. **Step-by-Step Technical Walkthrough** (from *Mechanism*) with clickable links to source files and line ranges.
5. **Design Rationale & Tradeoffs** (from *Rationale*: performance, security, UX, failure modes; each decision with its source).
6. **Consumers & Contracts** (from *Context*: callers, cross-repo contracts, pinning tests, what breaks if it changes).
7. **Edge Cases & Reviewer Insights** (from all three; include every axis disagreement found in aggregation).
