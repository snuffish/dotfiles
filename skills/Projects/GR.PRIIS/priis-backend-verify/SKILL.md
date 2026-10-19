---
name: priis-backend-verify
description: "[Project: GR.PRIIS.Backend] Run all quality checks before committing — format, build, anti-pattern scan, tests, and architecture validation. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# priis-backend-verify

Use this skill when the user asks to run `/priis-backend-verify`.

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../../../_modules/core.md`
- `../../../_modules/artifact-protocol.md`: writes no artifact — the PASS/FAIL table is printed in chat
- `../../../_modules/git-worktrees.md`

- Read-only apart from `dotnet format`, which only rewrites files you already changed.
- **Repo root** without a `[worktree-context]` block: the backend repo in the workspace. Every `dotnet` command below runs from `<repo-root>` — `(cd <repo-root> && dotnet …)` in a subshell, so the session's working directory never moves. A worktree lacks the ignored `appsettings.local.json` files; the profile's *Worktree include list* copies them before this skill runs, otherwise the integration suite targets the wrong database.

---

## Command Template

# /priis-backend-verify — Quality Gate

Run all phases before `git add / git commit`, from `<repo-root>`. Report PASS/FAIL for each phase and a final verdict.

---

## Phase 1: Format

```bash
pwsh -NoProfile -File ./scripts/format-changed.ps1
```

This runs `dotnet format` only on the C# files changed vs `origin/main` (committed, staged, unstaged and untracked). It automatically falls back to the whole solution when formatting config or a `global using` changed. Pass `-All` to force a full run, or `-Base origin/release/X.Y.Z` on a hotfix branch. Don't pass `-Verify` — it only reports and does not fix anything.

If any files were changed by the format run, list them. Format must be clean before committing: PR builds don't check formatting (only a weekly sweep does), so this run is the check.

---

## Phase 2: Build

```bash
dotnet build --configuration Release
```

Must produce **zero errors and zero warnings**. The project uses `TreatWarningsAsErrors`. Do not proceed to later phases if the build fails.

---

## Phase 3: Anti-Pattern Scan

Grep the changed `.cs` files (use `git diff --name-only HEAD` to find them, or scan all if on a fresh branch) for the following violations. Report each hit as `FILE:LINE — explanation`.

### EF Core
- `.Include(` combined with `.AsNoTracking()` in `source/GR.PRIIS.API/` — read-only queries must use `.Select()` projections instead of `.Include()`
- `.AsNoTracking()` on a chain that returns an entity type (not a DTO/record) — must project to a DTO

### Collections
- `new List<`, `new []`, `Array.Empty<`, `Enumerable.Empty<` — use collection expressions `[]` instead

### Error handling
- `throw new` inside `source/GR.PRIIS.Library/Features/` (outside exception filters) — use `return SystemResult.Failure(...)` instead

### Async safety
- `async void` methods (except event handlers) — use `async Task`
- `.Result` or `.Wait()` on a `Task` — use `await`

### Naming
- Classes ending in `Service`, `Handler`, `Manager`, `Helper`, `Processor` in non-test source code — prefer descriptive domain names

### Signatures
- `async` methods in source code that lack a `CancellationToken ct` parameter — all async methods should accept a cancellation token

---

## Phase 4: Tests

```bash
dotnet test --configuration Release
```

Report failures by project and test name. A full local run flakes under TestContainers load (dozens of varying integration timeouts): re-run the failing groups alone with `--treenode-filter` before blaming the change. If only touching a specific feature, you may run the focused test project:

```bash
dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/<ClassName>/*"   # TUnit/MTP: --treenode-filter, never --filter
```

---

## Phase 5: Architecture Tests

```bash
dotnet test --project tests/GR.PRIIS.ArchitectureTests --configuration Release
```

Enforces the **API → Library only** dependency rule. A failure here means a project reference was added that crosses the boundary.

---

## Phase 6: SystemAction Sync (conditional)

Only check this if `SystemAction` enum values were added or renamed in this changeset.

If they were, verify all three sync points:
1. `source/GR.PRIIS.Library/Common/Users/AccessRules/Actions/SystemAction.cs` — member in the correct numeric range with a Swedish `[Display(Name = "…")]` (there is no separate label file; `SystemActionTexts.cs` only maps ranges to category names)
2. `source/GR.PRIIS.Library/Common/Users/AccessRules/Roles/<Role>AccessRules.cs` — added to `AllowedActions` of every role that needs it, and only those
3. **Remind:** the frontend regenerates `src/enums/systemAction.ts` from the OpenAPI snapshot (`npm run codegen` after patching `openapi/swagger.json`), then wires the action into `top-menu-items.ts` / tab `systemActions` — flag as a TODO if the frontend repo is not in scope

---

## Output Format

```
## Verify Results

| Phase                  | Status  | Notes                          |
|------------------------|---------|--------------------------------|
| 1. Format              | ✅ PASS |                                |
| 2. Build               | ✅ PASS |                                |
| 3. Anti-pattern scan   | ⚠️ WARN | 2 issues (see below)           |
| 4. Tests               | ✅ PASS |                                |
| 5. Architecture tests  | ✅ PASS |                                |
| 6. SystemAction sync   | N/A     | No enum changes                |

### Issues Found

**Phase 3 — Anti-patterns:**
- `source/GR.PRIIS.API/Features/Foo/GetFooEndpoint.cs:42` — `.Include(x => x.Items).AsNoTracking()` on a read-only query; replace with `.Select()`
- `source/GR.PRIIS.Library/Features/Foo/FooFactory.cs:18` — `new List<string>()` should be `[]`

### Verdict

⚠️ **Not ready to commit** — fix 2 anti-pattern issues above, then re-run.
```
