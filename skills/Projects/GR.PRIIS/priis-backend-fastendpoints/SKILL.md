---
name: priis-backend-fastendpoints
description: "[Project: GR.PRIIS.Backend] FastEndpoints patterns for GR.PRIIS.Backend — ExtendedEndpoint hierarchy, Policy overloads, SendAsync/SendAndSaveChangesAsync, SystemResult chaining, FluentValidation conventions, and TUnit test structure. Load when creating or modifying endpoints. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# FastEndpoints — Project Patterns

This skill covers how FastEndpoints 8.x is used in this codebase via the `ExtendedEndpoint` base class hierarchy. All endpoints must derive from `ExtendedEndpoint`, not from FastEndpoints base types directly.

---

## 1. ExtendedEndpoint Hierarchy

```csharp
// Standard endpoint with request body + typed response
public abstract class ExtendedEndpoint<TRequest, TResponse>
    : Endpoint<TRequest, TResponse>, IExtendedEndpoint

// Endpoint with request body, no response content (sends 204)
public abstract class ExtendedEndpoint<TRequest>
    : ExtendedEndpoint<TRequest, EmptyResponse>, IExtendedEndpointNoContentResult

// Endpoint with no request body, no response content
public abstract class ExtendedEndpointWithoutRequest
    : ExtendedEndpointWithoutRequest<EmptyResponse>

// Endpoint with no request body, typed response
public abstract class ExtendedEndpointWithoutRequest<TResponse>
    : ExtendedEndpoint<EmptyRequest, TResponse>
```

**When to use each:**
- `ExtendedEndpoint<TReq, TRes>` — most endpoints (POST/PUT with body + response)
- `ExtendedEndpoint<TReq>` — mutations where only success/failure matters (PUT/DELETE that return 204)
- `ExtendedEndpointWithoutRequest<TRes>` — GET with no route/query params beyond path variables
- `ExtendedEndpointWithoutRequest` — DELETE with no body and no response

---

## 2. `Configure()` Rules

Every endpoint must call `Policy(...)` — no anonymous access anywhere.

```csharp
public override void Configure()
{
    Post("/operations/{operationId}/notes");
    Policy(SystemAction.CreateOperationNote);                          // single action
    Options(x => x.RequireRateLimiting(CUDRateLimitingPolicy.Name)); // required on mutations
    Summary(s => s.Summary = "Create a note on an operation");        // optional but recommended
}
```

**`Policy()` overloads:**
```csharp
Policy(SystemAction.X);                           // single action required
Policy(SystemAction.A, SystemAction.B);           // at least one (OR)
Policy(PolicyType.All, SystemAction.A, SystemAction.B); // all required (AND)
```

---

## 3. Response Helpers

All response helpers are on `ExtendedEndpoint` — use these, not the raw FastEndpoints `Send.*` calls, unless a specific scenario requires it.

```csharp
// Typed response — sends 200, or 204 if response is null
protected async Task SendAsync<T>(T? response, CancellationToken ct)

// SystemResult (no content) — sends 204 on success, 422 with errors on failure
protected async Task SendAsync(SystemResult systemResult, CancellationToken ct)

// SystemResult<T> — saves EF changes then sends 204 on success, 422 on failure
protected async Task SendAndSaveChangesAsync<TResult>(
    SystemResult<TResult> systemResult, PriisDbContext dbContext, CancellationToken ct)

// Error helpers
protected async Task SendErrorsAsync(string message, CancellationToken ct)
protected async Task SendErrorsAsync(ValidationFailures errors, CancellationToken ct)
protected async Task SendErrorsAsync(IEnumerable<IdentityError> errors, CancellationToken ct)
```

**Common patterns:**

```csharp
// Mutation (create/update/delete) — most common
var result = await SomeDomain.CreateAsync(req, dbContext, currentUser);
await SendAndSaveChangesAsync(result, dbContext, ct);

// Read — project inline or via library method
var dto = await dbContext.Foos
    .AsNoTracking()
    .Where(f => f.Id == req.Id)
    .Select(f => new FooDto { Id = f.Id, Name = f.Name })
    .FirstOrDefaultAsync(ct);
await SendAsync(dto, ct);  // sends 200 with dto, or 204 if null

// Domain failure without EF save
var result = await SomeDomain.ValidateAsync(req);
await SendAsync(result, ct);  // 204 on success, 422 on failure
```

---

## 4. Rate Limiting

All mutation endpoints (POST, PUT, PATCH, DELETE) must include rate limiting:

```csharp
Options(x => x.RequireRateLimiting(CUDRateLimitingPolicy.Name));
```

GET endpoints do not require rate limiting unless they trigger expensive operations.

---

## 5. FluentValidation Conventions

```csharp
public sealed class CreateFooRequestValidator : Validator<CreateFooRequest>
{
    public CreateFooRequestValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Email).EmailRules();          // project extension
        RuleFor(x => x.Phone).PhoneRules();          // project extension
        RuleFor(x => x.ParentId).NotEqual(Guid.Empty);

        When(x => x.HasPermit, () =>
        {
            RuleFor(x => x.PermitNumber).NotEmpty().MaximumLength(50);
        });
    }
}
```

FastEndpoints auto-discovers validators — no registration needed. Validation runs before `HandleAsync` and returns 400 on failure.

For complex cross-field validation or domain checks that require database access, do those in the library factory method and return `SystemResult.Failure(...)`.

---

## 6. SystemResult Flow

The standard pattern for mutations:

```csharp
// Endpoint HandleAsync:
public override async Task HandleAsync(CreateFooRequest req, CancellationToken ct)
{
    var result = await Foo.CreateAsync(req, dbContext, currentUser);
    await SendAndSaveChangesAsync(result, dbContext, ct);
}

// Library factory method (static, in Library project):
public static async Task<SystemResult<Foo>> CreateAsync(
    CreateFooRequest req,
    IReadOnlyPriisDbContext dbContext,
    ICurrentUser currentUser,
    CancellationToken ct = default)
{
    // 1. Input validation
    var validator = new InlineValidator<CreateFooRequest>();
    validator.RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
    var validation = validator.Validate(req);
    if (!validation.IsValid)
        return new ValidationFailures(validation.Errors);

    // 2. Domain checks
    if (await dbContext.Foos.AsNoTracking().AnyAsync(f => f.Name == req.Name, ct))
        return SystemResult.Failure(nameof(req.Name), "Namn är redan registrerat.");

    // 3. Happy path — implicit conversion to SystemResult<T>
    return new Foo { Name = req.Name, CreatedBy = currentUser.Id };
}
```

**Chaining API** for composing multiple domain steps:

```csharp
// .Then() — synchronous transform, short-circuits on failure
var result = ValidateInput(req)
    .Then(validated => BuildDomainObject(validated));

// .ThenAsync() — async transform
var result = await ValidateInput(req)
    .ThenAsync(async validated => await PersistAsync(validated, ct));

// .OnSuccess() / .OnFailure() — side effects
await result
    .OnSuccess(async () => await notifications.SendAsync(ct))
    .OnFailure(errors => logger.LogWarning("Failure: {Errors}", errors));

// .FailureOr() — produce a typed result from a non-typed SystemResult
var typedResult = await CheckPreconditionsAsync(ct)
    .FailureOr(new FooCreated(entity.Id));
```

---

## 7. 201 Created Responses

A create endpoint derives from `ExtendedCreateEndpoint<TRequest, TResponse, TResourceEndpoint>`, where `TResourceEndpoint` is the GET endpoint the Location header points at (it implements `IResourceEndpoint` and exposes its `RouteParameter`). `SendCreatedAndSaveChangesAsync` is the 201 counterpart of `SendAndSaveChangesAsync`: it saves, runs the optional `afterSave` hook with the saved entity, and answers 201 with the Location header, or sends the validation failures from whichever step produced them.

```csharp
public sealed class CreateControlTicketEndpoint(
    PriisDbContext dbContext, TimeProvider timeProvider, ControlTicket.AsyncMutations controlTicketMutations, ...)
    : ExtendedCreateEndpoint<CreateControlTicketRequest, CreatedResponse, GetControlTicketProfileEndpoint>
{
    public override async Task HandleAsync(CreateControlTicketRequest req, CancellationToken ct)
    {
        var now = timeProvider.GetUtcNow();
        var creationData = new ControlTicket.CreationData { OperationId = req.OperationId, Reason = req.Reason, /* ... */ };

        // SystemResult<ControlTicket>: the entity's mutation, then Add; the save happens below
        var created = await controlTicketMutations.CreateAsync(creationData, now, ct)
            .Then(ticket =>
            {
                dbContext.ControlTickets.Add(ticket);
                return SystemResult.From(ticket);
            });

        await SendCreatedAndSaveChangesAsync(
            created,
            dbContext,
            response: ticket => new CreatedResponse(ticket.Id),
            afterSave: ticket => PublishCreatedEventsAsync(ticket, ct),   // side effects that need the saved entity
            cancellation: ct);
    }
}
```

`response` runs **after** the save, so it also works for an entity whose key EF assigns during `SaveChanges`. Business events belong in `afterSave`, never before the save. Do not hand-roll save + `Send.CreatedAtAsync` + event publishing in `HandleAsync`; a review will ask for this class.

Most create endpoints predate this class and still hand-roll save + `Send.CreatedAtAsync` (`CreateFeedbackTicketEndpoint`, `CreateOperationEndpoint`, `CreateSupplierEndpoint`, `CreateUserEndpoint`, `CreateMatchingTicketEndpoint`, `CreateContractTemplateEndpoint`, `CreateChangeRequestEndpoint`, `CreateSystemNotificationEndpoint`, `AddMatchingTicketCommentEndpoint`, `StartNewMatchingIterationEndpoint`; only `CreateControlTicketEndpoint` and `CreateOperationObjectEndpoint` use it). **Do not copy them**, even when one of them is the sibling the quick-start rule sends you to: a new create endpoint uses `ExtendedCreateEndpoint`, and one you touch moves onto it. Raw `Send.CreatedAtAsync<TEndpoint>(new RouteValueDictionary { ... }, body, cancellation: ct)` is only for a created resource that is not an `IBaseEntity` saved through the context.

---

## 8. File Uploads

```csharp
public override void Configure()
{
    Post("/documents");
    Policy(SystemAction.UploadDocument);
    AllowFileUploads();
    Options(x => x.RequireRateLimiting(CUDRateLimitingPolicy.Name));
}

public override async Task HandleAsync(UploadDocumentRequestWrapper req, CancellationToken ct)
{
    // req.Json contains the structured request; req.File contains the upload
}

// Request record wraps the JSON payload and the file:
public sealed record UploadDocumentRequestWrapper(UploadDocumentRequest Json, IFormFile? File);
```

---

## 9. Anti-Patterns Checklist

```
❌ Deriving from Endpoint<TReq, TRes> directly — always use ExtendedEndpoint
❌ Missing Policy(...) call — no anonymous access
❌ Returning EF entity types as TResponse — project to records/DTOs
❌ Using raw Send.OkAsync / Send.NoContentAsync inside HandleAsync — use SendAsync helpers
❌ Throwing exceptions in HandleAsync for expected failures — use SendErrorsAsync
❌ Missing rate limiting on mutation endpoints
❌ Not sealing endpoint classes (they should be sealed unless inheritance is deliberate)
❌ Calling dbContext.SaveChangesAsync manually in HandleAsync — use SendAndSaveChangesAsync
❌ `if (result.IsFailure) { SendErrorsAsync; return; } Save; Send` by hand — that is `SendAndSaveChangesAsync(result, dbContext, ct)` in one line
❌ A create endpoint that saves, publishes events and answers 201 itself — derive from ExtendedCreateEndpoint and use SendCreatedAndSaveChangesAsync(result, dbContext, response:, afterSave:) (see §7)
❌ An entity id both in the route and in the request body — read it with Route<Guid>(RouteParameterX); the body carries only the payload
❌ A second endpoint with the same HandleAsync shape as its sibling (statistics, ticket types) — extract the shared part next to the sibling instead of copying it
```
