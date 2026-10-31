---
name: organize
description: "Guides, designs, and executes safe, systematic codebase directory and file reorganization. Resolves mixed concerns, isolates static assets and datasets, extracts cross-cutting utilities and component-internal hooks, splits kitchen-sink helpers into focused modules, realigns C# namespaces and TypeScript barrel APIs, and verifies zero regressions. Always use when the user types /organize, asks to clean up folder structure, split messy files, isolate assets, or refactor directory layout."
---

# Skill: `/organize` — Codebase & Directory Reorganization

Systematically restructures codebase directories and files to eliminate clutter, untangle mixed concerns, and establish clean architectural boundaries. Preserves git history with `git mv`, protects consumer contracts with clean public APIs, updates non-code references, and verifies zero regressions via automated quality gates.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-organize_plan-<suffix>.md` (suffix from the target subsystem or directory, e.g. `-matching-components`, `-ticket-features`)
- `../_modules/git-worktrees.md`

---

## ⛔ Golden Invariants

> [!CAUTION]
> 1. **PROPOSAL & PLAN FIRST.** Before moving, renaming or modifying files, write `<prefix>-organize_plan-<suffix>.md` at the workspace root and present the before/after structure. A reorganization touches every importer of every moved file, so the user needs to see the blast radius before it happens. The one exception: when the user names the exact moves themselves (`a/x.ts → b/x.ts`, …), those moves are the plan. List them in chat and skip the artifact.
> 2. **THE APPROVAL GATE (`/proceed`).** Do not mutate files until the user authorizes the plan, including the exact-moves case above.
> 3. **PRESERVE GIT HISTORY WITH `git mv`.** Never use plain `rm`/`cp`/`mv` or filesystem-only writes that break git file identity, blame, and history tracking.
> 4. **ZERO BROKEN REFERENCES (CODE & NON-CODE).** Updating import statements is not enough. Reorganization must scan and update dynamic imports, CSS `url()` assets, test fixtures, string path references, build configs, and `.csproj` inclusions.
> 5. **MANDATORY POST-MIGRATION VERIFICATION.** Every reorganization must culminate in running formatters, linters, type-checkers/builds, and targeted tests. Never declare completion on unverified moves.

---

## 1. When to Use

### When *not* to use — pick the right neighbor

| Situation | Correct skill |
|---|---|
| Deep research into architecture *before* deciding how to change it | [`/investigate`](../investigate/SKILL.md) |
| Structuring an entire new feature or system implementation | [`/plan`](../plan/SKILL.md) |
| Restructuring directories, files, assets, and modularizing helpers | **`/organize`** (this skill) |
| Code review of an already completed reorganization or PR | [`/code-review`](../code-review/SKILL.md) |
| Diagnosing a broken build or test failure caused by misplaced files | [`/problem`](../problem/SKILL.md) |

---

## 2. Core Architectural Principles

When organizing any subsystem, directory, or module, apply these six principles across languages and frameworks:

### 1. Asset & Dataset Isolation
- Move static media (images, icons, fonts, SVGs, audio) into an `assets/` subfolder.
- Move static datasets (JSON, GeoJSON, CSV, XML, test fixtures, seeds) into a `data/` or `fixtures/` subfolder.
- Code and static data/media should not sit side-by-side in flat lists.

### 2. Cross-Cutting vs Feature-Local Scoping
- **Shared / Cross-cutting**: Generic, reusable utilities, base types, or universal hooks that do not depend on a specific business domain belong at the shared parent or core level (e.g., `src/shared/`, `Core/Common/`).
- **Feature-local**: Domain-specific UI, controllers, hooks, services, and styles belong together in cohesive feature folders (e.g., `components/`, `hooks/`, `Endpoints/`).

### 3. Deconstruct Kitchen-Sink Files
When a file named `helper.*`, `utils.*`, or `common.*` accumulates multiple distinct responsibilities:
- Split it into focused, single-responsibility files:
  - **Context / State**: React contexts, providers, or state stores.
  - **Styles / Layout**: Presentation calculators, class maps, or styling functions.
  - **Types / Contracts**: Data transfer objects, interfaces, models, and type guards.
  - **Logic / Domain**: Pure business logic or transformation functions.
- If existing external code imports heavily from the old location, maintain backward compatibility initially by re-exporting from the original file, marking it deprecated if applicable.

### 4. Inline Logic & State Extraction
- Extract non-trivial inline state, complex calculations, and side effects from large presentation files into dedicated custom hooks or service classes.
- Keeps UI components declarative and focused purely on presentation, rendering, and accessibility.

### 5. Clean Public Boundaries vs Circular Dependency Guards
- **TypeScript / JavaScript**: Provide an `index.ts` barrel file at subsystem roots for clean public exports (`import { Widget } from '~/features/dashboard'`).
  - *Caution*: Never create circular imports across barrel files. If module A imports from module B's barrel and module B imports from module A's barrel, use direct deep imports instead.
- **C# / .NET**: Align namespaces with the folder hierarchy using file-scoped namespaces (`namespace Project.Features.Dashboard;`). Update solution folders and project references when relocating classes.
- **Python**: Maintain explicit `__all__` in `__init__.py` for public package surfaces, or use absolute package imports to avoid relative import ambiguity.

### 6. Zero Regressions & Git Preservation
- Preserve git blame, commit histories, and review annotations by using `git mv`.
- Account for filesystem nuances: on macOS / Windows (case-insensitive filesystems), case-only renames (e.g., `git mv file.ts File.ts`) must use `git mv -f` or a two-step move.

---

## 3. Step-by-Step Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. DISCOVERY & DEPENDENCY MAPPING                           │
│    Catalog directory, scan imports, trace string paths      │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. DRAFT REORGANIZATION PLAN ARTIFACT                       │
│    Write <prefix>-organize_plan-<suffix>.md at the root     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. THE APPROVAL GATE                                        │
│    Present before/after tree; await user /proceed           │
└──────────────────────────────┬──────────────────────────────┘
                               │ (User approves)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. ATOMIC PHYSICAL MIGRATION                                │
│    git mv files, isolate assets, create clean subfolders    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. REFERENCE REALIGNMENT                                    │
│    Rewrite imports, aliases, namespaces, test fixtures      │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. AUTOMATED QUALITY GATE                                   │
│    Format, lint, typecheck, build, run targeted tests       │
└─────────────────────────────────────────────────────────────┘
```

### Phase 1: Deep Discovery & Dependency Mapping

1. **Catalog the Target Directory**:
   - List all files, extensions, and sizes in the target path.
   - Categorize every file: Component, Hook/Service, Model/Type, Utility, Static Asset, Dataset/Fixture, Test Spec, or Config.
2. **Map Inbound & Outbound References**:
   - Grep for import statements referencing the directory or any contained file across the entire repository.
   - Grep for non-code references:
     - Dynamic imports: `import(...)`, `require(...)`, `import.meta.glob(...)`
     - CSS/SCSS asset paths: `url(...)`
     - Test fixture loaders: `readFile(...)`, `new URL(..., import.meta.url)`
     - Configuration files: `tsconfig.json`, `vite.config.*`, `.csproj`, Dockerfiles.
3. **Check Working Tree State**:
   - Check `git status` to ensure the directory is not in a tangled, dirty merge state before beginning moves.

### Phase 2: Formulate the Reorganization Plan Artifact

Create `<prefix>-organize_plan-<suffix>.md` at the **workspace root** adhering to the **`artifact-protocol`** protocol:
- Prefix `<prefix>-` includes both the host and active AI model: `<host>-<model>-` (e.g. `antigravity-gemini-3.8-flash-` or `claude-opus-5.5-`).
- Append descriptive `<suffix>` based on the target directory or component.

#### Artifact Structure:

```markdown
# Reorganization Plan: <Subsystem / Directory Name>

## 1. Context & Rationale
- Target Directory: `path/to/target/`
- Primary Issues: Flat mixed concerns, kitchen-sink helpers, unisolated static assets.

## 2. Structural Comparison (Before vs. Target)

### Before:
path/to/target/
├── logo.svg
├── data-dump.json
├── MyComponent.tsx
├── MyComponent.module.css
├── useMyComponentLogic.ts
├── helper.ts
└── generic-math.ts

### Target:
path/to/target/
├── index.ts                     # Public API barrel export
├── assets/
│   └── logo.svg                 # Static media isolation
├── data/
│   └── data-dump.json           # Fixtures & static datasets
├── components/
│   ├── MyComponent.tsx
│   └── MyComponent.module.css
├── hooks/
│   └── useMyComponentLogic.ts   # Extracted or isolated state
└── utils/
    ├── math.ts                  # Split from generic-math
    └── formatting.ts            # Split from kitchen-sink helper

## 3. Migration Breakdown
1. Move static assets to `assets/` and datasets to `data/` via `git mv`.
2. Split `helper.ts` into single-responsibility utilities.
3. Establish root `index.ts` with public exports.
4. Update internal and external import references.

## 4. Verification & Quality Checklist
- [ ] Format files with workspace formatter
- [ ] Lint check clean
- [ ] Typecheck / Build passing
- [ ] Targeted tests passing
```

### Phase 3: The Approval Gate

Present a high-signal summary in the chat with a direct link to `<prefix>-organize_plan-<suffix>.md`.
Then wait for confirmation (Golden Invariant 2). This holds even when the user named the exact moves:
```text
I have drafted the reorganization plan in [antigravity-<model>-organize_plan-<suffix>.md](file://<workspace-root>/antigravity-<model>-organize_plan-<suffix>.md#L8).
To proceed with the physical migration, please reply with `/proceed`.
```

### Phase 4: Atomic Physical Migration

Once approved, perform the migration in controlled, atomic steps:

1. **Create Destination Subdirectories**:
   ```bash
   mkdir -p path/to/target/assets path/to/target/data path/to/target/components path/to/target/hooks
   ```
2. **Execute Moves with `git mv`**:
   ```bash
   git mv path/to/target/logo.svg path/to/target/assets/
   git mv path/to/target/data-dump.json path/to/target/data/
   ```
3. **Handle Case-Only Renames Safely**:
   - On macOS/Windows case-insensitive systems, renaming `foo.ts` to `Foo.ts` requires:
     ```bash
     git mv -f path/to/foo.ts path/to/Foo.ts
     ```
4. **Deconstruct Kitchen-Sink Files**:
   - Create new focused files (`context.ts`, `styles.ts`, `types.ts`).
   - Extract code cleanly preserving type safety.
   - Re-export symbols from original file if backwards compatibility is needed.

### Phase 5: Code & Reference Realignment

1. **Update Internal Relative Imports**:
   - Rewrite relative paths within moved files (e.g., `../assets/logo.svg` or `../hooks/useFeature`).
2. **Update External Consumers**:
   - Where public barrels exist, update consumer imports to point to the clean barrel or updated path.
   - Where project aliases exist (`@/`, `~/`), align paths to the canonical alias pattern.
3. **Update Namespaces (C# / .NET)**:
   - Synchronize file-scoped namespaces with the new folder path (`namespace App.Features.Subsystem.Components;`).
   - Update `using` directives in referencing classes.
4. **Update Non-Code and Test References**:
   - Update relative filesystem paths in tests (`readFileSync`, asset loaders, jest/vitest mocks).
   - Update CSS `url()` references and markdown documentation links.

### Phase 6: Automated Quality Gate

Execute the project's quality verification suite in order:

1. **Format Check / Fix**:
   - Run the workspace formatter on the moved and edited files only (e.g. `npx prettier --write <files>`, `dotnet format --include <files>`). A whole-repo format run rewrites unrelated files and buries the reorganization in the diff.
2. **Linter Verification**:
   - Run workspace linter (e.g., `npm run lint` or `eslint`).
3. **Typecheck & Compilation**:
   - Run compiler check (e.g., `npx tsc --noEmit`, `npm run build`, `dotnet build`).
4. **Targeted Test Execution**:
   - Run test suites covering the moved and consuming modules (e.g., `npm test -- path/to/subsystem`, `dotnet test --filter ...`).
   - Confirm zero broken tests.

---

## 4. Ecosystem-Specific Nuances

### TypeScript / JavaScript (React, Next.js, Vite)
- **Barrels**: Keep `index.ts` strictly for public boundary exports. Never re-export internal implementation details that cause circular graphs.
- **Path Aliases**: Check `tsconfig.json` or `jsconfig.json` `paths`. If a new feature folder is created, check if a path alias should be registered or used.
- **CSS Modules & Assets**: Ensure asset imports (`import icon from './assets/icon.svg'`) resolve properly under the bundler.

### C# / .NET (FastEndpoints, EF Core, Clean Architecture)
- **Namespaces**: In .NET 6+, use file-scoped namespaces matching the folder structure (`namespace Solution.Project.Folder;`).
- **Project Items**: Modern SDK-style `.csproj` projects automatically glob all files in the directory. However, check `.csproj` for explicit `<Compile Remove="...">`, `<EmbeddedResource>`, or `<Content>` items that specify explicit paths.
- **EF Core Migrations**: Never manually move or rename files inside `Migrations/` without running the EF Core CLI tools or following [`squash-ef-core-migrations`](../squash-ef-core-migrations/SKILL.md).

### Python
- **Package Markers**: Ensure newly created subdirectories contain `__init__.py` if required for package resolution.
- **Imports**: Prefer absolute project-root imports (`from myapp.features.subsystem import worker`) over deeply nested relative imports (`from ....utils import worker`).
- **Tooling**: Run `ruff check`, `mypy`, or `pytest` to verify imports.

---

## 5. Deliverables & Output Protocol

When reporting results to the user, format your chat response cleanly:

1. **Clickable Link to Plan Artifact**:
   - **Antigravity IDE**: `📄 [antigravity-<model>-organize_plan-<suffix>.md](file://<workspace-root>/antigravity-<model>-organize_plan-<suffix>.md#L8)`
   - **Claude Code**: `📄 [claude-<model>-organize_plan-<suffix>.md](claude-<model>-organize_plan-<suffix>.md#L8)`
2. **Structural Comparison**: Render the concise Before vs. After directory tree.
3. **Key Extractions & Refactorings**: Bulleted summary of split files, isolated assets, and new hooks.
4. **Verification Evidence**: Clean reporting of linter, typecheck, build, and test outcomes confirming zero regressions.
