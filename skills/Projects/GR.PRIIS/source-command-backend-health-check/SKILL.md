---
name: source-command-backend-health-check
description: "[Project: GR.PRIIS.Backend] Audit the codebase against project conventions and generate a health scorecard. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# source-command-health-check

Use this skill when the user asks to run the migrated source command `health-check`.

## Command Template

# /health-check — Project Health Audit

Scan the entire codebase (or a specific feature area if specified) and produce a health report. Use this when onboarding to a feature area, before a large refactor, or to track convention drift over time.

---

## Inspection Areas

### 1. Dependency Rule

Scan all `.csproj` files for `<ProjectReference>` entries. Flag any that cross the allowed boundary.

**Allowed:** `API → Library`, `Worker → Library`, `CLI → Library`, `AppHost → *`
**Forbidden:** `Library → API`, `Library → Worker`, `API → Worker`, `Worker → API`

### 2. EF Core Patterns

In `source/GR.PRIIS.API/`:

- Count `.Include(` occurrences — each one in a read path is a violation (Include is fine in mutation paths but flag all for manual review)
- Count `.AsNoTracking()` on chains that return entity types without a `.Select()` — should project to DTOs

Grep patterns:
```
.Include(        in source/GR.PRIIS.API/**/*.cs
.AsNoTracking()  in source/GR.PRIIS.API/**/*.cs  (cross-reference — look for missing .Select())
```

### 3. Collection Expression Compliance

Count forbidden collection patterns across all `source/**/*.cs`:
```
new List<
new []{
Array.Empty<
Enumerable.Empty<
```
Report count per file. Should all be `[]` collection expressions.

### 4. SystemResult Compliance

Count `throw new` in `source/GR.PRIIS.Library/Features/**/*.cs`. Expected failures must return `SystemResult.Failure(...)`. Exceptions are only appropriate for truly unexpected conditions.

### 5. Naming Convention Violations

Count classes ending in `Service`, `Handler`, `Manager`, `Helper`, `Processor` in `source/**/*.cs` (excluding test projects and base/abstract framework types). Report by file.

### 6. TUnit Coverage Gaps

For every `*Endpoint.cs` in `source/GR.PRIIS.API/Features/`, check whether a matching `*EndpointTests.cs` exists anywhere under `tests/GR.PRIIS.API.IntegrationTests.TUnit/`.

Report:
- **Covered:** count
- **Uncovered:** list of endpoint filenames with no matching test file

### 7. SystemAction Sync

Read the `SystemAction` enum from `source/GR.PRIIS.Library/Common/Users/AccessRules/UserRoleAccessRules.cs`.

For each enum value, check whether it has an entry in `source/GR.PRIIS.Library/Common/Users/AccessRules/SystemActionTexts.cs`.

Report any enum values missing a Swedish display name.

### 8. FusionCache L2 Safety

Find all calls with `SkipDistributedCacheRead = false` or `SkipDistributedCacheWrite = false` across `source/**/*.cs`.

For each, check if it is wrapped in or near a `TransactionScope(TransactionScopeOption.Suppress, ...)`. Flag any that are not — an L2 cache call inside a transaction without suppression can cause data consistency issues.

---

## Output Format

```markdown
## Health Check Report — {date}

### Summary

| Area                        | Status  | Issues |
|-----------------------------|---------|--------|
| 1. Dependency rule          | ✅ PASS |      0 |
| 2. EF Core patterns         | ⚠️ WARN |      3 |
| 3. Collection expressions   | ⚠️ WARN |     12 |
| 4. SystemResult compliance  | ✅ PASS |      0 |
| 5. Naming conventions       | ⚠️ WARN |      2 |
| 6. TUnit coverage gaps      | ⚠️ WARN |      8 |
| 7. SystemAction sync        | ✅ PASS |      0 |
| 8. FusionCache L2 safety    | ✅ PASS |      0 |

### Detailed Findings

#### 2. EF Core Patterns
- `source/GR.PRIIS.API/Features/Foo/GetFooEndpoint.cs:55` — `.Include(x => x.Items)` in read path; replace with `.Select()`
- ...

#### 3. Collection Expressions
- `source/GR.PRIIS.Library/Features/Foo/FooFactory.cs:12` — `new List<string>()`
- ...

#### 6. TUnit Coverage Gaps (uncovered endpoints)
- `GetFooSummaryEndpoint.cs` — no matching test file found
- `DeleteFooEndpoint.cs` — no matching test file found
- ...

### Priority Actions

1. **High** — Fix EF Core Include violations (data consistency risk in read paths)
2. **Medium** — Fill TUnit coverage gaps for mutation endpoints (unauthorized/forbidden tests)
3. **Low** — Replace collection expression violations (style/convention)
```
