---
name: clean
description: Surgically cleans and tidies a target source file — removing unused exports (verifying zero external consumers across the workspace), dead variables and constants, obsolete comments, leftover debug statements, and redundant code, and refactoring nested ternaries into declarative, expressive constructs (lookup tables, guard clauses, internal closures, or pure helpers) while preserving public contracts, architectural documentation, and functional integrity. Trigger on /clean, "clean this file", "tidy up this file", "remove unused code in X", "strip dead code / console logs from X".
---

# Skill: `/clean` — File Sanitation & Dead Code Pruning

Surgically sanitizes a source file by eliminating dead code, unused exports, unreferenced variables, stale comments, and debug remnants, and refactoring nested ternaries into domain-expressive constructs — without altering runtime behavior or breaking any consumer, serialized contract, or framework convention.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.

- **Single-file target (default)**: `/clean` is itself the authorization to edit the target file — apply edits directly, no implementation plan or `/proceed` gate. Report with the chat summary in §5.
- **Directory / multi-file target**: write `<prefix>-clean_report-<suffix>.md` at the **workspace root** (prefix and suffix resolved per the [artifacts](../artifacts/SKILL.md) protocol, suffix derived from the target, e.g. `-audit-endpoint`), list the per-file findings, and clean the files one at a time with verification between each.
- **Blast radius**: edits stay inside the target file. The only permitted edits elsewhere are mechanical consequences of a verified removal (a barrel re-export line, an `__all__` entry, a stale JSDoc/XML-doc reference) — each one listed in the summary. Anything else found outside the target goes under *Suggestions*, not into the diff.

---

## ⛔ Golden Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR UNVERIFIED REMOVALS:**
>
> 1. **WORKSPACE CONSUMER VERIFICATION BEFORE UN-EXPORTING.**
>    Never demote or delete an exported/public symbol based on in-file usage. Search the **whole workspace root** — every repo in it, including tests and e2e — and follow re-exports and aliases (§3, Step 2). A test or e2e consumer is a consumer.
> 2. **PROTECT IMPLICIT & CONTRACT-BEARING CODE.**
>    Grep cannot see reflection, assembly scanning, serialization, or persistence. Never remove or demote framework entry points, serialized DTO members, persisted or integer-shared enum members, EF-mapped properties, or config-bound options — even with zero textual hits (§2, *What to Protect*).
> 3. **PRESERVE INTENT, NOT NOISE.**
>    Keep comments that explain *why* — business rules, workarounds, invariants, suppressions with rationale. Prune only commented-out code, completed TODOs, and comments that restate the code.
> 4. **ZERO RUNTIME BEHAVIOR DRIFT.**
>    Cleanup is non-functional. No changes to algorithms, API contracts, return types, evaluation order, or laziness unless the user explicitly asks.
> 5. **WHEN IN DOUBT, KEEP IT.**
>    Ambiguous usage (dynamic imports, string-built names, reflection-adjacent code) is retained and listed under *Retained — needs decision*. A missed removal costs nothing; a wrong one breaks production.
> 6. **MANDATORY POST-CLEAN VERIFICATION.**
>    Finish with the repo's own lint/type-check/build gates (§3, Step 5). Never leave the file broken or unformatted.

---

## 1. When to Use

Invoke this skill whenever:

- The user runs `/clean` (with a file path, or targeting the file open/selected in the IDE).
- The user asks to *"clean up / tidy this file"*, *"remove unused exports in X"*, *"strip dead variables and comments in Y"*, *"remove console logs and unused imports"*, *"tidy this component before shipping"*.

### When *not* to use — pick the right neighbor

| Situation | Correct skill |
| --- | --- |
| Moving files, splitting modules, reshaping folders | [`/organize`](../organize/SKILL.md) |
| Multi-function or architecture-wide declarative refactoring | [`/expressive`](../expressive/SKILL.md) |
| Removing duplication across files | `backend-dry` (backend) or [`/refine`](../refine/SKILL.md) |
| Compiler, build, or test failures | [`/problem`](../problem/SKILL.md) |
| Reviewing a branch diff against acceptance criteria | [`/code-review`](../code-review/SKILL.md) |

> [!NOTE]
> `/clean` borrows only the nested-ternary patterns from [`/expressive`](../expressive/SKILL.md). Anything broader — decomposing long functions, introducing strategy maps across a module — belongs in `/expressive`.

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
| **Nested Ternaries** | Ternary ladders (`a ? (b ? c : d) : e`) that obscure a decision. Refactor per Step 3.5 — but only when the result is clearer and behavior-identical. |

### 🛡️ What to Protect (NEVER Remove)

| Category | Must Be Preserved |
| --- | --- |
| **Architectural Rationale** | *Why* comments: workarounds for third-party bugs, domain invariants, race conditions, edge cases, links to work items. |
| **Docstrings & XML Docs** | JSDoc/TSDoc and `/// <summary>`. Update them when a removal makes them wrong (e.g. a deleted `@param`); never delete them wholesale. |
| **Framework Entry Points** | TanStack Router `export const Route = createFileRoute(...)`, lazy-route default exports, FastEndpoints endpoint classes, `IEntityTypeConfiguration<T>` picked up by `ApplyConfigurationsFromAssembly`, DI/assembly-scanned handlers, validators, Next.js page exports. |
| **Serialized Contracts** | Public properties on request/response DTOs, SignalR client methods, OpenAPI-emitted types. Zero C# references does not mean unused — the JSON consumer is in another repo. |
| **Persisted & Shared Enums** | Enum members stored in the database or shared by integer value across repos (e.g. PRIIS `SystemAction`). Deleting one breaks data or the other side of the contract. |
| **Persistence Mappings** | Entity properties mapped by EF Core. Removing one silently produces a schema change on the next migration. |
| **Config Binding** | Properties on options classes bound from `appsettings*.json` / environment. |
| **Required Signatures** | Parameters required by an interface or callback shape — prefix with `_` per convention instead of removing. |
| **Active Suppressions** | `eslint-disable-*`, `@ts-expect-error`, `#pragma warning disable`, `[SuppressMessage]` that still suppress something. Remove only if the suppressed diagnostic no longer fires (verify by removing and linting). |
| **Intentional Output** | `console.error`/`console.warn` in error paths, `ILogger` calls, and `Console.WriteLine`/`print()` in CLI tools and scripts — that is the program's output, not debug noise. |

---

## 3. Step-by-Step Workflow

```
1. RESOLVE TARGET  →  2. CROSS-CHECK USAGE  →  3. AUDIT  →  4. APPLY  →  5. VERIFY
   path / IDE file      workspace-wide search    smells      edits       repo gates
```

### Step 1: Target Resolution

1. Use the path the user gave (e.g. `/clean src/components/button.tsx`).
2. Otherwise use the file open or selected in the IDE (Claude Code: `ide_opened_file` / `ide_selection` context; Antigravity: active document metadata).
3. Still ambiguous → ask which file. Never guess.
4. Read the file **in full** (`Read` / `view_file`). Note which repo it belongs to — that decides the verification gates in Step 5.
5. Check `git status` for the file's repo. If the target already has uncommitted changes, mention it so the user can tell your edits apart from theirs.

### Step 2: Global Usage Cross-Check

Before touching any `export`, `public`, or `internal` symbol:

1. **Catalog** every exported/public symbol: functions, constants, types, enums, classes, and — for C# — public members.
2. **Search the workspace root, not just the repo.** Multi-repo workspaces (e.g. a root holding a backend and a frontend repo) need both searched. Use word boundaries and exclude build output:

   ```bash
   rg -n -w 'SymbolName' <workspace-root> \
     -g '!**/node_modules/**' -g '!**/bin/**' -g '!**/obj/**' -g '!**/dist/**'
   ```

3. **Follow the indirections grep misses on a plain name search:**
   - Barrels: `export * from './file'` and `export { Foo } from './file'` — then search consumers of the barrel path/alias.
   - Renames: `export { Foo as Bar }`, `import { Foo as Bar }` — search the alias too.
   - Dynamic and string references: `import('./file')`, `lazy(() => import(...))`, `nameof(Foo)`, string keys in JSON/config, `.cshtml`/`.razor` views.
   - Generated code that references the symbol (route trees, OpenAPI clients) — a generated consumer is a consumer.
4. **Classify each symbol:**

   | Finding | Action |
   | --- | --- |
   | External consumers exist (including tests, e2e, generated code) | Keep untouched |
   | No external consumers, used locally | Demote (drop `export` / narrow access modifier) |
   | No consumers anywhere | Delete |
   | Framework-mandated or contract-bearing (§2 *Protect*) | Keep, regardless of hits |
   | Ambiguous (dynamic / reflection-adjacent) | Keep; list under *Retained — needs decision* |

### Step 3: Code Smell & Dead Code Audit

1. **Unused imports** — trace every identifier against the body. Delete the whole statement if all specifiers are unused; otherwise prune specifiers. Keep side-effect-only imports.
2. **Dead bindings** — before removing an unused variable, inspect its right-hand side. `const x = performAction()` with unused `x` becomes `performAction()` if it has side effects (calls, awaits, mutations, getters that throw); only a pure expression may be deleted outright. In C#, use `_ = PerformAction();` where the repo convention requires it.
3. **Comments and debug output** — classify each per §2. Distinguish commented-out code (code syntax) from prose. A TODO is removed only when the code proves the work is done; TODOs with a work-item ID or an open question stay.
4. **Redundant code** — redundant casts and assertions, double negation, empty blocks, duplicate class names/styles. Removing a type assertion can change an inferred type — re-check with the type-checker.
5. **Nested ternaries** — refactor using the [`/expressive`](../expressive/SKILL.md) catalog, choosing by shape:

   | Shape | Construct |
   | --- | --- |
   | Discrete keys/variants → values | Lookup map / `Record` (Pattern 1) |
   | Depends on several locals, props, or state | **Internal closure** with guard clauses inside the consuming function — avoids parameter drilling |
   | Pure and independent of enclosing scope, or shared | Module-scope pure helper (Pattern 3) |
   | Compound domain condition | Named predicate / semantic variable (Pattern 2) |
   | C# | `switch` expression or pattern matching |

   **Behavior traps — check before converting:**
   - **Eager vs. lazy**: a ternary evaluates only the chosen branch; an object literal evaluates every value up front. If a branch throws, has side effects, or is expensive (`obj.a.b` on a possibly-null `obj`, a function call), store thunks or use a closure with guards instead of a plain map.
   - **Fallback semantics**: keep `??` vs `||` exactly as written — `0`, `''`, and `false` behave differently.
   - **Exhaustiveness**: a typed `Record<Union, T>` must still cover every member; don't introduce a silent `undefined`.
   - A single-level `a ? b : c`, or a two-branch JSX conditional render, is fine as is — don't refactor it.

### Step 4: Surgical Application

1. Apply targeted edits (`Edit` / `replace_file_content`). Never rewrite the whole file to remove a few lines.
2. Clean up orphaned blank lines, dangling commas, and now-empty blocks left by removals.
3. Place extracted helpers as an **internal closure** when they capture local scope; at module scope only when genuinely pure or shared.
4. No renames, reformatting of untouched code, reordering, or style changes beyond what the removal requires.

### Step 5: Verification & Quality Gate

Use the gates named in the repo's rulebook (`CLAUDE.md` / `GEMINI.md` / copilot-instructions) — they override the defaults below. **Scope formatters to the touched files**: repo-wide import sorters and formatters rewrite unrelated files and pollute the diff.

| Stack | Default gates |
| --- | --- |
| TypeScript / React | `npx eslint <file>` then the repo's `lint` + `build` scripts (or `npx tsc --noEmit`) |
| C# / .NET | `dotnet format --include <file>` then `dotnet build` |
| Python | `ruff check <file>` (or the repo's linter) and its type-checker |

Then:

1. If a test suite covers the target, run it (Playwright specs for UI, the relevant integration-test class for backend).
2. Run `git diff --stat` in the repo. Any file outside the target that is not a listed mechanical consequence → revert it (`git checkout -- <file>`).
3. A failing gate is fixed or the offending removal reverted — never reported as done.

---

## 4. Language-Specific Guidelines

### TypeScript / React

- **Unused props**: removing a prop from a component's type breaks every caller still passing it — grep the JSX call sites and include them in Step 2.
- **Unused state**: remove `useState` only when neither the value nor the setter is used. A setter used without reading the value may still trigger needed re-renders — keep it and flag it.
- **Unused effects/memos**: an effect with side effects is not dead just because nothing reads its output.
- **`import React`**: remove only when `tsconfig` uses the automatic runtime (`"jsx": "react-jsx"`) and the file doesn't use `React.*` APIs.
- **Prefer `type` over `interface`** per [core](../core/SKILL.md) — but converting existing interfaces is out of `/clean`'s scope unless the user asks.

### C# / .NET

- **Usings**: let `dotnet format --include <file>` prune them.
- **Access modifiers**: demote a member to `private` only when it is a method or field with no outside callers. Never demote public **properties** on DTOs, entities, or options classes — serialization, EF, and configuration binding use them reflectively.
- **`sealed`**: add only when the repo convention requires it (e.g. PRIIS Backend) and nothing derives from the class.
- **Discards**: `_ = Expression();` or `_` parameters where a signature demands them.
- **Nested ternaries**: `switch` expressions or pattern matching.

### Python

- Remove unused imports and locals; keep imports that exist for re-export or side effects.
- When removing an export from `__init__.py`, update `__all__`.
- Remove debugging `print()` — but not output in CLI entry points and scripts.

---

## 5. Output Format

Keep the summary concise and high-signal. Link the file using the **active host's** link format from the [artifacts](../artifacts/SKILL.md) protocol (workspace-relative in Claude Code, `file://` in Antigravity). Omit empty sections.

```markdown
### 🧹 Clean Summary: [button.tsx](src/components/button.tsx)

#### Removed & Pruned
- **Exports**: `helperUtil` demoted to module-private (no external consumers); `UNUSED_CONST` deleted (unused everywhere).
- **Imports**: `useCallback`, `useMemo` from `'react'`; type `UserRole` from `'~/types'`.
- **Comments & debug**: 3 commented-out JSX blocks; 2 `console.log()` calls.
- **Redundant logic**: `!!isValid` → `isValid` in `if` condition.

#### Expressive Refactorings
- Nested ternary `choices ? (typeof choices === 'function' ? choices(settle) : choices) : defaultChoices` → internal `resolveChoices` closure with guard clauses.

#### Outside the Target (mechanical)
- `src/components/index.ts`: dropped re-export of deleted `UNUSED_CONST`.

#### Retained
- `export const Route`: router entry point.
- Comment at L42–45: explains a cache-invalidation race.
- **Needs decision**: `legacyFormatter` — no static references, but `formatters/[name]` is resolved dynamically.

#### Suggestions (not applied)
- `useFoo` in `hooks/use-foo.ts` duplicates `useBar` — candidate for `/refine`.

#### Verification
- Lint: ✅ · Build/type-check: ✅ · Diff: target file + 1 listed barrel only
```

---

## 6. Verification Checklist

Before reporting completion, confirm:

- [ ] Every demoted/removed symbol was searched across the whole workspace root, including barrels, aliases, dynamic references, tests, and generated code.
- [ ] Nothing in §2 *What to Protect* was removed or demoted, regardless of grep results.
- [ ] Every nested ternary was refactored, or left as is with a stated reason; no conversion changed evaluation laziness or `??`/`||` semantics.
- [ ] No side-effecting expression was deleted along with an unused binding.
- [ ] Docs and suppressions are intact and still accurate after removals.
- [ ] The diff touches only the target file plus listed mechanical consequences.
- [ ] The repo's lint and build/type-check gates pass.
