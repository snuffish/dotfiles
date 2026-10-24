# Query & Projection DRY Patterns

## 3. Shared Read Projections — Static `Expression<Func<T,TDto>>`

**Rule:** When the same projection shape is used by more than one call site (endpoint, export, notification handler), extract it as a `static` expression member **on the entity or in a shared queries class**.

```csharp
// ✅ DRY — static expression declared once on the entity
public static Expression<Func<OperationUserRole, bool>> ContactsFilter =>
    ur => ur.RoleId == Role.OperationContactPersonId;

// Used identically in 10+ locations — no lambda duplication:
dbContext.UserRoles.Where(Operation.ContactsFilter)
// GR.PRIIS.API:  ExportDataToExcelEndpoint, GetNotificationDefinitionsEndpoint, ...\
// GR.PRIIS.Library: MatchingInquiryRecipientContractLoader, ...

// ✅ DRY — static predicate on User entity
public static Expression<Func<User, bool>> IsActivePredicate =>
    user => user.LockoutEnd != DateTimeOffset.MaxValue && user.Roles.Count > 0;

// Applied in ListInternalUsersEndpoint, ListExternalUsersEndpoint, BaseListUsersEndpoint

// ✅ DRY — expression-returning method for formatting
public static Expression<Func<FeedbackTicket, string>> TicketNumberExpression() =>
    x => "SYN-" + x.Administration.Municipality.Code + "-" + PriisDbContext.SqlFormat(x.IncrementalNumber, "D6");
```

```csharp
// ❌ Wet — same lambda copy-pasted in each endpoint
dbContext.UserRoles.Where(ur => ur.RoleId == Role.OperationContactPersonId)  // x5 copies
dbContext.Users.Where(u => u.LockoutEnd != DateTimeOffset.MaxValue && u.Roles.Count > 0)  // x3 copies
```

> **Where to put it:** Predicate/projection expressions for a single entity belong as `static` members on that entity class. Projections spanning multiple entities belong in a shared `*Queries` class under `Features/` or in the Library.

---

---

## 9. Joining ChangedBy User to List Queries — `UserExtensions.LeftJoin()`

**Rule:** When a list endpoint needs to display who last changed each row, use `query.LeftJoin(dbContext.Users)` from `GR.PRIIS.Library.DataAccess.QueryableExtensions.UserExtensions`. This produces a single SQL left-join and handles deleted users gracefully (returns `null` for the `User` property).

```csharp
// ✅ DRY — single left-join, works in EF, handles deleted users
var items = await dbContext.FeedbackTickets
    .AsNoTracking()
    .Where(predicate)
    .LeftJoin(dbContext.Users)   // joins on ChangedBy == User.Id
    .Select(x => new FeedbackTicketListItem
    {
        Id              = x.Entity.Id,
        ChangedBy       = x.User != null
            ? x.User.FirstName + " " + x.User.LastName
            : null,
        ChangedOnUTC    = x.Entity.ChangedOnUTC
    })
    .ToPaginatedListAsync(req, ct: ct);

// ❌ Wet — manual GroupJoin / DefaultIfEmpty boilerplate at every call site
dbContext.FeedbackTickets
    .GroupJoin(dbContext.Users, t => t.ChangedBy, u => u.Id, (t, u) => new { t, u })
    .SelectMany(x => x.u.DefaultIfEmpty(), (x, u) => new { x.t, User = u })
    .Select(x => new FeedbackTicketListItem { ... })
```

> **For export endpoints** that need the full name + temporal fallback (deleted users), see the `AddChangedByIds` pattern in Section 9a below — the `LeftJoin` approach only covers live users.

### 9a. ChangedBy Lookup with Temporal Fallback — Export Endpoints Only

Only necessary when you need deleted-user names in an Excel export. Use the `AddChangedByIds` + temporal-query approach:

```csharp
// Step 1 — accumulate all ChangedBy GUIDs from all lists
var changedByIds = new HashSet<Guid>();
AddChangedByIds(changedByIds, suppliers,                  s => s.ChangedBy);
AddChangedByIds(changedByIds, operations,                 o => o.ChangedBy);
AddChangedByIds(changedByIds, subareaContracts,           c => c.ChangedBy);
AddChangedByIds(changedByIds, directProcurementContracts, c => c.ChangedBy);
AddChangedByIds(changedByIds, administrations,            a => a.ChangedBy);

// Step 2 — query live users
var currentUsers = await dbContext.Users.AsNoTracking()
    .Where(user => changedByIds.Contains(user.Id))
    .Select(user => new { user.Id, user.FirstName, user.LastName })
    .ToListAsync(ct);

var changedByUsers = currentUsers.ToDictionary(u => u.Id, u => new ChangedByUserInfo(u.FirstName, u.LastName));

// Step 3 — temporal fallback for deleted users only
var missingIds = changedByIds.Where(id => !changedByUsers.ContainsKey(id)).ToList();
if (missingIds.Count > 0)
{
    var historicalUsers = await dbContext.Users.TemporalAll().AsNoTracking()
        .Where(user => missingIds.Contains(user.Id)
            && EF.Property<DateTime>(user, PriisDbContext.TemporalTablePeriodEnd) != DateTime.MaxValue)
        .OrderBy(user => user.Id)
        .ThenByDescending(user => user.ChangedOnUTC)
        .Select(user => new { user.Id, user.FirstName, user.LastName })
        .ToListAsync(ct);

    foreach (var h in historicalUsers)
        changedByUsers.TryAdd(h.Id, new ChangedByUserInfo(h.FirstName, h.LastName));
}

// Generic helper to accumulate IDs:
private static void AddChangedByIds<T>(
    HashSet<Guid> changedByIds,
    IReadOnlyList<T>? rows,
    Func<T, Guid> selector)
{
    if (rows is null) return;
    foreach (var row in rows) changedByIds.Add(selector(row));
}
```

> If you add a new export endpoint that has a `ChangedBy` column, **extract this helper to a shared location** (e.g., a static class in `Features/Reports/`) rather than duplicating the temporal-fallback logic.

---

---

## 10. Shared Static Expression Properties on Entities

**Rule:** Reusable EF filter and projection expressions belong as `static` members on the entity class itself — not re-declared inline at each call site.

| Symbol | Entity | Used in |
|--------|--------|---------|
| `User.IsActivePredicate` | `User` | `BaseListUsersEndpoint`, `ListInternalUsersEndpoint`, `ListExternalUsersEndpoint` |
| `User.DisplayNameExpression()` | `User` | Notification handlers, select lists |
| `Operation.ContactsFilter` | `Operation` | 10+ query sites across API and Library |
| `BaseSupplier.OperationManagerFilter` | `BaseSupplier` | `ExportDataToExcelEndpoint`, `GetSupplierProfileEndpoint`, `GetSupplierUpdateDataEndpoint` |
| `FeedbackTicket.TicketNumberExpression()` | `FeedbackTicket` | Ticket list and detail endpoints |

```csharp
// ✅ DRY — declared once on the entity
public static Expression<Func<User, bool>> IsActivePredicate =>
    user => user.LockoutEnd != DateTimeOffset.MaxValue && user.Roles.Count > 0;

// In queries:
dbContext.Users.Where(User.IsActivePredicate)

// ❌ Wet — the same lambda re-typed at each call site
dbContext.Users.Where(u => u.LockoutEnd != DateTimeOffset.MaxValue && u.Roles.Count > 0)
```

---

---

## 12. Shared Pagination — `ToPaginatedListAsync()`

**Rule:** All paginated list endpoints use `ToPaginatedListAsync<T, TOrderByEnum>(request, extraOrderBy?)` from `PaginatedListQueryableExtensions`. Never manually compute `Skip()` / `Take()` or total count.

```csharp
// ✅ DRY — pagination + ordering in one call
var result = await dbContext.Foos
    .AsNoTracking()
    .Where(predicate)
    .Select(f => new FooListItem { Id = f.Id, Name = f.Name })
    .ToPaginatedListAsync(req, extraOrderByExpression: f => f.Name, ct);

// ❌ Wet — manual pagination
var total = await query.CountAsync(ct);
var items = await query.Skip((req.Page - 1) * req.PageSize).Take(req.PageSize).ToListAsync(ct);
return new PaginatedList<FooListItem, FooOrderBy>(items, req.Page, req.PageSize, total, ...);
```

---

---

## 13. Tokenized Full-Text Search — `BuildTokenizedPredicate()`

**Rule:** All text-search functionality uses `SearchExtensions.BuildTokenizedPredicate<T>()` from `GR.PRIIS.Library.Common.Extensions`. Never write inline `Contains()` clauses or split search text manually.

```csharp
// ✅ DRY — tokens are split and matched across multiple fields
var predicate = PredicateBuilder.New<Operation>(true);
if (!string.IsNullOrWhiteSpace(req.Search))
{
    predicate = predicate.And(
        req.Search.BuildTokenizedPredicate<Operation>(1,
            x => x.Name,
            x => x.OperationNumber,
            x => x.Municipality.Name));
}

var result = await dbContext.Operations
    .AsExpandable()
    .Where(predicate)
    .ToPaginatedListAsync(req, ct: ct);

// ❌ Wet — manual split + Contains at each endpoint
var tokens = req.Search.Split(' ');
var results = dbContext.Operations.Where(o =>
    tokens.All(t => o.Name.Contains(t) || o.OperationNumber.Contains(t)));
```

> **Semantics:** Each token must appear in **at least one** of the supplied fields (OR across fields), and **all** tokens must match (AND across tokens). This mirrors the behavior across `ListOperationsEndpoint`, `ListFeedbackTicketsEndpoint`, `ListRegisterTicketsEndpoint`, `BaseListUsersEndpoint`, and `ListNotificationsEndpoint`.

---

---

## 14. Hierarchy Projections — `HierarchySelect()` + `IfTypeThenSelect()`

**Rule:** When querying an entity inheritance hierarchy (e.g., `BaseContract`, `ExternalSupplier`) and projecting into a single DTO type with derived-type-specific fields, use `HierarchySelect()` + `IfTypeThenSelect<TDerived>()`. Never use `is` pattern-matching or multiple queries for the same entity hierarchy.

```csharp
// ✅ DRY — single query, per-type field overrides
var data = await dbContext.Contracts
    .AsExpandable()
    .Where(x => x.Id == contractId)
    .HierarchySelect(x => new ContractProfileData
    {
        Id     = x.Id,
        Status = x.Status,
        // base fields shared by all contract types
    })
    .IfTypeThenSelect<SubareaContract, SubareaContractProfileData>(x => new()
    {
        SubareaId = x.SubareaId,
        // fields only on SubareaContract
    })
    .IfTypeThenSelect<DirectProcurementContract, DirectProcurementContractProfileData>(x => new()
    {
        DirectProcurementReason = x.DirectProcurementReason,
        // fields only on DirectProcurementContract
    })
    .ToQueryable()
    .AsNoTracking()
    .FirstOrDefaultAsync(ct);

// ❌ Wet — separate queries per derived type or runtime switch
var contract = await dbContext.Contracts.FindAsync(contractId, ct);
if (contract is SubareaContract sc) { ... }
else if (contract is DirectProcurementContract dpc) { ... }
```

> `HierarchySelect` and `IfTypeThenSelect` live in `GR.PRIIS.Library.DataAccess.HierarchyExpressionBuilder`. The result must be called `.ToQueryable()` to materialize into an `IQueryable<TReturn>`.

---
