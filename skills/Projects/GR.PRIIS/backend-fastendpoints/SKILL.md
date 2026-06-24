---
name: backend-fastendpoints
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

```csharp
// In HandleAsync, after creating and saving:
await Send.CreatedAtAsync<GetFooEndpoint>(
    new RouteValueDictionary { ["FooId"] = result.Result.Id },
    new CreateFooResponse(result.Result.Id),
    cancellation: ct);
```

Use `Send.CreatedAtAsync<TEndpoint>` (not `SendAsync`) when a 201 with a Location header is needed. The `RouteValueDictionary` must match the route template of the target GET endpoint.

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
```
