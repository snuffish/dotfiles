# Investigation Artifact Template (`<prefix>-investigation-<suffix>.md`)

Written in the artifact dir (`artifact-protocol`) via `artifact-protocol` › _Claim_ only under `--file` or `--deep`.

```markdown
<!-- artifact-owner: … -->

# Investigation: <Topic Name>

**Goal:** <One-sentence restatement of user goal>  
**Scope:** <Repositories, microservices, domains, or directories touched; `--scope` paths when given>  
**Source:** <`--from` PR / work item link, or "topic"> · **Read from:** <live checkout | snapshot `<ref>@<short-sha>`> · **Flags:** <as invoked>  
**Status:** Complete | Blocked on open questions  
**Date:** <YYYY-MM-DD>

---

## 1. Questions Answered

1. **<Question 1>?** → <Direct, concise answer with source citation>
2. **<Question 2>?** → <Direct, concise answer with source citation>

---

## 2. Executive Summary (TL;DR)

- <Key finding 1: current state truth>
- <Key finding 2: primary constraint or contract>
- <Key finding 3: recommended architectural direction>

---

## 3. Current-State Architecture & Code Map

<Walkthrough of the active implementation, including data flow, call sequences, and file links.>

<One visual of the flow, per `references/visuals.md`: a Mermaid sequenceDiagram or a call tree.>

| Component / Layer     | Source Location          | Responsibilities                             |
| --------------------- | ------------------------ | -------------------------------------------- |
| Controller / Endpoint | `path/to/File.cs:L20`    | Handles request dispatch and validation      |
| Domain Service        | `path/to/Service.cs:L45` | Business invariants and transaction boundary |

---

## 4. Prior Art & Reference Patterns

- **Primary Reference**: `path/to/SiblingFeature.cs:L30` — cleanest pattern to mirror.
- **Pattern Inconsistencies**: <Notes on legacy vs modern patterns if both exist in the repo.>

---

## 5. Constraints & Contracts

| Constraint Category | Impact / Requirement                          | Source Evidence             |
| ------------------- | --------------------------------------------- | --------------------------- |
| Schema & Migration  | Requires non-nullable column backfill         | `src/Db/Migration.cs:L12`   |
| Cross-Service API   | Downstream consumer expects fixed JSON format | `src/Contracts/Event.cs:L8` |

---

## 6. Blast Radius

- **Direct Callers**: <List of calling methods/components with file links>
- **Shared State / Persistence**: <Tables, caches, or stores affected>
- **Existing Test Coverage**: <Paths to unit/integration test suites, or "None found">

---

## 7. Options & Trade-offs

### Option A: <Name> (Recommended)

- **Concept:** <One-sentence summary>
- **Pros:** ...
- **Cons:** ...
- **Follows:** `path/to/Reference.cs`

<A `diff` of the call tree, state flow, or file tree this option changes, per `references/visuals.md`.>

### Option B: <Name>

- **Concept:** <One-sentence summary>
- **Pros:** ...
- **Cons:** ...
- **Follows:** ...

**Recommendation:** <Why Option A is selected over alternatives.>

---

## 8. Blind Spots & Critical Omission Analysis (What Am I Missing?)

<Under `--no-blindspot`: the single line "_Not run (`--no-blindspot`). Re-run without it, or `/what-am-I-missing` on the recommended option._" and nothing else in this section. Otherwise embed the sections from `../../what-am-I-missing/references/artifact-template.md` (`### 🎯 The #1 Most Important Thing You Are Missing`, `#### 💥 The Failure Scenario`, `#### 🔍 Secondary Blind Spots & Nuances`, `#### 🛠️ Actionable Recommendation`).>

---

## 9. Confidence Ledger

| Finding / Assumption                     | Level       | Evidence / Verification Method                            |
| ---------------------------------------- | ----------- | --------------------------------------------------------- |
| Existing handler uses optimistic locking | ✅ Verified | `src/Handlers/OrderHandler.cs:L55`                        |
| Legacy background job runs every 15 mins | 🟡 Inferred | Cron schedule in `appsettings.json`, needs runtime check  |
| Third-party API rate limits for webhook  | ❓ Unknown  | External vendor docs needed; non-blocking for scaffolding |

---

## 10. Plan Seed

<High-level structural outline for /plan to build upon. No phases, no task lists, no code snippets.>

- 1. Define domain contracts and event schemas adhering to Option A.
- 2. Add database schema migration with backward-compatible defaults.
- 3. Implement business handler mirroring prior art in `SiblingFeature.cs`.
- 4. Wire client state hook and update frontend component.

---

## 11. Open Questions for User

<Decisions that belong exclusively to the user, or genuine blockers. Leave empty if none.>

- **<Question 1>?**
  - **Rec:** <Concise recommended choice and rationale>
- **<Question 2>?**
  - **Rec:** <Concise recommended choice and rationale>
```
