---
name: source-command-backend-verify
description: "[Project: GR.PRIIS.Backend] Run all quality checks before committing — format, build, anti-pattern scan, tests, and architecture validation. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# source-command-verify

Use this skill when the user asks to run the migrated source command `verify`.

## Command Template

# /verify — Quality Gate

Run all phases before `git add / git commit`. Report PASS/FAIL for each phase and a final verdict.

---

## Phase 1: Format

```bash
dotnet format
```

If any files were changed by `dotnet format`, list them. Format must be clean before committing — CI enforces this.

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

Report failures by project and test name. If only touching a specific feature, you may run the focused test project:

```bash
dotnet test --project tests/GR.PRIIS.API.IntegrationTests.TUnit --configuration Release
```

---

## Phase 5: Architecture Tests

```bash
dotnet test tests/GR.PRIIS.ArchitectureTests --configuration Release
```

Enforces the **API → Library only** dependency rule. A failure here means a project reference was added that crosses the boundary.

---

## Phase 6: SystemAction Sync (conditional)

Only check this if `SystemAction` enum values were added or renamed in this changeset.

If they were, verify all three sync points:
1. `source/GR.PRIIS.Library/Common/Users/AccessRules/UserRoleAccessRules.cs` — enum value present in the correct numeric range and added to relevant role AllowedActions
2. `source/GR.PRIIS.Library/Common/Users/AccessRules/SystemActionTexts.cs` — Swedish display name present
3. **Remind:** the frontend `systemAction.ts` enum must also be updated (separate repo — flag as a TODO if not already done)

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
