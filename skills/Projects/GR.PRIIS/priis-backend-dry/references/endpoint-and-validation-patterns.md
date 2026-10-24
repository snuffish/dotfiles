# Endpoint & Validation DRY Patterns

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
