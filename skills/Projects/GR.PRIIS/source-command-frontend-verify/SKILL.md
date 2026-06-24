---
name: source-command-frontend-verify
description: "[Project: GR.PRIIS.Frontend] Run all quality checks before committing — organize imports, lint, build, and anti-pattern scan. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# source-command-frontend-verify

Use this skill when the user asks to run the migrated source command `verify` for the GR.PRIIS.Frontend project.

## Command Template

# /verify — Quality Gate

Run all phases before `git add / git commit`. All npm commands run from `source/priis-web/`.

---

## Phase 1: Organize Imports

```bash
cd source/priis-web && npm run organize-imports
```

Sorts imports and applies Prettier formatting to `.ts/.tsx` files. Run this first — CI expects clean, sorted imports. List any files changed.

---

## Phase 2: Lint

```bash
cd source/priis-web && npm run lint
```

**Zero warnings allowed.** List each warning with file:line. Do not proceed to commit if any warnings remain.

---

## Phase 3: Build

```bash
cd source/priis-web && npm run build
```

TypeScript compile errors and Vite bundle issues surface here. Must complete with zero errors.

---

## Phase 4: Anti-Pattern Scan

Grep the changed `.ts/.tsx` files (use `git diff --name-only HEAD` or scan all in `source/priis-web/src/`) for the following violations. Report each hit as `FILE:LINE — explanation`.

### Imports
- `from ['"]\.\.` (starts with `../` or `../../`) — relative imports forbidden; use `~` path aliases
- `from ['"]zod['"]` — must be `from 'zod/v4'`
- `from ['"]@hookform/resolvers/zod['"]` — must use `~/utility/validation/zod-v4-resolver`

### Styling
- `style={{` in JSX — use CSS Modules (`.module.css`) instead of inline styles

### TypeScript
- `// @ts-ignore` or `// @ts-expect-error` — fix the type error, don't suppress
- `: any` type annotation — narrow the type properly

### Code quality
- `console.log(` in `src/` — remove before committing
- `fetch(` or `axios.` in `src/` outside `store/` — use RTK Query hooks instead

### Localization
- Hardcoded English text in JSX (labels, placeholder text, button text, error messages) — all user-visible text must be in Swedish; use `~strings/error-messages` for standard messages

---

## Phase 5: SystemAction Sync (conditional)

Only check this if `src/enums/systemAction.ts` was changed in this commit.

If it was, remind:
1. Verify backend `UserRoleAccessRules.cs` has matching entries
2. Verify backend `SystemActionTexts.cs` has Swedish display names for all new values
3. Flag as TODO if backend repo is not in scope of this changeset

---

## Output Format

```
## Verify Results

| Phase                  | Status  | Notes                          |
|------------------------|---------|--------------------------------|
| 1. Organize imports    | ✅ PASS |                                |
| 2. Lint                | ✅ PASS |                                |
| 3. Build               | ✅ PASS |                                |
| 4. Anti-pattern scan   | ⚠️ WARN | 2 issues (see below)           |
| 5. SystemAction sync   | N/A     | No enum changes                |

### Issues Found

**Phase 4 — Anti-patterns:**
- `source/priis-web/src/features/foo/foo-form.tsx:12` — `from '../../store/api'`; use `~api` instead
- `source/priis-web/src/features/foo/schema.ts:1` — `from 'zod'`; must be `from 'zod/v4'`

### Verdict

⚠️ **Not ready to commit** — fix 2 anti-pattern issues above, then re-run.
```
