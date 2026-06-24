---
name: backend-dry
description: "[Project: GR.PRIIS.Backend] DRY (Don't Repeat Yourself) patterns for GR.PRIIS.Backend — identifying and eliminating duplication across endpoints, domain methods, validators, queries, and tests. Load when refactoring, scaffolding new features, or reviewing code for repeated logic. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# DRY Patterns — Project Conventions

This skill describes how to avoid repeating yourself in GR.PRIIS.Backend across the API, Library, and test layers. **Every pattern here maps to code that already exists in this repo.** When in doubt, grep for the referenced symbols before writing new code.

---

## Quick-Reference Decision Tree

```text
Writing validation?                  → use *Rules() extensions or shared AbstractValidators
Writing a domain mutation?           → put logic in entity method / Library static; endpoint stays thin
Returning the same shape?            → extract a static Expression<Func<T,TDto>> or shared query method
Projecting an entity hierarchy?      → use .HierarchySelect() + .IfTypeThenSelect<TDerived>()
Translating an enum?                 → add / use ToSwedish() extension on the enum type
Building an Excel sheet?             → use sheet.FormatAsTable() + shared *FormatX()* helpers
Joining ChangedBy user to a list?    → use .LeftJoin(dbContext.Users) — NOT a HashSet loop
Collecting ChangedBy users (export)? → use the shared AddChangedByIds + temporal fallback pattern
Writing a test?                      → use ApiWebFactory factory methods; extract private arrange helpers
Chaining SystemResult?               → use .Then() / .ThenAsync() — never repeat if (!result.IsSuccess)
Filtering scoped by access rules?    → use .ApplyAccessRules() / .ApplyAccessRulesOr()
Paginating a list?                   → use .ToPaginatedListAsync() — never manual Skip/Take + CountAsync
Searching across text fields?        → use req.Search.BuildTokenizedPredicate<T>(1, x => x.Field, ...)
```

---

## 1. Shared Validators — `*Rules()` Extension Methods

**Rule:** Do not repeat validation rules inline for well-known field types. Use project extension methods from
`GR.PRIIS.Library.Common.Validation.IRuleBuilderExtensions` (lives in the `FluentValidation` namespace so no extra `using` is needed).

| Extension | What it validates |
|-----------|-------------------|
| `.EmailRules()` | `MaximumLength(FieldLimits.EmailMaxLength)` + `.EmailAddress()` |
| `.PhoneRules()` | Swedish landline regex + area-code lookup |
| `.MobilePhoneRules()` | Swedish mobile regex |
| `.WebPageRules()` | `MaximumLength` + URL regex |
| `.OrganizationNumberRules()` | `NotEmpty` + 10-digit regex |
| `.NameRules()` | `MaximumLength(FieldLimits.NameMaxLength)` |
| `.WhenNotNull()` | Applies preceding rules only when the property is non-null |
| `.IncludeThen()` | Fluent `Include()` for composing `AbstractValidator<T>` instances |
| `.IdOrNavigationObjectRequired()` | `NotEmpty` when navigation object is null |

```csharp
// ✅ DRY — one extension per field type, used everywhere
public sealed class CreateFooRequestValidator : Validator<CreateFooRequest>
{
    public CreateFooRequestValidator()
    {
        RuleFor(x => x.Name).NotEmpty().NameRules();
        RuleFor(x => x.Email).EmailRules().WhenNotNull();
        RuleFor(x => x.Phone).PhoneRules().WhenNotNull();
        RuleFor(x => x.WebPage).WebPageRules().WhenNotNull();
    }
}

// ❌ Wet — inline repetition in every validator
RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256);
RuleFor(x => x.Phone).NotEmpty().Matches(@"^\+?[0-9\s\-]{7,15}$");
```

### 1a. Shared Abstract Validators for Feature Interfaces

When several endpoints update the same group of fields, define an interface + matching `AbstractValidator<IInterface>` in the Library once (see `OperationSharedProperties.cs`):

```csharp
// ✅ Library — one validator for a shared interface
public class OperationContactInfoValidator : AbstractValidator<IOperationContactInfoProperties>
{
    public OperationContactInfoValidator()
    {
        RuleFor(x => x.CountyCode).NotEmpty().MaximumLength(2);
        RuleFor(x => x.MailingAddress).NotNull().ChildRules(Address.ChildRulesAllRequired);
        RuleFor(x => x.Email).EmailRules().WhenNotNull();
        RuleFor(x => x.Phone).PhoneRules().WhenNotNull();
        RuleFor(x => x.WebPage).WebPageRules().WhenNotNull();
    }
}

// Composed in the endpoint validator:
public sealed class CreateOperationRequestValidator : Validator<CreateOperationRequest>
{
    public CreateOperationRequestValidator()
    {
        Include(new OperationContactInfoValidator());   // reuses all rules above
    }
}
```

> **When to create a shared interface validator:** When two or more endpoints (or an endpoint + a CLI command + a domain entity focused-update method) validate the same logical group of fields.

### 1b. `EntityFieldValidation.Validate()` — Rules Inside Domain Entities

Use `EntityFieldValidation.Validate<T>(value, propertyName, configure)` when a focused-update domain method needs to run a shared `*Rules()` extension on a **single field** without exposing a full request object:

```csharp
// ✅ Inside Operation.UpdateWebPage() — same rule as OperationContactInfoValidator
var normalized = string.IsNullOrWhiteSpace(webPage) ? null : webPage;
if (EntityFieldValidation.Validate(normalized, nameof(WebPage), r => r.WebPageRules().WhenNotNull())
    is { IsFailure: true, ValidationFailures: var f2 })
    return f2;

// ❌ Wet — duplicating the regex inline inside the domain entity
if (webPage != null && !Regex.IsMatch(webPage, "^https?://..."))
    return new ValidationFailures(nameof(WebPage), "Ogiltigt webbsideformat");
```

### 1c. `RuleSets.Domain` — Domain-Level Validation Rule Sets

When a validator has rules that only apply in the domain context (e.g., database checks run by Library code), use `RuleSets.Domain` and `IncludeDefaultAndDomainRuleSets()`:

```csharp
// ✅ Library validator — domain checks in a named rule set
public class CreateSupplierValidator : AbstractValidator<CreateSupplier.Data>
{
    public CreateSupplierValidator()
    {
        RuleFor(x => x.Name).NotEmpty().NameRules();   // default set

        RuleSet(RuleSets.Domain, () =>
        {
            RuleFor(x => x.OrganizationNumber)
                .MustAsync(async (orgNum, ct) => !await dbContext.Suppliers.DoesOrganizationNumberExistAsync(orgNum, ct))
                .WithMessage("Organisationsnumret finns redan registrerat.");
        });
    }
}

// Invoking both sets together:
var result = await validator.ValidateAsync(data, opts => opts.IncludeDefaultAndDomainRuleSets());
```

---

## 2. Shared Library Factory / Domain Methods

**Rule:** Domain creation, update, and delete logic lives on the entity as instance/static methods in the Library project — **never inline inside `HandleAsync`**.

The canonical shape is:

```csharp
// ✅ Entity static factory — callable from endpoint, CLI, and tests identically
public static async Task<SystemResult<Operation>> CreateAsync(
    Operation.CreationData data,
    IReadOnlyPriisDbContext dbContext,
    UserCache userCache)
{
    // 1. Input validation (shared validators)
    var validationResult = new InlineValidator<CreationData>()
        .IncludeThen(new OperationBasicInfoValidator())
        .IncludeThen(new OperationContactInfoCommandValidator())
        .Validate(data);
    if (!validationResult.IsValid)
        return new ValidationFailures(validationResult.Errors);

    // 2. Domain checks
    if (await dbContext.Suppliers.Where(x => x.Id == ...).Select(x => x.Status).FirstOrDefaultAsync()
        is RegisterStatus.Terminated)
        return SystemResult.Failure(nameof(SupplierId), "Leverantören är avslutad...");

    // 3. Happy path — implicit conversion to SystemResult<T>
    var entity = Create(data, false);
    return await entity.UpdateBasicInfo(data)
        .ThenAsync(_ => entity.UpdateContactInfoAsync(data, dbContext, userCache));
}

// Endpoint stays thin:
public override async Task HandleAsync(CreateOperationRequest req, CancellationToken ct)
{
    var result = await Operation.CreateAsync(req, dbContext, userCache);
    await SendAndSaveChangesAsync(result, dbContext, ct);
}
```

> **Private constructor rule:** Domain entities should have a `private` parameterless constructor — only the static factory / internal `Create()` can instantiate the object.

---

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

## 4. `ExtendedEndpoint` Hierarchy — No Raw FastEndpoints Types

**Rule:** All endpoints must derive from `ExtendedEndpoint<TReq, TRes>` (or its siblings). Never derive from `Endpoint<TReq, TRes>` directly — doing so re-introduces duplicated response dispatch, policy binding, and error handling.

```csharp
// ✅ DRY — base provides SendAndSaveChangesAsync, Policy(), SendErrorsAsync
public sealed class UpdateFooEndpoint(PriisDbContext dbContext, ICurrentUser currentUser)
    : ExtendedEndpoint<UpdateFooRequest>
{
    public override void Configure()
    {
        Put("/foos/{fooId}");
        Policy(SystemAction.UpdateFoo);
        Options(x => x.RequireRateLimiting(CUDRateLimitingPolicy.Name));
    }

    public override async Task HandleAsync(UpdateFooRequest req, CancellationToken ct)
    {
        var foo = await dbContext.Foos.FindAsync(req.FooId, ct)
            ?? return await SendErrorsAsync("Foo hittades inte", ct);
        var result = foo.Update(req);
        await SendAndSaveChangesAsync(result, dbContext, ct);
    }
}

// Hierarchy:
// ExtendedEndpoint<TReq, TRes>           — body + typed response
// ExtendedEndpoint<TReq>                 — body, 204 on success
// ExtendedEndpointWithoutRequest<TRes>   — no body, typed response (ExecuteAsync returns T)
// ExtendedEndpointWithoutRequest         — no body, 204 on success
```

### 4a. Typed-Response Save Pattern — `Send.ResponseAndSaveChangesAsync()`

When an endpoint returns a typed body (not 204) **and** needs to save changes, use the `ResponseSender` extension instead of `SendAndSaveChangesAsync`:

```csharp
// ✅ ExtendedEndpointWithoutRequest<TResponse> — typed result + save
public override async Task<FooResponse?> ExecuteAsync(CancellationToken ct)
{
    var result = await Foo.CreateAsync(req, dbContext);
    await Send.ResponseAndSaveChangesAsync(dbContext, result, ct);
    return null; // response already sent
}

// OR use the fluent Task<SystemResult> extension:
await someSystemResultTask.SendAsync(Send, ct);

// ❌ Wet — re-implementing save + send inline
var saveOk = await dbContext.SaveChangesWithResultAsync(ct);
if (!saveOk.IsSuccess) { await SendErrorsAsync(saveOk.ValidationFailures, ct); return null; }
await Send.OkAsync(result.Result, cancellation: ct);
```

### 4b. Multi-Action Policies — `PolicyType.All`

```csharp
// ✅ Require ALL listed actions (default is AtLeastOne)
Policy(PolicyType.All, SystemAction.ReadFoo, SystemAction.UpdateFoo);

// ✅ Require at least one of the listed actions
Policy(SystemAction.ReadFoo, SystemAction.ReadBar);
```

---

## 5. `SystemResult` Chaining — `.Then()` / `.ThenAsync()`

**Rule:** Chain domain steps instead of repeating `if (!result.IsSuccess)` guards after each step.

```csharp
// ✅ DRY — pipeline short-circuits on first failure
var result = await operation.UpdateBasicInfo(req)
    .ThenAsync(_ => operation.UpdateContactInfoAsync(req, dbContext, userCache))
    .ThenAsync(_ => operation.ChangeParameterConnectionsAsync(req.ParameterConnections, dbContext));

await SendAndSaveChangesAsync(result, dbContext, ct);

// ❌ Wet — repeated manual guards
var r1 = operation.UpdateBasicInfo(req);
if (!r1.IsSuccess) { await SendErrorsAsync(r1.ValidationFailures, ct); return; }

var r2 = await operation.UpdateContactInfoAsync(req, dbContext, userCache);
if (!r2.IsSuccess) { await SendErrorsAsync(r2.ValidationFailures, ct); return; }
```

Full chaining API (all members on `SystemResultExtensions`):

| Method | Use when |
|--------|----------|
| `.Then(x => next(x))` | Sync transform, short-circuits on failure |
| `.ThenAsync(async x => await next(x))` | Async transform, short-circuits on failure |
| `.OnSuccess(async () => ...)` | Side-effect on success (sends 204, fires event) |
| `.OnFailure(errors => ...)` | Side-effect on failure (logging, etc.) |
| `.FailureOr(result)` | Convert `SystemResult` → `SystemResult<T>` |

`ValidationFailures` also provides `OrSuccess()` and `OrResult<T>(result)` for converting an accumulated error list into a `SystemResult` at the end of a collect-and-check pattern.

---

## 6. Shared Test Factory Methods

**Rule:** Do not repeat auth setup. Use the factory methods on `ApiWebFactory`.

```csharp
// ✅ DRY — provided factory methods
var (client, _)        = await ApiWebFactory.CreateClientAsUserAsync();
var (client, userId)   = await ApiWebFactory.CreateClientAsRoleAsync(RoleType.RegisterAdministrator);
var (client, _)        = await ApiWebFactory.CreateClientAsNoAccessUserAsync(SystemAction.CreateFoo);

// For seeding test data:
await ApiWebFactory.RunDbContextActionAsync(async db =>
{
    db.Foos.Add(new Foo { Name = "Test" });
    await db.SaveChangesAsync();   // auto-called by RunDbContextActionAsync
});

// ❌ Wet — constructing cookies/headers manually in each test
var client = ApiWebFactory.CreateClient();
client.DefaultRequestHeaders.Add("Cookie", "...");
```

### 6a. Extract Repeated Arrange Logic into Private Helpers

```csharp
// ✅ Extract a private async helper for arrange steps used by multiple tests
private async Task<Guid> CreateOperationAsync()
    => await ApiWebFactory.RunDbContextActionAsync(async db =>
    {
        var op = Operation.Create(new Operation.CreationData { /* minimal seed */ });
        db.Operations.Add(op);
        return op.Id;
    });

[Test, AutoRollback]
public async Task CreateFeedbackTicket_ValidRequest_ReturnsCreated()
{
    var operationId = await CreateOperationAsync();
    // ... rest of test
}

[Test, AutoRollback]
public async Task CreateFeedbackTicket_TerminatedOperation_ReturnsBadRequest()
{
    var operationId = await CreateOperationAsync();
    // ... rest of test
}
```

---

## 7. Shared Enum-to-String Translation — `ToSwedish()` / `ToLocalizedString()`

**Rule:** When an enum needs a Swedish display string, add it once as an extension method on (or near) the enum — **not** as a `private static GetXxxInSwedish()` inside each endpoint or export class.

```csharp
// ✅ DRY — extension declared once, used everywhere
public static class GenderExtensions          // in Operation.cs
{
    public static string ToSwedish(this Gender gender) => gender switch
    {
        Gender.Male         => "Man",
        Gender.Female       => "Kvinna",
        Gender.Both         => "Båda",
        Gender.BothSeparate => "Båda (separat)",
        _                   => gender.ToString()
    };
}

// Consumed in ExportDataToExcelEndpoint, ExportDetailedMatchingTicketsEndpoint, ...
sheet.Cell(row, 5).Value = supplier.Status.ToSwedish();
sheet.Cell(row, 9).Value = operation.ReceivingGender.ToSwedish();

// ❌ Wet — private static inside each export endpoint
private static string GetGenderInSwedish(Gender gender) => gender switch { ... };
private static string GetStatusInSwedish(MatchingTicketStatus status) => status switch { ... };
```

> **Existing `ToSwedish()` extensions** (do not duplicate): `RegisterStatus`, `Gender`, `MatchingTicketStatus`, `MatchingReason`, `MatchingSelectionStatus`, `MatchingIterationStatus`. Check by grepping `ToSwedish` before adding a new one.

---

## 8. Shared Excel Worksheet Helpers — `WorksheetExtensions.FormatAsTable()`

**Rule:** Use `worksheet.FormatAsTable(lastRow, lastColumn, headerRow)` from `GR.PRIIS.API.Extensions.WorksheetExtensions` instead of manually styling cells or creating table ranges.

```csharp
// ✅ DRY — used in every export endpoint after writing all rows
var lastColumn = sheet.LastColumnUsed()?.ColumnNumber() ?? 0;
sheet.FormatAsTable(row, lastColumn);                  // default headerRow = 1
worksheet.FormatAsTable(row - 1, 20, headerRow: 2);   // with explicit header row

// ❌ Wet — manual bold + table setup
sheet.Cell(headerRow, 1).Style.Font.Bold = true;
sheet.Cell(headerRow, 2).Style.Font.Bold = true;
// ... repeated for every column
var range = sheet.Range(1, 1, lastRow, lastColumn);
range.CreateTable();
```

`FormatAsTable` sets `TableStyleMedium2`, shows header row, enables auto-filter, and optionally auto-fits columns (`adjustToContents: true`).

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

## 11. Shared Access Rule Filtering — `ApplyAccessRules()`

**Rule:** All export / list queries that are scoped by the current user's role must use `ApplyAccessRules()` from `GR.PRIIS.Library.DataAccess.QueryableExtensions.AccessRulesExtensions` — never write manual access predicate logic inline in an endpoint.

```csharp
// ✅ DRY — access rules applied uniformly
var rules = await accessRulesEvaluationEngine.GetAccessRulesForCurrentUserAsync(ct);
var suppliers = await dbContext.Suppliers
    .ApplyAccessRules(SystemActions, rules)   // ← filters to user's permitted scope
    .Select(...)
    .ToListAsync(ct);

// Also available: ApplyAccessRulesOr() when you need an additional OR predicate
dbContext.Contracts
    .ApplyAccessRulesOr(SystemActions, rules, c => c.OwnedByCurrentUser)
    .Select(...)

// ❌ Wet — writing the access predicate inline
dbContext.Suppliers.Where(s => rules.Any(r => r.SupplierIds.Contains(s.Id)))
```

> **Note:** When no access rules are returned for the current user, both methods return an empty result set (`WHERE 1=0`). This is intentional and correct.

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

## 15. Mixed Existing/New Entity Collections — `ExistingOrNewEntities<T>`

**Rule:** When a request can reference either an existing entity by ID or provide data to create a new one, use `ExistingOrNewEntities<TNew>` from `GR.PRIIS.Library.Common.Collections`. Never duplicate the "Guid list + new-entity list" pattern inline in request types.

```csharp
// ✅ DRY — reusable collection type in request DTOs
public record CreateOperationRequest
{
    // References existing users by ID or provides data to create new ones:
    public ExistingOrNewEntities<NewUser> ContactEntities { get; init; } = new();
}

// In domain logic:
var (existingIds, newUsers) = (req.ContactEntities.ExistingIds, req.ContactEntities.NewEntities);
if (!req.ContactEntities.Any()) return SystemResult.Failure(...);

// ❌ Wet — ad-hoc parallel lists in every request type
public List<Guid> ExistingContactIds { get; init; } = [];
public List<NewContactData> NewContacts { get; init; } = [];
```

---

## 16. Anti-Patterns Checklist

The following are definitively banned in this codebase. If you see one, it is a DRY violation.

```text
❌ private static GetXxxInSwedish() inside an endpoint — add a public ToSwedish() extension to the enum
❌ Inline worksheet header/bold/table styling — use WorksheetExtensions.FormatAsTable()
❌ Duplicating ChangedBy user lookup across export endpoints — extract the pattern once
❌ Re-declaring the same .Select() projection shape in multiple endpoints — use a static expression
❌ Repeating IsActive / ContactsFilter / OperationManagerFilter lambdas inline — use the static expression members
❌ Copy-pasting SystemResult if (!result.IsSuccess) guards — use .Then() / .ThenAsync() chaining
❌ Repeating auth factory setup in each test method — use a private helper or ApiWebFactory methods
❌ Domain validation logic in HandleAsync — it belongs in the Library factory/entity method
❌ Deriving from Endpoint<TReq,TRes> directly — always derive from ExtendedEndpoint
❌ Writing the same inline FluentValidation rule for Email/Phone/WebPage/Org# — use *Rules() extensions
❌ Manual Skip/Take + CountAsync for pagination — use ToPaginatedListAsync()
❌ Writing a manual access predicate instead of ApplyAccessRules()
❌ Manual string.Split + Contains for search — use BuildTokenizedPredicate()
❌ GroupJoin/DefaultIfEmpty for ChangedBy in list endpoints — use .LeftJoin(dbContext.Users)
❌ Runtime is/switch for entity hierarchy projections — use HierarchySelect() + IfTypeThenSelect()
❌ Parallel List<Guid> + List<TNew> for mixed existing/new entities — use ExistingOrNewEntities<T>
❌ Separate queries per derived type in an inheritance hierarchy — use HierarchySelect()
✅ One place to change means one place to fix — if the same logic appears twice, extract it now
✅ Name extractions by what they do (ToSwedish, FormatAddress, FormatContactPersons, FormatChangedBy)
✅ Before adding a new ToSwedish() or static expression, grep first — it may already exist
```
