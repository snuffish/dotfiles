---
name: organize
description: Guides, designs, and executes safe, systematic codebase directory and file reorganization. Resolves mixed concerns, isolates static assets and datasets, extracts cross-cutting utilities and component-internal hooks, splits kitchen-sink helpers into focused modules, provides clean public barrel APIs, and verifies zero regressions.
---

# Skill: `/organize` — Codebase & Directory Reorganization

Systematically restructures codebase directories and files to eliminate clutter, untangle mixed concerns, and establish clean architectural boundaries. Preserves git history with `git mv`, protects consumer contracts with barrel files, and verifies zero regressions via automated quality checks.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/organize` (with or without a target directory or file list).
- The user asks to *"organize these files"*, *"clean up this folder structure"*, *"separate concerns in folder X"*, or *"how should we organize this directory?"*.
- A directory has grown into a flat list of mixed concerns (e.g. components, static assets, heavy datasets, hooks, and styles all in one folder).
- A helper file has become a kitchen-sink dumping ground with multiple unrelated responsibilities.

---

## 2. Core Architectural Principles

When organizing any directory or subsystem, apply these six principles:

### 1. Asset & Dataset Isolation
- Move static media (images, icons, fonts) into an `assets/` subfolder.
- Move large static datasets (JSON, GeoJSON, CSV, fixtures) into a `data/` subfolder.
- Code and static data should not sit side-by-side in flat lists.

### 2. Cross-Cutting vs Feature-Local Scoping
- Generic, reusable utilities and hooks that do not depend on a specific sub-feature belong at the shared parent level (e.g. `hooks/use-geojson-asset.ts`).
- Feature-specific UI, hooks, and styles belong together in cohesive feature folders (e.g. `components/`, `hooks/`).

### 3. Deconstruct Kitchen-Sink Files
- When a file named `helper.ts`, `utils.ts`, or `common.ts` accumulates multiple distinct responsibilities (e.g., React Context + presentation styles + layer guards + type definitions), split it into focused, single-responsibility files:
  - `context.ts`: React context, Provider, and consumer hook.
  - `styles.ts`: Presentation calculators, class maps, or styling functions.
  - `types.ts`: Type definitions, interfaces, and type guards.
- Retain backward compatibility by re-exporting from the original file if widespread imports exist.

### 4. Inline Logic & State Extraction
- Extract non-trivial inline state and derived calculations (e.g., search input state, list filtering `useMemo`, pagination, multi-select toggling) from large view components into dedicated custom hooks in `hooks/` (e.g., `useRegionSearch.ts`).
- Keeps UI components declarative and focused purely on layout and presentation.

### 5. Clean Public APIs via Barrel Exports
- Provide an `index.ts` barrel file at the subsystem root that exports public components, dialogs, hooks, and contracts.
- Shields consumers across the project from internal directory reshuffling:
  ```ts
  // Clean, resilient consumer import:
  import { LocationMap, MunicipalityMapSelectionDialog } from '~/components/maps';
  ```

### 6. Zero Regressions & Git History Preservation
- Use `git mv` for all file moves so file history, annotations, and blame are preserved.
- Inspect and update all relative imports, including unit, integration, and E2E test specs that reference data files or modules by path.

---

## 3. Step-by-Step Workflow

### Step 1: Discovery & Dependency Mapping
1. **Catalog the target directory**:
   - List all files, file sizes, and subdirectories.
   - Categorize each file: component, style, generic hook, feature hook, static asset, data file, helper, or test.
2. **Identify incoming references**:
   - Search the codebase for imports referencing the target directory and its files.
   - Note any test files that load data files using relative disk paths (e.g. `readFileSync` or `new URL(..., import.meta.url)`).

### Step 2: Formulate & Present the Target Structure
Present a clear before/after comparison to the user or implementation plan:
```
Before:                                  Target:
src/feature/                             src/feature/
├── icon.png                             ├── index.ts              # Public API
├── data.json                            ├── assets/
├── feature-component.tsx                │   └── icon.png
├── feature-component.module.css         ├── data/
├── use-feature.ts                       │   └── data.json
├── helper.ts                            ├── hooks/
└── generic-util.ts                      │   └── use-feature.ts
                                         ├── components/
                                         │   ├── feature-component.tsx
                                         │   └── feature-component.module.css
                                         └── helper.ts             # Focused or backward-compat re-export
```

### Step 3: Execute Reorganization
1. **Create target directories**:
   ```bash
   mkdir -p path/to/assets path/to/data path/to/hooks path/to/components
   ```
2. **Move files using `git mv`**:
   ```bash
   git mv path/to/icon.png path/to/assets/
   git mv path/to/data.json path/to/data/
   ```
3. **Extract inline logic / hooks**:
   - If a component has inline filtering or state logic, extract it into a dedicated hook in `hooks/`.
4. **Deconstruct kitchen-sink files**:
   - Split multi-purpose helper files into single-responsibility modules.
5. **Update internal relative imports**:
   - Update `import` statements in moved files and their sibling components.
6. **Establish / update barrel exports**:
   - Ensure the directory's `index.ts` cleanly re-exports all public symbols.
7. **Update external consumers and test specs**:
   - Update external import paths if needed, or rely on the updated barrel.
   - Update relative filesystem paths in tests.

### Step 4: Verification & Quality Gate
1. **Format files**:
   - Run workspace formatter (e.g. `npx prettier --write`).
2. **Lint check**:
   - Run workspace linter (e.g. `npm run lint` or `dotnet format --verify-no-changes`).
3. **Type check & Build**:
   - Run type checking and build (e.g. `tsc -b`, `npm run build`, `dotnet build`).
4. **Run relevant tests**:
   - Execute unit and integration tests covering the affected module to verify zero regressions.

---

## 4. Output Deliverables

When presenting the reorganization to the user:
1. **Directory Tree**: Display the clean before-and-after tree structure.
2. **Key Changes**: Summarize extractions (new hooks, split helpers, isolated assets).
3. **Verification Results**: Report lint, build, and test run outcomes confirming zero broken references.
