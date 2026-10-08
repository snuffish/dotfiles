---
name: source-command-frontend-verify
description: "[Project: GR.PRIIS.Frontend] Run all quality checks before committing — lint, build, and anti-pattern scan. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# source-command-frontend-verify

Use this skill when the user asks to run the migrated source command `verify` for the GR.PRIIS.Frontend project.

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../../../core/SKILL.md)** operating standards and the **[artifacts](../../../artifacts/SKILL.md)** delivery protocol.
- **Target Artifact**: none — the PASS/FAIL table is printed in chat. Read-only.

---

## Command Template

# /verify — Quality Gate

Run all phases before `git add / git commit`. All npm commands run from `source/priis-web/`.

---

## Phase 1: Lint

```bash
cd source/priis-web && npm run lint
```

**Zero warnings allowed.** List each warning with file:line. Do not proceed to commit if any warnings remain.

---

## Phase 2: Build

```bash
cd source/priis-web && npm run build
```

TypeScript compile errors and Vite bundle issues surface here. Must complete with zero errors.

---

## Phase 3: Anti-Pattern Scan

Grep the changed `.ts/.tsx` files (use `git diff --name-only HEAD` or scan all in `source/priis-web/src/`) for the following violations. Report each hit as `FILE:LINE — explanation`.

### Imports
- `from ['"]\.\.` (starts with `../` or `../../`) — relative imports forbidden; use `~` path aliases
- `from ['"]zod/v4['"]` — legacy subpath; must be `from 'zod'` (v4 is the pinned package)
- `from ['"]~/utility/validation/zod-v4-resolver['"]` — file no longer exists; use `@hookform/resolvers/zod`

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

## Phase 4: SystemAction Sync (conditional)

Only check this if `openapi/swagger.json` or the generated `SystemAction` enum changed in this commit (`src/enums/systemAction.ts` is a generated facade — a hand edit there is itself a finding).

If it did, remind:
1. Verify the backend member exists in `AccessRules/Actions/SystemAction.cs` with `[Display(Name = "…")]` and is granted in `AccessRules/Roles/<Role>AccessRules.cs`
2. Verify the action is wired into `top-menu-items.ts` `actions` and the tab's `systemActions` where it gates UI
3. Flag as TODO if the backend repo is not in scope of this changeset

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
- `source/priis-web/src/features/foo/schema.ts:1` — `from 'zod/v4'`; must be `from 'zod'`

### Verdict

⚠️ **Not ready to commit** — fix 2 anti-pattern issues above, then re-run.
```

---

> [!IMPORTANT]
> `npm run organize-imports` runs `scripts/organize-changed-imports.mjs` (since 2026-09-17) and only touches files the
> working tree has changed, so it is safe after editing. **Never run `npm run organize-imports:all`** — it rewrites
> imports across the whole `src/` tree and buries your change under unrelated files. CI gates on neither;
> `npm run lint` and `npm run build` are the checks that matter. Check `git status` afterwards and
> `git checkout --` anything you did not edit.
>
> If a file you actually edited has messy imports, fix that file by hand.
