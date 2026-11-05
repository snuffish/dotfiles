---
name: investigate
description: 'Read-only research before designing a change: traces symbols, maps call flows and blast radius, uncovers prior art and conventions, surfaces cross-layer constraints, weighs options and answers in chat with an evidence-backed confidence ledger. It includes the /what-am-I-missing blind-spot audit unless `--no-blindspot`, `--file` writes `<prefix>-investigation-<suffix>.md` for /plan, `--html` compiles rich standalone HTML and launches the browser, `--deep` runs the full protocol with the file; `--from <PR|work item>` frames it from a ticket, `--scope <path>` bounds it. Use for /investigate, "research this", "how does X work before we change it?", "what would it take to add Y?", "scope this out", "is this feasible?".'
argument-hint: "[--deep] [--no-blindspot] [--file] [--html] [--from <PR|work item>] [--scope <path>…] [/worktrees] <topic>"
---

# Skill: `/investigate` — Pre-Plan Research & Discovery

The dedicated reconnaissance pass executed **before** `/plan`. It replaces speculation with verifiable evidence, answering: _"What is actually true in this codebase today, what are our viable options, and what critical traps are we missing?"_

Every assertion is anchored to real code or quarantined as an unverified inference, includes the `/what-am-I-missing` blind-spot audit by default (unless `--no-blindspot`), and hands `/plan` an evidence foundation instead of a blank page. Plain runs answer in chat; `--file` and `--deep` also write the artifact in the artifact dir.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/fan-out.md`: _Speed fan-out_ for the research lanes (Steps 1.3–4) and _Review lenses_ for Step 6
- `../_modules/artifact-protocol.md`: writes `<prefix>-investigation-<suffix>.md` in the artifact dir (`artifact-protocol`) under `--file`, `--deep`, or `--html` (suffix e.g. `-draft-close-dialog`, `-municipality-sync`); under `--html`, compiles `<prefix>-investigation-<suffix>.html` via `render_html.py` and opens in browser; a plain run writes nothing

Read these only when their flag is given:

- `../_modules/pr-host.md` (`--from`): read-only, to resolve the PR or work item and its acceptance criteria
- `../_modules/git-worktrees.md` (`/worktrees`): snapshot mode, per `core` › _Worktree opt-in_

On-demand references (`references/`):
- [`references/artifact-template.md`](references/artifact-template.md) — template for `<prefix>-investigation-<suffix>.md` (`--file` / `--deep`)
- [`references/visuals.md`](references/visuals.md) — view selection and symbol-citation rules for diagrams and call trees
- [`references/lane-briefs.md`](references/lane-briefs.md) — the four research-lane briefs and their return format (Steps 1.3–4)

---

## Invariants

1. **Read-only:** never edit source code, scaffold files, stage git changes, run database migrations, or execute mutating commands. The only file this skill creates or modifies is `<prefix>-investigation-<suffix>.md`, and only under `--file` or `--deep`.
2. **No plan:** deliver current-state findings, architectural options, trade-offs, and a seed outline. Never draft task phases, step-by-step checklists, or `<prefix>-implementation_plan-<suffix>.md`. Solution architecture belongs to `/plan`.
3. **Cite every claim:** every factual claim about codebase behavior, interfaces, or types carries a precise `path:line` citation. Mark deductions explicitly as **Inferred** or **Unknown** (`core` › _Codebase investigation* › *Confidence Ledger*).
4. **No auto-proceed:** never roll directly from research into planning or implementation without explicit user authorization.

---

## 1. When to Use

| Objective / Context                                                                               | Correct Skill                                                                                          |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Deep-dive research, ground truth, options, and critical blind spots **before** designing a change | **`/investigate`** (this skill; includes the `/what-am-I-missing` audit unless `--no-blindspot`)       |
| Synthesizing gathered evidence into a phased task plan                                            | [`/plan`](../plan/SKILL.md)                                                                            |
| Explaining an isolated symbol, expression, error, or PR comment                                   | [`/explain`](../explain/SKILL.md)                                                                      |
| Diagnosing an active regression, failing test, or runtime crash                                   | [`/problem`](../problem/SKILL.md)                                                                      |
| Auditing an existing plan or pull request diff                                                    | [`/plan --review`](../plan/SKILL.md) (plans) or [`/code-review`](../code-review/SKILL.md) (diffs) |
| Standalone blind-spot audit of an already-chosen approach, plan, or diff                          | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md)                                                  |
| Another visual angle on a finished investigation (a different diagram, a diff, an HTML view)      | `/show-me` (`~/.agents/skills/show-me/`, user-invoked only; see [`references/visuals.md`](references/visuals.md)) |

---

## 2. Invocation Modes

### Case A: Bare Command (`/investigate` with no arguments)

1. **Locate Existing Investigation**: scan `<prefix>-investigation-*.md` in the artifact dir (`artifact-protocol`) and select the family per `artifact-protocol` › _Claim_ › _Readers & family selection_.
2. **If Found**: read real anchor line numbers (`grep -n '^#\{1,3\} ' <file>`) and render the `artifact-protocol` › _Chat link block_ with links to `Executive Summary (TL;DR)`, `Current-State Architecture`, `Options & Trade-offs`, `Blind Spots`, `Confidence Ledger`, `Plan Seed`, and `Open Questions for User`, plus `**Status:** Complete | Blocked on open questions`.
3. **If Not Found**: inform the user and prompt for the topic, module, or feature to investigate.

### Case B: Command With Instructions (`/investigate <topic>`)

| Flag                     | Effect                                                                                                                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| _(none)_                 | Steps 0–7, blind-spot audit included; answer in chat per §5 _Chat-only response_. No file                                                                                                              |
| `--no-blindspot`         | Skips Step 6, the blind-spot audit                                                                                                                                                                     |
| `--file`                 | Writes the §4 artifact and answers per §5 _Artifact response_                                                                                                                                          |
| `--html`                 | Writes the §4 markdown artifact, compiles its sibling `<prefix>-investigation-<suffix>.html` via `render_html.py`, launches the default browser, and links both in chat                                  |
| `--deep`                 | The full protocol: `--file` with the audit. With `--no-blindspot` it contradicts itself, so ask which applies                                                                                          |
| `--from <PR\|work item>` | Frames Step 0 from a PR or work item (URL, id, `#30342`). The topic becomes optional                                                                                                                   |
| `--scope <path>…`        | Bounds Steps 2–4 to these paths (repo, directory or package); see Step 0                                                                                                                               |
| `/worktrees`             | Reads a pinned snapshot instead of the live checkout (`git-worktrees` › _Snapshot Lifecycle_). With `--from <PR>`, the snapshot is the PR head, so the findings describe the PR, not your working tree |

Flags combine and their order does not matter. An unknown `--flag` is a question, not a guess.

---

## 3. The 8-Step Investigation Protocol

**Research lanes.** Steps 1.3, 2, 3 and 4 do not depend on each other. After Steps 0, 1.1 and 1.2, run them as four parallel lanes per `fan-out` › _Speed fan-out_ and [`references/lane-briefs.md`](references/lane-briefs.md): History (1.3), Prior art (2), Trace (3) and Blast radius (4). Each lane gets the Step 0 goal and questions, the `--scope` paths, the rulebooks and References loaded in 1.1, and the topology from 1.2. Then merge the lanes, re-open the load-bearing citations, and continue with Step 5 in the main context. Run the four steps inline instead when the change stays in one layer (Step 1.2 found no boundary) and Step 0 has at most 3 questions.

### Step 0 — Frame the Scope & Questions

0. **Intake (`--from` only)**: Resolve the PR or work item per `pr-host` › _Parse a PR or work-item URL_ and _Fetch the PR, its work items and acceptance criteria_ (a work item without a PR is fine; read the item and its parent). Derive the goal and questions from its title, description and acceptance criteria, and cite them. A failed fetch follows `pr-host` › _When a fetch fails_.
1. **Goal**: Restate the inquiry in one concise, unambiguous sentence.
2. **Core Questions**: Define 3–7 precise questions that must be resolved before a plan can be drafted.
3. **Done Condition**: Specify the clear boundary where investigation ends.
4. **Scope Boundary (`--scope` only)**: Steps 2–4 search and trace only under the given paths. Callers or contracts outside them are listed in Blast Radius as _outside scope_ with `path:line`, not traced further. Rulebooks (Step 1) are still read for the whole workspace.

### Step 1 — Orient & Recover Context

1. **Workspace Rulebooks & Project-Scoped Skills**: Check workspace rulebooks (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) and load relevant project Profiles and References per `core` › _Precedence_ (e.g. `priis-backend-dry`, `priis-frontend-rtk-query`).
2. **Repository Topology**: Determine if the change crosses repository or package boundaries (Backend API, Frontend SPA, Shared Contracts, Worker).
3. **Historical Decisions**: Follow `core` › _Codebase investigation_ › _Historical decisions_ (`git log`, claude-mem, and transcripts) to honor established decisions and cite the commit or code that proves them.

### Step 2 — Locate Prior Art & Reference Patterns

- Locate the nearest analogous implementation (sibling endpoint, form, domain event, migration) and read its flow across every layer.
- Identify competing patterns in the codebase and document which represents modern consensus and why.

### Step 3 — Trace Real Code Cross-Layer (No Guesswork)

Follow `core` › _Codebase investigation_ (*Navigation* via `.codegraph/` lean commands + grep for DI/wiring/enums/config, and *Cross-Layer Mapping* across API ↔ UI, Domain ↔ Storage, Runtime ↔ Config):
- Inspect enclosing class definitions, lifecycles, and middlewares—not isolated snippets.
- Locate existing unit and integration tests covering the flow; document any absence as a critical finding.

### Step 4 — Surface Contracts, Constraints & Blast Radius

- **Blast Radius**: Enumerate direct callers, downstream subscribers, consumers, and webhooks.
- **Data & Migration Risks**: Schema locks, breaking column drops, data backfills, or nullable transitions.
- **Third-Party & Network Boundaries**: External APIs, timeouts, fallback policies, and retry behaviors.
- **Auth & Access Control**: Role-based or tenant authorization gates protecting target pathways.

### Step 5 — Frame Architectural Options (Not the Plan)

Present 2–3 viable, contrasting implementation approaches with **Approach Summary**, **Trade-offs** (complexity, performance, blast radius, migration burden, reversibility), **Prior Art Reference**, and **Recommendation & Rationale**.

### Step 6 — Audit Blind Spots & Critical Omissions (skipped under `--no-blindspot`)

Under `--no-blindspot` the artifact's §8 says _Not run_ and the handoff offers a re-run without the flag or `/what-am-I-missing`.

Read [`../what-am-I-missing/references/vectors.md`](../what-am-I-missing/references/vectors.md) (stop and report the path if it cannot be read) and audit the recommended option against its **7 Universal Blindspot Vectors** as `fan-out` › _Review lenses_ (write the option and its cited code map to `<scratchpad>/lens-target.md` as the target), recording the fields defined in [`../what-am-I-missing/references/artifact-template.md`](../what-am-I-missing/references/artifact-template.md) (#1 Primary Blind Spot, Failure Scenario, Secondary Blind Spots, Actionable Recommendation).

### Step 7 — Assemble the Confidence Ledger

Classify every key finding into ✅ **Verified** (`path:line`), 🟡 **Inferred** (with how to verify), or ❓ **Unknown** (with owner and whether it blocks planning) per `core` › _Codebase investigation_ › _Confidence Ledger_.

---

## 4. Workspace Artifact Specification (`--file` / `--deep` / `--html`)

Read [`references/artifact-template.md`](references/artifact-template.md) and [`references/visuals.md`](references/visuals.md), and publish `<prefix>-investigation-<suffix>.md` in the artifact dir (`artifact-protocol`) via `artifact-protocol` › _Claim_:
- **No per-item inventories:** give the count, a table of the few that decide the options, and the command that regenerates the full list.
- **Cite, don't paste:** a `path:line` replaces a code excerpt; quote at most a few lines where the exact text is the finding.
- **HTML Compilation (`--html` only):** compile the sibling `.html` artifact via `render_html.py` (`artifact-protocol` › *HTML Export Pipeline*) and launch in the default browser.

---

## 5. Chat Response Protocol

Per `core` › _Golden invariants_, keep chat output concise and high-signal; every claim carries its `path:line`.

### Chat-only response (neither `--file` nor `--deep`)

1. **Headline**: 1–2 sentences with the most critical finding and primary direction, plus at most one visual per [`references/visuals.md`](references/visuals.md) when it earns its place.
2. **Questions Answered**: Step 0 questions, one line each with citation.
3. **Code Map**: compact table (component, `path:line`, role); list _outside scope_ dependencies on one line under `--scope`.
4. **Options**: numbered, recommended first, one line each with precedent; then recommendation and why.
5. **#1 Blind Spot** (unless `--no-blindspot`): bold sentence, trigger, and fix.
6. **Confidence Ledger**: 🟡 Inferred and ❓ Unknown rows only (with verification/owner) + count of ✅ Verified findings.
7. **Open Questions**: blocking user decisions.
8. **Handoff Line**: `**Next Step:** /plan <suffix> drafts a plan from these findings in this session; re-run with --file (or --deep) to keep them for a new session.`

### Artifact response (`--file`, `--deep`, or `--html`)

1. **Headline**: 1–2 sentences summarizing the critical finding and primary direction, plus at most one visual from the artifact (usually §3).
2. **Link block**: the `artifact-protocol` › _Chat link block_ with real line numbers (`grep -n '^#\{1,3\} ' <file>`) for `Executive Summary`, `Options & Trade-offs`, `Blind Spots`, `Confidence Ledger`, `Plan Seed`, and `Open Questions for User` (under `--html`, include sibling `🌐 [<artifact>.html](<host-link-to-html>)`).
3. **Primary Recommendation & #1 Blind Spot** (or note `--no-blindspot`) and **Open Questions**.
4. **Handoff Line**: `**Next Step:** Type /plan <suffix> to convert the Plan Seed into a detailed implementation plan, or /show-me <aspect> for another view of the findings.`

---

## 6. Pre-Handoff Quality Checklist

- [ ] Strictly read-only (no source edits, no implementation plan written) and explicit handoff presented without auto-proceeding.
- [ ] Every factual claim carries `path:line`, and 🟡 Inferred / ❓ Unknown rows in the Confidence Ledger name their verification method or owner.
- [ ] Flags honored (`--no-blindspot`, `--file` / `--deep`, `--scope`, `--from`, `/worktrees`), and Step 6 audited all 7 vectors from `../what-am-I-missing/references/vectors.md` unless `--no-blindspot`.
- [ ] Visuals and artifact format follow [`references/visuals.md`](references/visuals.md), [`references/artifact-template.md`](references/artifact-template.md), and `artifact-protocol` › _Chat link block_.
