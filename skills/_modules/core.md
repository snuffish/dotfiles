# core

Root operating standards for every Command in the Registry: the golden invariants, the execution gates, the investigation protocol and the precedence model. Depends on no other Module.

---

## Golden invariants

Every Command and agent workflow enforces these:

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

---

## Execution gates

To prevent accidental regressions and unapproved mutations:

### Planning mode first
- For non-trivial modifications, refactorings, or new features, **always formulate an implementation plan first**.
- Save the plan as `<prefix>-implementation_plan-<suffix>.md` at the **workspace root** and request user approval before modifying code.

### The `/proceed` gate
- A Command whose `## Modules` section marks its `core` line **read-only until `/proceed`** must **never** execute code modifications, stage commits, run migrations, or auto-implement changes during or immediately after the evaluation.
- Execution is locked until the user explicitly issues the command:
  ```text
  /proceed
  ```
- `/proceed` is the [`proceed`](../proceed/SKILL.md) Command. It is user-invoked only; a plain "proceed" or "go ahead" from the user counts the same.
- Even if a plan or review is flawless, **never auto-proceed without explicit authorization**.

### Post-edit verification
- After editing code, never assume success. Always run targeted verification (relevant unit tests, integration tests, type checks, or build commands).
- If tests or builds fail, diagnose and fix the issue before claiming completion.

### Worktree opt-in
- When the invocation's arguments contain `worktree`, `worktrees` or `/git-worktrees`, or a `[worktree-context]` block was handed in, read [git-worktrees.md](git-worktrees.md) (same folder as this file) and run under it, even if this Command does not list it.

---

## Codebase investigation

When investigating, explaining, refining, or troubleshooting:

1. **Trace Enclosing Scope & Call Lifecycles**:
   - Inspect the enclosing class, method, endpoint, or component lifecycle rather than inspecting isolated lines.
2. **Cross-Layer Mapping**:
   - When a change crosses a boundary (API ↔ client, domain ↔ persistence, service ↔ consumer), check both sides of the contract. The project's Profile and References name the concrete touchpoints.
3. **Historical Transcripts & Brain Lookup**:
   - Search past conversations and transcripts (`.system_generated/logs/transcript.jsonl` in Antigravity or `~/.claude/projects/` in Claude Code) to align with past user decisions and architectural consensus.

---

## Precedence

When multiple skills and rules apply to a task, instructions resolve in the following order of precedence (highest to lowest):

1. **Workspace Rulebooks** (`CLAUDE.md` / `GEMINI.md` / `.agents/rules/`):
   - Strict repository-level instructions, project constraints, and local overrides.
2. **Project-scoped References and Profiles** (`Projects/<Project>/...`):
   - Domain-specific conventions (e.g., `priis-backend-fastendpoints`, `priis-backend-ef-core`, `priis-frontend-rtk-query`) and the facts a Command adapts to.
3. **General References** (`modern-csharp`, `typescript-conventions`, etc.):
   - General language idioms and patterns.
4. **Modules** (`core`, `artifact-protocol`, `git-worktrees`, `pr-counterpart`):
   - Foundational operational discipline, safety gates, and communication protocols.
