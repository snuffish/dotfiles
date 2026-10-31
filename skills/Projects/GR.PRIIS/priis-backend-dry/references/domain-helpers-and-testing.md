# Domain Helpers, Testing & Anti-Patterns

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

---

## 8. Shared Excel Worksheet Helpers — `WorksheetExtensions`

**Rule:** Use the `IXLWorksheet` extensions in `GR.PRIIS.API.Extensions.WorksheetExtensions` (`backend/source/GR.PRIIS.API/Extensions/WorksheetExtensions.cs`) instead of styling cells by hand: `WriteTitle(title, fontSize = 14)` for the bold title in A1, `WriteMetadataRow(row, label, value, col = 1)` for each bold-label/value row, and `FormatTable(table, adjustToContents = false)` on the table ClosedXML's `InsertTable` returns.

```csharp
// ✅ DRY — the report export endpoints (e.g. ExportControlTicketsEndpoint)
worksheet.WriteTitle("Rapport: Kontrollärenden");
worksheet.WriteMetadataRow(2, "Skapad:", ReportGeneratedAt.ToSwedishDateTimeString());
worksheet.WriteMetadataRow(3, "Period:", $"{req.StartDate:yyyy-MM-dd} - {req.EndDate:yyyy-MM-dd}");
var table = worksheet.Cell(headerRow, 1).InsertTable(data);
worksheet.FormatTable(table);                              // or adjustToContents: true

// ❌ Wet — hand-styled title, labels and table in each endpoint
sheet.Cell(1, 1).Value = "Rapport: …";
sheet.Cell(1, 1).Style.Font.Bold = true;
sheet.Cell(2, 1).Style.Font.Bold = true;
// ... repeated for every metadata row
table.Theme = XLTableTheme.TableStyleMedium2;
table.ShowAutoFilter = true;
```

`FormatTable` sets `TableStyleMedium2`, shows the header row, enables auto-filter, and optionally auto-fits columns (`adjustToContents: true`).

---

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

---

## 16. Anti-Patterns Checklist

The following are definitively banned in this codebase. If you see one, it is a DRY violation.

```text
❌ private static GetXxxInSwedish() inside an endpoint — add a public ToSwedish() extension to the enum
❌ Inline worksheet title/bold/table styling — use WorksheetExtensions.WriteTitle() / WriteMetadataRow() / FormatTable()
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
