---
name: clean
description: "Removes dead weight from a target file without changing behaviour: unused exports (after proving zero consumers across the workspace), dead variables and constants, obsolete comments, leftover debug statements and redundant code, plus nested ternaries it meets in that file. Preserves public contracts and architectural documentation. Use for /clean, \"clean this file\", \"tidy up this file\", \"remove unused code in X\", \"strip dead code / console logs from X\"."
argument-hint: "[<target>]"
---

# Skill: `/clean` — File Sanitation & Dead Code Pruning

Surgically sanitizes a source file by eliminating dead code, unused exports, unreferenced variables, stale comments, and debug remnants, and refactoring nested ternaries into domain-expressive constructs — without altering runtime behavior or breaking any consumer, serialized contract, or framework convention.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-clean_report-<suffix>.md` for a directory / multi-file target only (suffix derived from the target, e.g. `-audit-endpoint`); single-file runs apply edits directly and report in chat
- `../_modules/git-worktrees.md`

On-demand references (`references/`):
- [`references/summary-template.md`](references/summary-template.md) — chat and report summary structure

- **Single-file target (default)**: invoking `/clean` authorizes editing the target file directly (no plan or `/proceed` gate).
- **Blast radius**: edits stay inside the target file except mechanical consequences of a verified removal (a barrel re-export line, an `__all__` entry, a stale JSDoc/XML-doc reference), each listed in the summary. Anything else outside the target goes under *Suggestions*.

---

## ⛔ Golden Invariants

> [!CAUTION]
> 1. **WORKSPACE CONSUMER VERIFICATION BEFORE UN-EXPORTING.** Search the **whole workspace root** — every repo in it, including tests, e2e, barrels, and aliases (§3 Step 2) — before demoting or deleting an exported/public symbol.
> 2. **PROTECT IMPLICIT & CONTRACT-BEARING CODE.** Never remove or demote framework entry points, serialized DTO members, persisted or integer-shared enum members, EF-mapped properties, or config-bound options — even with zero textual hits (§2 *What to Protect*).
> 3. **PRESERVE INTENT, NOT NOISE.** Keep comments that explain *why* (business rules, workarounds, invariants, suppressions with rationale). Prune only commented-out code, completed TODOs, and comments that restate the code.
> 4. **ZERO RUNTIME BEHAVIOR DRIFT.** No changes to algorithms, API contracts, return types, evaluation order, or laziness unless the user explicitly asks.
> 5. **WHEN IN DOUBT, KEEP IT.** Retain ambiguous usage (dynamic imports, string-built names, reflection-adjacent code) under *Retained — needs decision*.
> 6. **MANDATORY POST-CLEAN VERIFICATION.** Finish with the repo's lint/type-check/build gates (`core` › *Post-edit verification*).

---

## 1. When *not* to use — pick the right neighbor

| Situation | Correct skill |
| --- | --- |
| Moving files, splitting modules, reshaping folders | [`/organize`](../organize/SKILL.md) |
| Multi-function or architecture-wide declarative refactoring | [`/expressive`](../expressive/SKILL.md) |
| Removing duplication across files | `priis-backend-dry` (backend) or [`/refine`](../refine/SKILL.md) |
| Compiler, build, or test failures | [`/problem`](../problem/SKILL.md) |
| Reviewing a branch diff against acceptance criteria | [`/code-review`](../code-review/SKILL.md) |

---

## 2. The Sanitation Spectrum

### 🧹 What to Prune

| Category | Targets for Removal |
| --- | --- |
| **Unused Exports** | Exported symbols with zero consumers workspace-wide. Used only locally → drop `export` (or demote to `private`/`internal`); unused anywhere → delete. |
| **Dead Symbols** | Unused locals, unreferenced private functions, unread constants, unreferenced local types. Keep side-effecting right-hand expressions (Step 3.2). |
| **Unused Imports** | Whole import statements or individual specifiers never referenced. Keep side-effect imports (`import './polyfill'`, `import './styles.css'`). |
| **Obsolete Comments** | Commented-out code, TODO/FIXMEs whose work is demonstrably done in the code, and comments that restate the next line (`// increment count`). |
| **Narrative Comments** | Comments addressed to a reader rather than describing code — defending a decision, listing rejected alternatives, referencing "the user asked". Condense to one technical clause; delete only if nothing technical remains. |
| **Debug Remnants** | Stray `console.log`/`console.debug`, `debugger;`, temporary `Console.WriteLine`/`Debug.WriteLine`, debugging `print()`, leftover test spies or `.only`. |
| **Redundant Constructs** | `if (!!x)` → `if (x)`; `x ? true : false` → `Boolean(x)` (or `x` if already boolean); empty lifecycle hooks, empty default constructors, empty `else {}`; casts to the type the value already has. |
| **Nested Ternaries** | Ternary ladders (`a ? (b ? c : d) : e`) that obscure a decision. Refactor per Step 3.5 — only when clearer and behavior-identical. |

### 🛡️ What to Protect (NEVER Remove)

| Category | Must Be Preserved |
| --- | --- |
| **Architectural Rationale** | *Why* comments: workarounds for third-party bugs, domain invariants, race conditions, edge cases, links to work items. |
| **Docstrings & XML Docs** | JSDoc/TSDoc and `/// <summary>`. Update them when a removal makes them wrong (e.g. a deleted `@param`); never delete them wholesale. |
| **Framework Entry Points** | TanStack Router `export const Route = createFileRoute(...)`, lazy-route default exports, FastEndpoints endpoint classes, `IEntityTypeConfiguration<T>` picked up by `ApplyConfigurationsFromAssembly`, DI/assembly-scanned handlers, validators, Next.js page exports. |
| **Serialized Contracts** | Public properties on request/response DTOs, SignalR client methods, OpenAPI-emitted types. |
| **Persisted & Shared Enums** | Enum members stored in the database or shared by integer value across repos (e.g. PRIIS `SystemAction`). |
| **Persistence Mappings** | Entity properties mapped by EF Core. |
| **Config Binding** | Properties on options classes bound from `appsettings*.json` / environment. |
| **Required Signatures** | Parameters required by an interface or callback shape — prefix with `_` per convention instead of removing. |
| **Active Suppressions** | `eslint-disable-*`, `@ts-expect-error`, `#pragma warning disable`, `[SuppressMessage]` that still suppress something. |
| **Intentional Output** | `console.error`/`console.warn` in error paths, `ILogger` calls, and `Console.WriteLine`/`print()` in CLI tools and scripts. |

---

## 3. Step-by-Step Workflow

### Step 1: Target Resolution

1. Resolve the path from arguments or the file open/selected in the IDE (ask if still ambiguous).
2. Read the file **in full** and check `git status` for its repo (mention if the file already has uncommitted changes).

### Step 2: Global Usage Cross-Check

Before touching any `export`, `public`, or `internal` symbol:
1. **Catalog** every exported/public symbol (functions, constants, types, enums, classes, C# public members).
2. **Search the workspace root** with word boundaries, excluding build output and worktree copies:
   ```bash
   rg -n -w 'SymbolName' <workspace-root> \
     -g '!**/node_modules/**' -g '!**/bin/**' -g '!**/obj/**' -g '!**/dist/**' \
     -g '!**/.claude/worktrees/**'
   ```
3. **Follow indirections**: barrels (`export *`, `export { Foo }`), renames (`as Bar`), dynamic/string references (`import(...)`, `nameof(Foo)`, JSON/config keys, `.cshtml`/`.razor`), and generated code (route trees, OpenAPI clients).
4. **Classify**: external consumers → keep; local only → demote; zero consumers → delete; framework/contract (§2) → keep; ambiguous → keep and list under *Retained — needs decision*.

### Step 3: Code Smell & Dead Code Audit

1. **Unused imports**: delete unused statements or specifiers; keep side-effect-only imports.
2. **Dead bindings**: inspect the right-hand side before removing. Keep side-effecting expressions (`performAction()`, or `_ = PerformAction();` in C#); delete only pure expressions.
3. **Comments and debug output**: classify per §2. Remove a TODO only when the code proves the work is done; keep TODOs with a work-item ID or open question.
4. **Redundant code**: redundant casts/assertions, double negation, empty blocks, duplicate class names. Re-check inferred types after removing assertions.
5. **Nested ternaries**: refactor using [`../expressive/references/transformation-catalog.md`](../expressive/references/transformation-catalog.md) (Pattern 1 lookup map, internal closure with guards when capturing local scope, Pattern 3 pure helper, Pattern 2 named predicate, or C# `switch` expression), checking Pattern 1's behavior traps (eager vs. lazy evaluation, `??` vs `||`, exhaustiveness, and leaving single-level ternaries alone).

### Step 4: Surgical Application

1. Apply targeted edits without rewriting the whole file; remove orphaned blank lines, dangling commas, and empty blocks.
2. Place extracted helpers as an **internal closure** when they capture local scope; at module scope only when pure or shared.
3. No renames, reformatting of untouched code, or reordering beyond what the removal requires.

### Step 5: Verification & Quality Gate

Run `core` › *Post-edit verification*, scoping formatters to touched files only:
- **TypeScript / React**: `npx eslint <file>` then repo `lint` + `build` / `npx tsc --noEmit`.
- **C# / .NET**: `dotnet format --include <file>` then `dotnet build`.
- **Python**: `ruff check <file>` and type-checker.
- Run covering tests, check `git diff --stat`, and revert any unintended file changes outside the target (`git checkout -- <file>`).

---

## 4. Language-Specific Guidelines

- **TypeScript / React**: include JSX call sites when checking unused component props; keep `useState` setters that trigger needed re-renders; keep side-effecting `useEffect`; remove `import React` only under `"jsx": "react-jsx"` with no `React.*` usage; prefer `type` over `interface` for new shapes ([`expressive` Pattern 7](../expressive/references/transformation-catalog.md#pattern-7-prefer-type-over-interface-typescript)).
- **C# / .NET**: let `dotnet format --include <file>` prune `using`s; never demote public properties on DTOs, entities, or options classes; add `sealed` when repo convention requires it and nothing derives from the class.
- **Python**: keep re-export/side-effect imports; update `__all__` when removing exports from `__init__.py`; keep `print()` in CLI scripts.

---

## 5. Output Format & Verification

Report using [`references/summary-template.md`](references/summary-template.md) (or write `<prefix>-clean_report-<suffix>.md` for directory targets and render its `artifact-protocol` › _Chat link block_). Confirm all Golden Invariants and repo lint/build gates pass before reporting.
