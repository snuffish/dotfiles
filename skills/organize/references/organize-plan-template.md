# Reorganization Plan Artifact Template (`<prefix>-organize_plan-<suffix>.md`)

Written at the **workspace root** via `artifact-protocol` › _Claim_.

```markdown
<!-- artifact-owner: … -->

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
