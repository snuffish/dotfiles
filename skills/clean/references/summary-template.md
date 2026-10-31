# Clean Summary Template

Used in chat for single-file `/clean` runs and per file in `<prefix>-clean_report-<suffix>.md` for directory / multi-file runs. Link files using `artifact-protocol` › *Host-Specific Link Formats*; omit empty sections.

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
