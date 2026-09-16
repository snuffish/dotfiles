---
name: clean
description: Surgically cleans and tidies a target source file — removing unused exports (verifying zero external consumers across the workspace), dead variables and constants, obsolete comments, leftover debug statements, and redundant code, and refactoring nested ternaries into declarative, expressive constructs (lookup tables, guard clauses, internal closures, or pure helpers) while preserving public contracts, architectural documentation, and functional integrity. Trigger on /clean, "clean this file", "tidy up this file", "remove unused code in X".
---

# Skill: `/clean` — File Sanitation & Dead Code Pruning

Surgically sanitizes a source file by eliminating dead code, unused exports, unreferenced variables, stale comments, and debug remnants, and refactoring convoluted nested ternaries into clean, domain-expressive constructs without altering runtime behavior or breaking external consumers.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.

- **Target Artifact** (when performing a multi-file audit or deep refactoring): `<prefix>-clean_report-<suffix>.md` at the **workspace root** (where `<prefix>` is `<host>-<model>-`, e.g. `antigravity-gemini-3.8-flash-` or `claude-sonnet-3.7-`).
- **Anti-Overwrite Rule**: Always include the active AI model in `<prefix>` and append a descriptive kebab-case `<suffix>` derived from the target module or file (e.g. `-audit-endpoint`, `-register-tickets`). Never write unsuffixed or un-modeled generic files.
- For single-file targeted cleanup, apply precise edits directly to the file, accompanied by a structured summary in the chat response.

---

## ⛔ Golden Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR UNVERIFIED REMOVALS:**
>
> 1. **WORKSPACE CONSUMER VERIFICATION BEFORE UN-EXPORTING.**
>    Never remove `export` or delete an exported symbol solely based on its usage *within* the current file. You MUST search the workspace (ripgrep / grep search) to confirm zero external consumers across the entire codebase.
> 2. **PROTECT FRAMEWORK ENTRY POINTS & ROUTE CONTRACTS.**
>    Never remove exports that are implicitly consumed by frameworks, code generators, or reflection (e.g. TanStack Router `Route`, Next.js `metadata`/`default`, FastEndpoints endpoint classes, EF Core configurations, test suites).
> 3. **PRESERVE ARCHITECTURAL & INTENT COMMENTS.**
>    Never delete comments that explain *why* non-obvious logic exists, domain business rules, architectural tradeoffs, or active linter/compiler suppressions with rationale. Only prune self-evident, commented-out, or obsolete comments.
> 4. **MANDATORY POST-CLEAN VERIFICATION.**
>    Every clean operation must conclude with language-appropriate checks (linting, type-checking, or building). Never leave a file in a broken or unformatted state.
> 5. **ZERO RUNTIME BEHAVIOR DRIFT.**
>    Cleanup is strictly non-functional refactoring. Do not change algorithms, API contracts, return types, or execution order unless explicitly requested by the user.

---

## 1. When to Use

Invoke this skill whenever:

- The user runs `/clean` (with an optional file path or targeting the active editor file).
- The user asks to:
  - *"clean up this file"*
  - *"remove unused exports in X"*
  - *"strip dead variables and comments in Y"*
  - *"tidy up this component before shipping"*
  - *"remove console logs, dead code, and unused imports"*

### When *not* to use — pick the right neighbor

| Situation | Correct skill |
| --- | --- |
| Deep structural reorganization across folders/modules | [`/organize`](../organize/SKILL.md) |
| Architecture-wide or multi-function declarative refactoring | [`/expressive`](../expressive/SKILL.md) |
| Diagnosing compiler, build, or test failures | [`/problem`](../problem/SKILL.md) |
| Pre-commit branch review of diffs against acceptance criteria | [`/code-review`](../code-review/SKILL.md) |

> [!NOTE]
> `/clean` directly incorporates [`/expressive`](../expressive/SKILL.md) patterns to refactor **nested ternaries** (`a ? (b ? c : d) : e`) into clean lookup tables, flat guard clauses, internal closures, or pure helper functions encountered during sanitation. For broader structural or multi-function transformations, use [`/expressive`](../expressive/SKILL.md).

---

## 2. The Sanitation Spectrum (What to Prune vs. What to Keep)

### 🧹 What to Prune

| Category | Targets for Removal |
| --- | --- |
| **Unused Exports** | Exported types, constants, helper functions, or classes that have zero consumers across the workspace. If used only locally, remove `export` and make private/module-scoped; if unused anywhere, delete completely. |
| **Dead Symbols** | Unused local variables, unreferenced private functions, unread constants, and unreferenced local types/interfaces. |
| **Unused Imports** | Imported modules, types, or destructured members that are never referenced in the file. |
| **Obsolete Comments** | Commented-out code blocks (e.g. `// const oldData = ...`), stale TODOs/FIXMEs that have already been addressed or abandoned, and redundant "what" comments (e.g. `// increment count`, `// return result`). |
| **Debug Remnants** | Leftover `console.log`, `console.debug`, `Console.WriteLine`, `debugger;`, `print()`, or temporary test spies. |
| **Redundant Constructs** | Redundant boolean casts in boolean contexts (`if (!!condition)` → `if (condition)`), pointless ternaries (`val ? true : false` → `Boolean(val)` or `val`), empty lifecycle hooks or empty default constructors that do nothing. |
| **Nested Ternaries** | Nested ternary ladders (`a ? (b ? c : d) : e`) or compound inline ternaries that obscure business decisions. Refactor into declarative lookup tables, flat guard clauses, internal closures, or intent-revealing pure helper functions adhering to [`/expressive`](../expressive/SKILL.md) patterns. |

---

### 🛡️ What to Protect (NEVER Remove)

| Category | Must Be Preserved |
| --- | --- |
| **Architectural Rationale** | Comments detailing *why* an unusual pattern was chosen, workarounds for third-party bugs, domain invariants, or edge-case explanations. |
| **Public API Contracts** | Public methods and types of shared libraries, packages, or base interfaces intended for external package consumption. |
| **Framework Hooks & Conventions** | Framework entry points: TanStack Router `Route = createFileRoute(...)`, FastEndpoints `Endpoint<TRequest, TResponse>`, React component default exports for lazy routes, Next.js page exports (`generateMetadata`, `dynamic`), etc. |
| **Required Signatures** | Unused function parameters required to satisfy an interface or callback signature (prefix with `_` instead of removing if required by convention, e.g. `(_event, value) => ...`). |
| **Active Suppressions** | Linter/compiler directives with purpose (e.g. `// eslint-disable-next-line @typescript-eslint/no-explicit-any`, `#pragma warning disable CS8618`). |
| **Docstrings & XML Docs** | JSDoc/TSDoc (`/** ... */`) and C# XML doc comments (`/// <summary>`) providing documentation for IDE autocompletion and API consumers. |

---

## 3. Step-by-Step Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. TARGET RESOLUTION & SCOPE                                │
│    Resolve file path from user argument or active editor    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. GLOBAL USAGE CROSS-CHECK (CRITICAL)                      │
│    Search workspace for all exported symbols via ripgrep    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. CODE SMELL & DEAD CODE SCAN                              │
│    Audit imports, unused variables, comments, debug logs    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. SURGICAL APPLICATION                                     │
│    Apply clean edits; remove dead code; format whitespace   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. VERIFICATION & QUALITY GATE                              │
│    Run lint, typecheck, or build; confirm zero regressions  │
└─────────────────────────────────────────────────────────────┘
```

---

### Step 1: Target Resolution

1. If the user provided a file path (e.g. `/clean src/components/button.tsx`), use that target.
2. If no file path was given:
   - Check the user metadata for the currently active document / open editor file.
   - If ambiguous, ask the user to specify which file they want to clean.
3. Read the target file in full using `view_file`.

---

### Step 2: Global Usage Cross-Check (Workspace-Wide)

Before touching any `export`:

1. **Catalog all exported symbols** in the target file:
   - Exported functions, constants, types, interfaces, enums, classes.
2. **Search the entire workspace** for each symbol using `grep_search`:
   - Search for the exact symbol name across files.
   - Check barrel files (`index.ts`, `index.js`) that re-export from the file (`export * from ...` or `export { Foo } from ...`).
   - If an export is re-exported from an index barrel, check for consumers importing from that barrel!
3. **Classify each exported symbol**:
   - **External consumers exist**: KEEP the export untouched.
   - **No external consumers, but used locally**: REMOVE the `export` keyword (demote to file-private).
   - **No external consumers, and NOT used locally**: MARK FOR DELETION.
   - **Framework-mandated export**: KEEP untouched regardless of grep matches.

---

### Step 3: Code Smell & Dead Code Audit

Audit the file systematically for:

1. **Unused Imports**:
   - Trace each imported identifier against the file body.
   - If a whole import statement becomes unused, delete the line.
   - If only specific destructured specifiers are unused, prune only those specifiers.
2. **Dead Variables, Constants, and Functions**:
   - Identify unreferenced local bindings.
   - Check for side-effect assignments: if removing a variable, ensure the right-hand expression does not contain necessary side effects (e.g. `const x = performAction()` → if `x` is unused, keep `performAction()` if it has side effects, or eliminate if pure).
3. **Comments & Debug Logs**:
   - Identify commented-out code (lines matching code syntax rather than English explanation).
   - Identify obsolete or trivial comments.
   - Locate `console.*`, `debugger`, or print statements.
4. **Redundant Code**:
   - Unnecessary type assertions (`as const` on primitives, redundant casts).
   - Redundant double negation in `if` conditions.
   - Duplicate styles, classes, or empty blocks.
5. **Nested Ternaries & Convoluted Branching**:
   - Locate nested ternary expressions (`a ? (b ? c : d) : e` or ternary chains).
   - Refactor them into expressive constructs following [`/expressive`](../expressive/SKILL.md):
     - **Declarative Lookup Map / Record** (Pattern 1): When mapping discrete keys, states, or variants to values.
     - **Internal Closure with Guard Clauses (Preferred when capturing local scope)**: If the helper relies on multiple local variables, props, or state setters (e.g. `choices`, `settle`, `defaultChoices`), make it an **internal closure** within the consuming function/component. Capturing lexical scope avoids parameter drilling and keeps module scope clean.
     - **Extracted Pure Helper Function at Module Scope** (Pattern 3): When resolving complex fallback cascades, factory functions, or multi-condition values that are completely pure, parameter-independent, or shared across multiple functions.
     - **Domain Predicates & Semantic Variables** (Pattern 2): When condition operands represent compound domain rules.

---

### Step 4: Surgical Application

1. Make targeted file replacements using `replace_file_content` or `multi_replace_file_content`.
2. Clean up excess whitespace, orphan blank lines, or dangling trailing commas caused by pruned items.
3. **Scoping Extracted Helpers**: Prefer an **internal closure** inside the consuming function/component when the logic naturally captures local lexical variables (props, state, handlers), avoiding parameter bloat. Place helpers at module scope only if they are genuinely pure, independent of enclosing state, or shared across callers.
4. Keep changes focused strictly on cleanup and expressiveness: avoid unsolicited architectural restructurings or stylistic renames during a `/clean` pass.

---

### Step 5: Verification & Quality Gate

Never complete a clean operation without verifying:

1. **Linter / Formatter**:
   - Run project-specific linting (e.g., `npm run lint`, `dotnet format`, or `ruff check`).
2. **Type-Check / Compiler**:
   - Verify TypeScript compilation (`npx tsc --noEmit` or `npm run build`), .NET build (`dotnet build`), or equivalent.
3. **Tests**:
   - If a dedicated test suite exists for the target file, run it to guarantee zero behavioral regressions.

---

## 4. Language-Specific Cleaning Guidelines

### TypeScript / React

- **Unused Props**: If an interface prop is never used in the component, check if the component is part of a public contract or library before removing.
- **Unused Handlers / State**: Remove `useState` hooks that are never read or updated.
- **React Imports**: Remove unnecessary `import React from 'react'` in modern JSX transform environments (React 17+).
- **Barrel Safety**: Check `index.ts` in parent directories for re-exports before removing any component export.
- **Nested Ternaries in Logic & JSX**: Refactor nested ternaries in props resolution, state derivation, or render branches into declarative lookup maps, early guards, or internal closures that capture props/state without parameter bloat.

### C# / .NET

- **Unused Usings**: Prune unused `using` directives at top of file (or let `dotnet format` handle them).
- **Access Modifiers**: If a class member is `public` or `internal` but only used within the class, demote to `private`.
- **Sealed Classes**: If a class is not meant to be inherited and is marked `internal` or `public` without virtual members, follow project conventions (e.g. `sealed` in PRIIS Backend).
- **Discard Variables**: Use `_ = expression;` or discard parameters `_` where required by signature.
- **Nested Ternaries**: Replace nested `? :` ladders with switch expressions (`x switch { ... }`) or pattern matching.

### Python

- **Unused Imports & Variables**: Remove unused imports and unreferenced local variables.
- **`__all__` Maintenance**: If removing an export in `__init__.py`, synchronize the `__all__` list.
- **Leftover Print Statements**: Remove `print()` calls that were used for manual debugging.

---

## 5. Output Format & Deliverables

Always provide a concise, high-signal summary of the sanitation performed:

```markdown
### 🧹 Clean Summary: `[file basename](file:///path/to/file)`

#### Removals & Pruning:
- **Exports Demoted / Removed**:
  - `helperUtil`: Removed `export` keyword (now module-private; zero external consumers).
  - `UNUSED_CONST`: Deleted (unused locally and globally).
- **Unused Imports**:
  - Pruned `useCallback`, `useMemo` from `'react'`.
  - Pruned unused type `UserRole` from `'~/types'`.
- **Dead Code & Comments**:
  - Removed 3 commented-out legacy JSX blocks.
  - Stripped 2 leftover `console.log()` statements.
- **Redundant Logic**:
  - Simplified `!!isValid` to `isValid` inside `if` condition.

#### Expressive Refactorings:
- **Nested Ternaries Refactored**:
  - Replaced nested ternary `choices ? (typeof choices === 'function' ? choices(settle) : choices) : defaultChoices` with internal `resolveChoices` closure using guard clauses (capturing `choices`, `settle`, `defaultChoices` without parameter drilling).

#### Protected / Retained:
- Kept `export const Route`: Framework router entry point.
- Kept architectural comment on lines 42–45 explaining cache invalidation race condition.

#### Verification:
- Linter: PASSED (0 errors, 0 warnings)
- Build / Typecheck: PASSED
```

---

## 6. Verification Checklist

Before reporting completion to the user, ensure:

- [ ] Every modified/removed export was searched workspace-wide with zero external hits.
- [ ] No framework conventions or entry points were inadvertently stripped.
- [ ] All nested ternaries were refactored into expressive, intent-revealing constructs (lookup tables, guard clauses, internal closures, or pure helpers).
- [ ] Meaningful documentation, JSDoc/XML-doc, and suppressions remain intact.
- [ ] No side effects were accidentally deleted when stripping unused variables.
- [ ] Cleaned file passes the project's linter and type-checker/compiler cleanly.
