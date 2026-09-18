---
name: core
description: Universal root operating standards, golden invariants, execution gates, artifact protocols, and codebase investigation principles for all skills across Claude Code, Antigravity IDE, and other AI coding assistants.
---

# Skill: `core` — Root Operating Standards & Baseline Invariants

The foundational operating system and rulebook for all skills in this repository. All general and project-scoped skills derive from and adhere to the standards defined here.

---

## 1. Golden Operational Invariants (Zero-Tolerance Rules)

Every skill and agent workflow must strictly enforce these invariants:

1. **Truth in Code (No Guesswork or Speculation)**:
   - Never assume symbol definitions, types, route signatures, or library capabilities from names alone.
   - Always trace real source definitions, database models, and active configuration before explaining, designing, or modifying code.
   - When diagnosing issues or evaluating architecture, inspect recent git history (`git log -p`, `git diff`) and conversation context.

2. **Non-Destructive Work**:
   - Never delete or modify unrelated user changes, existing test suites, or configuration files without explicit instruction.
   - Maintain documentation integrity: preserve all existing comments, docstrings, and architectural rationales unless directly related to requested refactoring.

3. **High-Signal Chat & Minimal Noise**:
   - Keep chat responses concise, structured, and focused on key decisions, findings, and immediate next actions.
   - Offload deep analysis, exhaustive reviews, implementation plans, and diagnostics into dedicated workspace markdown artifacts.
   - Never let that analysis leak into source comments. A comment is documentation for the next reader, never a message to the user or a defence of a decision — keep it slim, technical, and about the code.

4. **TypeScript Convention (Prefer `type` Before `interface`)**:
   - In all TypeScript code, always prefer `type` over `interface` for props, state, payloads, and domain objects (`type ComponentProps = { ... }`, not `interface ComponentProps`).
   - Reserve `interface` strictly for third-party declaration merging or framework-mandated abstractions.

---

## 2. Safety & Execution Gates

To prevent accidental regressions and unapproved mutations:

### 2.1 Planning Mode First
- For non-trivial modifications, refactorings, or new features, **always formulate an implementation plan first**.
- Save the plan as `<prefix>-implementation_plan-<suffix>.md` at the **workspace root** and request user approval before modifying code.

### 2.2 The `/proceed` Gate (Strict Read-Only Invariant)
- Read-only research, evaluation and diagnostic skills (`/investigate`, `/review`, `/code-review`, `/pr-feedback-review`) must **never** execute code modifications, stage commits, run migrations, or auto-implement changes during or immediately after the evaluation.
- Execution is locked until the user explicitly issues the command:
  ```text
  /proceed
  ```
- Even if a plan or review is flawless, **never auto-proceed without explicit authorization**.

### 2.3 Mandatory Post-Edit Verification
- After editing code, never assume success. Always run targeted verification (relevant unit tests, integration tests, type checks, or build commands).
- If tests or builds fail, diagnose and fix the issue before claiming completion.

---

## 3. Universal Artifact & Link Protocol

All skills creating or referencing workspace markdown documents must strictly adhere to the **[artifacts](../artifacts/SKILL.md)** protocol:

1. **Host & AI-Model Prefix Resolution**:
   - The `<prefix>-` of every artifact MUST include **both the active host and the actual AI-model**: `<host>-<model>-`
   - **Host indicator**: `antigravity` (Antigravity IDE), `claude` (Claude Code), or standalone/other.
   - **AI-Model slug**: The slugified active model name:
     - Under **Antigravity IDE**: Derived from active model selection/metadata (e.g. `gemini-3.8-flash`, `gemini-2.5-pro`, fallback `gemini`). Example prefix: `antigravity-gemini-3.8-flash-`
     - Under **Claude Code**: Derived from environment (`ANTHROPIC_MODEL`) or CLI/session model (e.g. `sonnet-3.7`, `sonnet-3.5`, `opus-4`, fallback `sonnet`). Example prefix: `claude-sonnet-3.7-`
     - Standalone / Other: Model slug directly (e.g. `gemini-3.8-flash-`, `gpt-4o-`) or `<host>-<model>-`.
   - Write all artifacts directly to the **workspace root** to ensure IDE clickability.
2. **Contextual Suffix Rule (Anti-Overwrite Invariant)**:
   - **Always append a descriptive kebab-case suffix (`-<suffix>`)** to every generated artifact (e.g. `-18176-verksamhetsobjekt`, `-begar-prefix`, `-draft-close-dialog`).
   - **Never generate unsuffixed generic artifacts** (such as bare `antigravity-code_review.md` or `claude-implementation_plan.md`). A generic filename causes concurrent agents, subsequent sessions, or subagents to silently overwrite previous artifacts.
   - Suffix derivation priority:
     a. **Work Item / PR / Ticket ID + Slug**: e.g. `-18176-verksamhetsobjekt`, `-29982-verksamhetsobjekt`, `-1480-009204`.
     b. **Branch or Topic Slug**: e.g. `-begar-prefix`, `-new-users-audit`.
     c. **Task / Problem Descriptor**: 2–4 kebab-case words describing the specific objective.
3. **Chat Link Formats**:
   - **Antigravity IDE**: `[<prefix>-<artifact>-<suffix>.md](file://<workspace-root>/<prefix>-<artifact>-<suffix>.md#L<line>)` (absolute URI with `file://` scheme).
   - **Claude Code**: `[<prefix>-<artifact>-<suffix>.md](<prefix>-<artifact>-<suffix>.md#L<line>)` (workspace-relative path without scheme).
4. **Section Anchors**:
   - Chat links must use `#L<line>` line numbers obtained via `grep -n '^#\{1,3\} ' <file>`.
   - Intra-document links inside markdown files must use HTML anchors `<a id="..."></a>` and semantic `#anchor` targets.

---

## 4. Codebase Investigation Protocol

When investigating, explaining, refining, or troubleshooting:

1. **Trace Enclosing Scope & Call Lifecycles**:
   - Inspect the enclosing class, method, endpoint, or component lifecycle rather than inspecting isolated lines.
2. **Cross-Layer Mapping**:
   - Backend $\leftrightarrow$ Frontend: Check DTO synchronization, route paths, payload serialization, and client hooks (e.g. RTK Query).
   - Domain $\leftrightarrow$ Persistence: Check EF Core mappings, migrations, foreign keys, and validation rules.
3. **Historical Transcripts & Brain Lookup**:
   - Search past conversations and transcripts (`.system_generated/logs/transcript.jsonl` in Antigravity or `~/.claude/projects/` in Claude Code) to align with past user decisions and architectural consensus.

---

## 5. Skill Hierarchy & Precedence Model

When multiple skills and rules apply to a task, instructions resolve in the following order of precedence (highest to lowest):

1. **Workspace Rulebooks** (`CLAUDE.md` / `GEMINI.md` / `.agents/rules/`):
   - Strict repository-level instructions, project constraints, and local overrides.
2. **Project-Scoped Skills** (`Projects/<Project>/...`):
   - Domain-specific conventions (e.g., `backend-fastendpoints`, `backend-ef-core`, `frontend-rtk-query`).
3. **Tech & Language Skills** (`modern-csharp`, `manual-testing`, etc.):
   - General language idioms and testing patterns.
4. **Root Operating Standard** (`core` & `artifacts`):
   - Foundational operational discipline, safety gates, and communication protocols.

---

## 6. How Skills Derive From `core`

Any child skill declaring operational standards should include a header block referencing `core`:

```markdown
## Operating Standards & Invariants
This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **Target Artifact**: `<prefix>-<artifact_name>-<suffix>.md` at the **workspace root**.
```
*(For nested project skills under `Projects/<Project>/`, use relative path `../../core/SKILL.md`).*
