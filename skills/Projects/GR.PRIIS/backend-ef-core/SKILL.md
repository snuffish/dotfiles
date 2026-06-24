---
name: backend-ef-core
description: "[Project: GR.PRIIS.Backend] EF Core 10 patterns for GR.PRIIS.Backend — AsNoTracking/Select for reads, PriisDbContext usage, AuditableEntity, temporal tables, FusionCache integration, and dynamic predicates. Load when writing queries, migrations, or any data access code. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# EF Core 10 — Project Patterns

This skill covers how EF Core 10 is used in this specific codebase. These are not generic EF docs — every pattern here reflects what the project actually does.

---

## 1. Read Query Contract

**GET endpoints with no side effects:** always `AsNoTracking()` + `Select()` projection.

```csharp
// ✅ Correct — read-only query
var items = await dbContext.Operations
    .AsNoTracking()
    .Where(o => o.Status == OperationStatus.Active && o.SupplierId == supplierId)
    .Select(o => new OperationListItem
    {
        Id = o.Id,
        Name = o.Name,
        SupplierName = o.Supplier.Name,        // navigation via Select is fine
        ContactCount = o.Contacts.Count()      // aggregate via Select is fine
    })
    .OrderBy(o => o.Name)
    .ToListAsync(ct);

// ❌ Wrong — Include in a read-only query
var items = await dbContext.Operations
    .AsNoTracking()
    .Include(o => o.Supplier)                  // never Include for projection
    .Include(o => o.Contacts)
    .ToListAsync(ct);

// ❌ Wrong — returning entity types
var ops = await dbContext.Operations.ToListAsync(ct);  // missing AsNoTracking + Select
```

**`.Include()` is only appropriate in mutation paths** where you need to load and modify related entities (e.g., loading an aggregate root and its children before calling a command method). Never use it for pure read projections.

---

## 2. `IReadOnlyPriisDbContext` vs `PriisDbContext`

```csharp
// IReadOnlyPriisDbContext — inject in Library methods that only READ
public static async Task<SystemResult<Foo>> CreateAsync(
    CreateFooRequest req,
    IReadOnlyPriisDbContext dbContext,   // ← read-only interface
    CancellationToken ct = default)
{
    var exists = await dbContext.Foos.AsNoTracking().AnyAsync(..., ct);
}

// PriisDbContext — inject in endpoints and CLI commands that WRITE
public sealed class CreateFooEndpoint(
    PriisDbContext dbContext,            // ← full context
    ICurrentUser currentUser)
    : ExtendedEndpoint<CreateFooRequest, CreateFooResponse>
{ ... }
```

Do not inject `PriisDbContext` into Library methods that only perform reads — `IReadOnlyPriisDbContext` provides a clear, testable boundary.

---

## 3. AuditableEntity + Interceptor

All domain entities extend `AuditableEntity`. The `SaveChangesAsync` interceptor sets `ChangedBy` and `ChangedOnUTC` automatically — do not set them manually.

```csharp
// ✅ Correct — ChangedBy is set by interceptor on SaveChangesAsync
var note = new OperationNote { OperationId = req.Id, Content = req.Content };
dbContext.OperationNotes.Add(note);
await dbContext.SaveChangesAsync(ct);   // interceptor fills ChangedBy

// For bulk ExecuteUpdateAsync, use the overload that takes currentUser:
await dbContext.OperationNotes
    .Where(n => n.OperationId == operationId)
    .ExecuteUpdateAsync(
        setters => setters.SetProperty(n => n.Content, newContent),
        currentUser,    // passes ChangedBy to the update
        ct);

// ❌ Wrong — setting audit fields manually
entity.ChangedBy = currentUser.Id;
```

---

## 4. Temporal Table Queries

Entities with temporal tables expose history via `.TemporalAll()`:

```csharp
var history = await dbContext.Operations
    .TemporalAll()
    .Where(o => o.Id == operationId)
    .OrderByDescending(o => EF.Property<DateTime>(o, "PeriodEnd"))
    .Select(o => new OperationHistoryItem
    {
        Id = o.Id,
        Status = o.Status,
        ChangedBy = o.ChangedBy,
        ChangedAt = EF.Property<DateTime>(o, "PeriodEnd")
    })
    .ToListAsync(ct);
```

---

## 5. Paginated List

Use the `ToPaginatedListAsync` extension for all paginated endpoints:

```csharp
// Request must extend PaginatedRequest<TOrderByEnum, TItem>
var result = await dbContext.Operations
    .AsNoTracking()
    .Where(o => o.SupplierId == supplierId)
    .Select(o => new OperationListItem { Id = o.Id, Name = o.Name })
    .ToPaginatedListAsync(req, extraOrderBy: x => x.Id, ct);
```

The `PaginatedRequest` base handles page/size/sort-direction parsing. Override `GetOrderByExpression` in the request to map sort column enum values to expression trees.

---

## 6. FusionCache Rules

**L1 only by default.** Many cached types contain EF expression trees or non-serializable objects that cannot survive a JSON round-trip. Do not enable L2 unless the cached type is provably serializable.

```csharp
// ✅ L1 only (default) — safe for all types
var roles = await fusionCache.GetOrSetAsync(
    cacheKey,
    async _ => await LoadRolesAsync(ct),
    token: ct);

// ✅ L2 opt-in — only for JSON-serializable types
var config = await fusionCache.GetOrSetAsync(
    cacheKey,
    async _ => await LoadConfigAsync(ct),
    new FusionCacheEntryOptions { SkipDistributedCacheRead = false, SkipDistributedCacheWrite = false },
    token: ct);
```

**TransactionScope suppression is mandatory** when a cache call may execute inside an ambient transaction:

```csharp
// ✅ Correct — suppress transaction before cache call
using var scope = new TransactionScope(
    TransactionScopeOption.Suppress,
    TransactionScopeAsyncFlowOption.Enabled);
var result = await fusionCache.GetOrSetAsync(cacheKey, async _ => await LoadAsync(ct), token: ct);
scope.Complete();

// ❌ Wrong — cache inside transaction without suppression (deadlock / consistency risk)
using var tx = new TransactionScope(...);
var result = await fusionCache.GetOrSetAsync(...);  // could write to L2 inside transaction
```

---

## 7. Dynamic Predicates

Use `PredicateBuilder.New<T>()` from LinqKit for dynamic `WHERE` clauses. The `ExpandingQueryExpressionInterceptor` is registered globally and expands these at query time.

```csharp
// Building a tokenized search predicate
var predicate = PredicateBuilder.New<Operation>(true);

if (!string.IsNullOrWhiteSpace(req.Search))
{
    var tokens = req.Search.BuildTokenizedPredicate<Operation>(
        o => o.Name,
        o => o.Description);
    predicate = predicate.And(tokens);
}

if (req.StatusFilter.Count > 0)
    predicate = predicate.And(o => req.StatusFilter.Contains(o.Status));

var result = await dbContext.Operations
    .AsNoTracking()
    .AsExpandable()        // required for PredicateBuilder
    .Where(predicate)
    .Select(...)
    .ToPaginatedListAsync(req, extraOrderBy: x => x.Id, ct);
```

---

## 8. System Accounts

Two special account GUIDs are used in seed data and correction scripts:

```csharp
// SystemAccountId — for system-initiated actions (automated processes, seeds)
public static readonly Guid SystemAccountId = new("00000000-0000-0000-0000-00000000ABCD");

// SupportAccountId — for manual corrections, data fixes, support scripts
public static readonly Guid SupportAccountId = new("00000000-0000-0000-0000-00000000DCBA");
```

Use `SupportAccountId` in correction migration scripts. Use `SystemAccountId` only for system-triggered operations. They are not interchangeable — audit trails distinguish them.

---

## 9. Active Interceptors — Do Not Disable

Two interceptors are registered globally in `Setup.cs`:

- **`ExpandingQueryExpressionInterceptor`** — expands LinqKit `PredicateBuilder` expression trees at query time. Required for any query using `.AsExpandable()`. Do not remove.
- **`SlowQueryLoggingInterceptor`** — logs queries exceeding the configured threshold. If a query is slow, optimize it — do not disable the interceptor or add query hints to silence it.

---

## 10. Anti-Patterns Checklist

```
❌ .Include() in read-only GET endpoints — use .Select() navigation
❌ Missing .AsNoTracking() on read queries in API layer
❌ Returning EF entity types from endpoints
❌ PriisDbContext injected in Library read-only methods (use IReadOnlyPriisDbContext)
❌ Setting ChangedBy / ChangedOnUTC manually (interceptor handles this)
❌ ExecuteSqlRawAsync with string concatenation — use parameterized or ExecuteUpdateAsync
❌ FusionCache L2 (SkipDistributedCacheRead = false) inside a TransactionScope without Suppress
❌ L2 opt-in for types containing EF expression trees (non-serializable)
❌ Disabling or bypassing ExpandingQueryExpressionInterceptor
❌ Using SupportAccountId for system-triggered operations (and vice versa)
```
