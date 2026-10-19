---
name: priis-backend-ef-core
description: "[Project: GR.PRIIS.Backend] EF Core 10 patterns for GR.PRIIS.Backend — AsNoTracking/Select for reads, PriisDbContext usage, AuditableEntity, temporal tables, FusionCache integration, dynamic predicates, and multi-write transactions (TransactionScope.CreatePriisDefault). Load when writing queries, migrations, or any data access code. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
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

## 3. AuditableEntity + SaveChanges stamping

All domain entities extend `AuditableEntity`. The `SaveChangesAsync` override stamps `ChangedBy` on tracked inserts and edits; `ChangedOnUTC` is the temporal period column and is never set by code. Do not set `ChangedBy` manually on tracked entities as a habit — an explicit value set before the save is kept (acting on behalf of someone), everything else is stamped.

```csharp
// ✅ Correct — ChangedBy is stamped by SaveChangesAsync
var note = new OperationNote { OperationId = req.Id, Content = req.Content };
dbContext.OperationNotes.Add(note);
await dbContext.SaveChangesAsync(ct);   // SaveChanges stamps ChangedBy

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

### Bulk updates

EF's raw `ExecuteUpdate`/`ExecuteUpdateAsync` are banned (RS0030, `source/BannedSymbols.txt`) because they skip `ChangedBy`. Pick one of:

| Need | Use |
|---|---|
| Standalone update of `IAuditable` rows | `query.ExecuteUpdateAsync(setters, currentUser, ct)` |
| Update that must commit atomically with tracked changes | `dbContext.QueueUpdate<T>(ids, setters, phase)` |
| Update of a non-`IAuditable` entity | `query.ExecuteUnauditedUpdateAsync(setters, ct)` (throws for `IAuditable`) |

```csharp
// Runs inside the next SaveChanges, in the same transaction; ChangedBy is stamped for IAuditable targets.
dbContext.QueueUpdate<BaseContract>(
    contractIds,
    setters => setters.SetProperty(c => c.Status, RegisterStatus.Terminated));   // phase defaults to BeforeTrackedChanges
dbContext.ContractAuditLogs.AddRange(logs);
await dbContext.SaveChangesAsync(ct);
```

`QueueUpdate` rules:
- `BeforeTrackedChanges` (default) runs before the tracked save, e.g. to clear a reference that blocks a tracked delete. Use `AfterTrackedChanges` when the update depends on rows the same save inserts.
- Every id must match a row under the context's query filters, or the save throws `QueuedBulkUpdateException` and nothing is committed. The same exception is thrown when a queued id is also tracked: change tracked entities through the tracker.
- The save joins the caller's transaction or opens a ReadCommitted one. Never wrap it in your own `TransactionScope`.
- A failed save keeps both the queue and the tracked changes, so retry as-is. The queue is cleared when a save succeeds; inside a caller's transaction, a later rollback by that caller is not undone. `ChangeTracker.Clear()` does not clear the queue.
- Never `SetProperty` `ChangedBy` in the setters: the queue (and the audited `ExecuteUpdateAsync` overload) stamps it, and a second setter fails the save with `QueuedBulkUpdateException`. An act-as case gets an explicit parameter, not a setter.
- Inserts with a store-generated key (identity; today only Identity's claim tables and `DataProtectionKey`) cannot be restored after a failed save, so the save throws `NotSupportedException` when one is tracked together with a queued update or an audited deletion. Domain entities have client-generated Guid keys and are unaffected.

Raw SQL `UPDATE` against an `IAuditable` table must set `[ChangedBy] = {currentUser.Id}` itself. The analyzer cannot see raw SQL.

The ban covers `source/` only (`source/Directory.Build.props`); test projects may call the raw overloads to seed data.

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

### Shared predicates and projections: one definition per rule

A rule or projection that two queries need is defined **once**, as a static expression on the entity it describes, and used through `.Invoke(...)`. The global `ExpandingQueryExpressionInterceptor` inlines it, so it translates to SQL like an inline lambda. Reviews keep finding the same lambda copied into a second and third endpoint ("same ordering as X" in a comment is the tell); the copies then drift.

```csharp
// On the entity (or its filter/snapshot class)
public static readonly Expression<Func<MatchingSelectionContractUsedArticle, bool>> IsApproximate =
    a => a.Source == ArticlePriceSnapshotSource.ReconstructedApproximate;

public static Expression<Func<BaseContract, string?>> SubareaNameExpression() =>
    x => x is SubareaContract ? (x as SubareaContract)!.TemplateSubarea.Name : null;

// In every query that needs it
.Select(u => new UsedContractDto
{
    SubareaName = BaseContract.SubareaNameExpression().Invoke(u.Contract),
    ArticlePricesApproximate = u.ArticlePrices.Any(a => MatchingSelectionContractUsedArticle.IsApproximate.Invoke(a)),
})
```

Before writing a predicate or projection, grep the property combination it uses (`NotReplied.*DeadlineReached`, `Source == .*Reconstructed`) across `source/`; a hit means the definition already exists.

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

## 10. Transactions Across Several Writes

When several writes (`SaveChangesAsync`, `ExecuteDeleteAsync`, standalone audited `ExecuteUpdateAsync` calls) must commit or roll back together, use `TransactionScope.CreatePriisDefault()` from `GR.PRIIS.Library.Common.Extensions`. A bulk update paired with tracked changes needs no scope: see *Bulk updates*, `QueueUpdate` replaces it. Wrap only the writes: load and modify entities before the scope opens, and run best-effort follow-up work after it is disposed.

```csharp
// ✅ Correct — reads before the scope, only the writes inside it
var activeKeys = await dbContext.OidcServerKeys.Where(x => x.RetiredOnUTC == null).ToListAsync(ct);
foreach (var key in activeKeys)
    key.RetiredOnUTC = now;

using (var transaction = TransactionScope.CreatePriisDefault())
{
    await dbContext.SaveChangesAsync(ct);
    dbContext.OidcServerKeys.Add(newKey);
    await dbContext.SaveChangesAsync(ct);
    transaction.Complete();
}

// ❌ Wrong — throws "An ambient transaction has been detected" under [AutoRollback] and inside any calling scope
await using var tx = await dbContext.Database.BeginTransactionAsync(ct);

// ❌ Wrong — bare scope defaults to Serializable and does not flow across await
using var scope = new TransactionScope();
```

Why each setting (also documented on the method):

- **`Required`** joins an ambient transaction (a calling scope, or the `[AutoRollback]` test scope) and starts one otherwise. `Database.BeginTransactionAsync` cannot do this and throws when an ambient transaction exists.
- **`ReadCommitted`** is the SQL Server default. A bare `TransactionScope` is `Serializable`, which takes range locks and causes blocking. A nested scope must also request the same isolation level as the ambient one, so all scopes should use the same level.
- **`TransactionScopeAsyncFlowOption.Enabled`** makes the ambient transaction flow across `await`.

Use the block form `using (...) { }` when more database calls follow in the same method. Database calls inside a scope after `Complete()` has been called fail.

Every write scope in `source/` uses `CreatePriisDefault()`. The only hand-built scope is `TransactionScopeOption.Suppress` around FusionCache L2 calls (see §6).

---

## 11. Migrations

Run from the backend repo root (`dotnet-ef` is a local tool; there is no `--migrate` flag):

```bash
dotnet ef migrations add <MigrationName> -p source/GR.PRIIS.Library -s source/GR.PRIIS.API
```

Review the generated file before committing. Integration tests apply migrations themselves through `TUnitApiWebFactory`; to apply and seed a local database use `cd source/GR.PRIIS.CLI && dotnet run -- migrations -s -d`. Several migrations accumulated on one branch → the `squash-ef-core-migrations` skill.

---

## 12. Anti-Patterns Checklist

```
❌ .Include() in read-only GET endpoints — use .Select() navigation
❌ Missing .AsNoTracking() on read queries in API layer
❌ Returning EF entity types from endpoints
❌ PriisDbContext injected in Library read-only methods (use IReadOnlyPriisDbContext)
❌ Setting ChangedBy manually on tracked entities — SaveChanges stamps it (raw SQL UPDATE must set `[ChangedBy]` itself, see Bulk updates)
❌ ExecuteSqlRawAsync with string concatenation — use parameterized SQL that sets `[ChangedBy]`, or the audited `ExecuteUpdateAsync(…, currentUser)`
❌ FusionCache L2 (SkipDistributedCacheRead = false) inside a TransactionScope without Suppress
❌ Database.BeginTransactionAsync or a hand-built TransactionScope for multi-write atomicity in feature code — use TransactionScope.CreatePriisDefault() (infrastructure that owns its connection is exempt: PriisDbContext's save path and the Worker's queue dequeuers)
❌ L2 opt-in for types containing EF expression trees (non-serializable)
❌ Disabling or bypassing ExpandingQueryExpressionInterceptor
❌ The same predicate or projection lambda in two queries — one static Expression on the entity, used via .Invoke(...) (see §7)
❌ Using SupportAccountId for system-triggered operations (and vice versa)
```
