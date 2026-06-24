---
name: source-command-frontend-health-check
description: "[Project: GR.PRIIS.Frontend] Audit the frontend codebase for convention violations and generate a health scorecard. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# source-command-frontend-health-check

Use this skill when the user asks to run the migrated source command `health-check` for the GR.PRIIS.Frontend project.

## Command Template

# /health-check — Frontend Health Audit

Scan the frontend source (`source/priis-web/src/`) for convention drift and produce a health report. Use when onboarding to the codebase, before a large refactor, or to track quality over time.

---

## Inspection Areas

### 1. Relative Imports

Count `from '../` or `from '../../` patterns in all `.ts/.tsx` files under `source/priis-web/src/`.
Expected: **zero**. All imports must use path aliases (`~`, `~components/`, `~features/`, `~api`, `~enums/`, `~strings/`).

### 2. Zod v3 Imports

Count `from 'zod'` (without `/v4`) in `source/priis-web/src/**/*.ts` and `*.tsx`.
Expected: **zero**. All Zod usage must import from `'zod/v4'`.

Also check for old resolver: `from '@hookform/resolvers/zod'`
Expected: **zero**. Must use `~/utility/validation/zod-v4-resolver`.

### 3. Inline Styles

Count `style={{` in `.tsx` files under `source/priis-web/src/`.
Expected: near zero. Inline styles should use CSS Modules instead. Flag occurrences for review.

### 4. TypeScript Suppressions

Count `// @ts-ignore` and `// @ts-expect-error` in `source/priis-web/src/`.
Expected: **zero**. Type errors must be fixed, not suppressed.

### 5. Console Logs in Source

Count `console.log(` in `source/priis-web/src/`.
Expected: **zero** in committed code.

### 6. RTK Query Adoption

Count `fetch(` and `axios.` calls in `source/priis-web/src/` excluding `store/`.
Expected: **zero**. All API calls must go through RTK Query hooks.

### 7. Mutations Without `invalidatesTags`

For each `builder.mutation(` in `source/priis-web/src/store/api/endpoint-builders/**/*.ts`, check whether it has an `invalidatesTags` field.
Flag mutations that do not invalidate any tags — these can cause stale UI after mutations.

### 8. Route → E2E Spec Coverage

For each file in `source/priis-web/src/routes/` (excluding `__root.tsx`, layout files, and `routeTree.gen.ts`), check whether any `.spec.ts` in `source/priis-web/e2e/` references its route path or related test IDs.
List routes with no corresponding E2E coverage.

### 9. Hardcoded English UI Text

Sample JSX in `source/priis-web/src/features/` for common English UI patterns:
- English placeholder text in `<input placeholder=`
- English button labels (e.g., `"Save"`, `"Cancel"`, `"Submit"`)
- English error messages not using `ErrorMessages.*`

All user-visible text must be Swedish. Flag files with obvious English strings.

### 10. SystemAction Sync

Read `source/priis-web/src/enums/systemAction.ts` and list all enum values.
If the backend repo is accessible at `d:\GR.PRIIS.Backend`, cross-check against `source/GR.PRIIS.Library/Common/Users/AccessRules/SystemActionTexts.cs` for missing entries.
Flag any values present in one but not the other.

---

## Output Format

```markdown
## Frontend Health Check — {date}

### Summary

| Area                         | Status  | Issues |
|------------------------------|---------|--------|
| 1. Relative imports          | ✅ PASS |      0 |
| 2. Zod v3 imports            | ✅ PASS |      0 |
| 3. Inline styles             | ⚠️ WARN |      4 |
| 4. TypeScript suppressions   | ✅ PASS |      0 |
| 5. Console logs              | ✅ PASS |      0 |
| 6. RTK Query adoption        | ✅ PASS |      0 |
| 7. Mutations without tags    | ⚠️ WARN |      2 |
| 8. E2E coverage gaps         | ⚠️ WARN |      6 |
| 9. Hardcoded English text    | ⚠️ WARN |      3 |
| 10. SystemAction sync        | ✅ PASS |      0 |

### Detailed Findings

#### 3. Inline Styles
- `source/priis-web/src/features/foo/foo-list.tsx:34` — `style={{ marginTop: '8px' }}`
...

#### 7. Mutations Without invalidatesTags
- `source/priis-web/src/store/api/endpoint-builders/foo/index.ts:22` — `updateFoo` mutation has no invalidatesTags
...

#### 8. E2E Coverage Gaps
- `/suppliers/$supplierId/notes` — no spec found
...

### Priority Actions

1. **High** — Add `invalidatesTags` to mutations (stale UI risk)
2. **Medium** — Replace inline styles with CSS Modules
3. **Low** — Fill E2E coverage gaps for key user flows
```
