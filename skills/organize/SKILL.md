---
name: organize
description: "Guides, designs, and executes safe, systematic codebase directory and file reorganization. Resolves mixed concerns, isolates static assets and datasets, extracts cross-cutting utilities and component-internal hooks, splits kitchen-sink helpers into focused modules, realigns C# namespaces and TypeScript barrel APIs, and verifies zero regressions. Always use when the user types /organize, asks to clean up folder structure, split messy files, isolate assets, or refactor directory layout."
argument-hint: "[<target-directory | scope>]"
---

# Skill: `/organize` — Codebase & Directory Reorganization

Systematically restructures codebase directories and files to eliminate clutter, untangle mixed concerns, and establish clean architectural boundaries. Preserves git history with `git mv`, protects consumer contracts with clean public APIs, updates non-code references, and verifies zero regressions via automated quality gates.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-organize_plan-<suffix>.md` (suffix from the target subsystem or directory, e.g. `-matching-components`, `-ticket-features`)
- `../_modules/git-worktrees.md`

On-demand references (`references/`):
- [`references/organize-plan-template.md`](references/organize-plan-template.md) — template for `<prefix>-organize_plan-<suffix>.md`

---

## ⛔ Golden Invariants

> [!CAUTION]
> 1. **PROPOSAL & PLAN FIRST.** Before moving, renaming or modifying files, write `<prefix>-organize_plan-<suffix>.md` in the artifact dir (`artifact-protocol`) and present the before/after structure. Exception: when the user names the exact moves themselves (`a/x.ts → b/x.ts`), list them in chat and skip the artifact.
> 2. **THE APPROVAL GATE (`/proceed`).** Do not mutate files until the user opens `core` › _The `/proceed` gate_, including the exact-moves case above.
> 3. **PRESERVE GIT HISTORY WITH `git mv`.** Never use plain `rm`/`cp`/`mv` or filesystem-only writes that break git file identity and blame.
> 4. **ZERO BROKEN REFERENCES (CODE & NON-CODE).** Scan and update static/dynamic imports, CSS `url()` assets, test fixtures, string paths, build configs, and `.csproj` inclusions.
> 5. **MANDATORY POST-MIGRATION VERIFICATION.** Finish with formatters (scoped to touched files), linters, type-checkers/builds, and targeted tests (`core` › _Post-edit verification_).

---

## 1. When *not* to use — pick the right neighbor

| Situation | Correct skill |
|---|---|
| Deep research into architecture *before* deciding how to change it | [`/investigate`](../investigate/SKILL.md) |
| Structuring an entire new feature or system implementation | [`/plan`](../plan/SKILL.md) |
| Restructuring directories, files, assets, and modularizing helpers | **`/organize`** (this skill) |
| Code review of an already completed reorganization or PR | [`/code-review`](../code-review/SKILL.md) |
| Diagnosing a broken build or test failure caused by misplaced files | [`/problem`](../problem/SKILL.md) |

---

## 2. Core Architectural Principles

| Principle | Rule |
|---|---|
| **1. Asset & Dataset Isolation** | Move static media (images, icons, fonts, SVGs) to `assets/` and static datasets/fixtures (JSON, CSV, XML, seeds) to `data/` or `fixtures/`. |
| **2. Cross-Cutting vs Feature-Local** | Domain-agnostic utilities/types/hooks belong in shared core (`src/shared/`, `Core/Common/`); domain-specific UI, hooks, services, and endpoints stay together in cohesive feature folders. |
| **3. Deconstruct Kitchen-Sink Files** | Split `helper.*`/`utils.*`/`common.*` into single-responsibility modules (context/state, styles/layout, types/contracts, domain logic); re-export from the old path when external callers need backward compatibility. |
| **4. Inline Logic & State Extraction** | Extract non-trivial inline state, complex calculations, and side effects from large presentation components into custom hooks or service classes. |
| **5. Clean Public Boundaries** | TS/JS: `index.ts` barrel at subsystem roots without circular barrel imports. C#: file-scoped namespaces matching folder paths. Python: explicit `__all__` in `__init__.py` or absolute package imports. |
| **6. Git History Preservation** | Move with `git mv` (`git mv -f` for case-only renames on case-insensitive filesystems). |

---

## 3. Step-by-Step Workflow

`1. Discovery & Dependency Mapping → 2. Draft Plan Artifact → 3. Approval Gate (/proceed) → 4. Atomic git mv Migration → 5. Reference Realignment → 6. Quality Gate`

### Phase 1: Deep Discovery & Dependency Mapping

1. **Catalog Target Directory**: list all files and categorize each (Component, Hook/Service, Model/Type, Utility, Asset, Dataset/Fixture, Test, Config).
2. **Map Inbound & Outbound References**: grep across the repo/workspace for static imports, dynamic imports (`import(...)`, `require(...)`, `import.meta.glob(...)`), CSS `url(...)`, test fixture loaders (`readFile(...)`, `new URL(..., import.meta.url)`), and config paths (`tsconfig.json`, `vite.config.*`, `.csproj`, Dockerfiles).
3. **Check Working Tree State**: run `git status` to ensure the directory is not in a tangled merge state.

### Phase 2: Formulate the Reorganization Plan Artifact

Write `<prefix>-organize_plan-<suffix>.md` in the artifact dir (`artifact-protocol`) via `artifact-protocol` › _Claim_ using [`references/organize-plan-template.md`](references/organize-plan-template.md).

### Phase 3: The Approval Gate

Present the `artifact-protocol` › _Chat link block_ for `<prefix>-organize_plan-<suffix>.md` and wait at `core` › _The `/proceed` gate_ (even when the user named the exact moves).

### Phase 4: Atomic Physical Migration

1. **Create Destination Subdirectories**: `mkdir -p <dest-dirs>`
2. **Execute Moves with `git mv`** (use `git mv -f` for case-only renames).
3. **Deconstruct Kitchen-Sink Files**: extract into focused files preserving type safety; re-export from the original file if backward compatibility is needed.

### Phase 5: Code & Reference Realignment

1. **Internal & External Imports**: rewrite relative paths within moved files and update external consumers to barrels or canonical project aliases (`@/`, `~/`).
2. **Namespaces (C# / .NET)**: synchronize file-scoped namespaces with the new folder path and update `using` directives.
3. **Non-Code & Test References**: update relative filesystem paths in tests, CSS `url()`, and markdown links.

### Phase 6: Automated Quality Gate

Run `core` › _Post-edit verification_:
1. **Formatter** on moved and edited files only (`npx prettier --write <files>`, `dotnet format --include <files>`).
2. **Linter & Typecheck/Build** (`npm run lint`, `npx tsc --noEmit` / `npm run build`, `dotnet build`, `ruff check` / `mypy`).
3. **Targeted Tests** covering the moved and consuming modules (`npm test -- <path>`, `dotnet test --filter ...`, `pytest`).

---

## 4. Ecosystem-Specific Nuances

- **TypeScript / JavaScript**: keep `index.ts` strictly for public boundary exports (no internal details that cause circular graphs); check `tsconfig.json` `paths` and bundler asset resolution.
- **C# / .NET**: use file-scoped namespaces matching folder paths; check `.csproj` for explicit `<Compile Remove>`, `<EmbeddedResource>`, or `<Content>` paths; never manually move EF Core `Migrations/` files (use [`squash-ef-core-migrations`](../squash-ef-core-migrations/SKILL.md)).
- **Python**: include `__init__.py` where required for package resolution and prefer absolute project-root imports over deep relative imports.

---

## 5. Deliverables & Output Protocol

1. **Link block**: the `artifact-protocol` › _Chat link block_ for `<prefix>-organize_plan-<suffix>.md`.
2. **Structural Comparison**: concise Before vs. After directory tree.
3. **Key Extractions & Refactorings**: bulleted summary of split files, isolated assets, and new hooks.
4. **Verification Evidence**: linter, typecheck, build, and test results.
