---
name: source-command-backend-scaffold
description: "[Project: GR.PRIIS.Backend] Scaffold a complete FastEndpoints feature slice — endpoint, validator, library method, and TUnit integration tests. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# source-command-scaffold

Use this skill when the user asks to run the migrated source command `scaffold`.

## Command Template

# /scaffold — Feature Scaffolding

Generate a complete vertical slice for a new FastEndpoints endpoint. Provide a short description:

```
/scaffold "POST /operations/{operationId}/notes — create a note, SystemAction.CreateOperationNote"
/scaffold "GET /operations/{operationId}/notes — list notes, SystemAction.ListOperationNotes"
/scaffold "PUT /operations/{operationId}/notes/{noteId} — update note, SystemAction.UpdateOperationNote"
```

---

## Step 1: Gather Context

Before generating, read:
- The nearest `*Endpoint.cs` in the same feature domain to understand folder structure
- The relevant entity in `source/GR.PRIIS.Library/` to understand the domain model

Ask for clarification if: request/response shape is unclear, or the domain entity doesn't exist yet.

---

## Step 2: Determine File Locations

```
source/GR.PRIIS.API/Features/{Domain}/{Verb}{Feature}Endpoint.cs
source/GR.PRIIS.Library/Features/{Domain}/{Verb}{Feature}.cs      ← or inline in entity file
tests/GR.PRIIS.API.IntegrationTests.TUnit/{Domain}/{Verb}{Feature}EndpointTests.cs
```

---

## Step 3: Generate Endpoint

```csharp
// source/GR.PRIIS.API/Features/Operations/Notes/CreateOperationNoteEndpoint.cs
namespace GR.PRIIS.API.Features.Operations.Notes;

public sealed class CreateOperationNoteEndpoint(
    PriisDbContext dbContext,
    ICurrentUser currentUser)
    : ExtendedEndpoint<CreateOperationNoteRequest, CreateOperationNoteResponse>
{
    public override void Configure()
    {
        Post("/operations/{operationId}/notes");
        Policy(SystemAction.CreateOperationNote);
        Options(x => x.RequireRateLimiting(CUDRateLimitingPolicy.Name));
        Summary(s => s.Summary = "Create a note on an operation");
    }

    public override async Task HandleAsync(CreateOperationNoteRequest req, CancellationToken ct)
    {
        var result = await OperationNote.CreateAsync(req, dbContext, currentUser);
        await SendAndSaveChangesAsync(result, dbContext, ct);
    }
}

public sealed record CreateOperationNoteRequest(Guid OperationId, string Content);
public sealed record CreateOperationNoteResponse(Guid Id);

public sealed class CreateOperationNoteRequestValidator : Validator<CreateOperationNoteRequest>
{
    public CreateOperationNoteRequestValidator()
    {
        RuleFor(x => x.OperationId).NotEqual(Guid.Empty);
        RuleFor(x => x.Content).NotEmpty().MaximumLength(2000);
    }
}
```

**Rules for endpoints:**
- Always derive from `ExtendedEndpoint<TRequest, TResponse>` — never from FastEndpoints base types directly
- DI via primary constructor — no field assignments
- Every endpoint must call `Policy(...)` — no anonymous access
- Mutation endpoints (POST/PUT/DELETE/PATCH): add `Options(x => x.RequireRateLimiting(CUDRateLimitingPolicy.Name))`
- Read endpoints: `.AsNoTracking().Where(...).Select(x => new ResponseDto { ... }).FirstOrDefaultAsync(ct)` — never return EF entities
- Use `await SendAndSaveChangesAsync(result, dbContext, ct)` for mutations
- Use `await SendAsync(projection, ct)` for reads
- 201 Created: `await Send.CreatedAtAsync<GetFooEndpoint>(new RouteValueDictionary { ["FooId"] = foo.Id }, response, cancellation: ct)`

**Endpoint base class variants:**
```csharp
ExtendedEndpoint<TRequest, TResponse>       // standard with body + typed response
ExtendedEndpoint<TRequest>                  // no-content response (204)
ExtendedEndpointWithoutRequest              // no request body, no content
ExtendedEndpointWithoutRequest<TResponse>   // no request body, typed response
```

---

## Step 4: Generate Library Method

```csharp
// source/GR.PRIIS.Library/Features/Operations/OperationNote.cs
public sealed class OperationNote : AuditableEntity
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public Guid OperationId { get; init; }
    public string Content { get; private set; } = "";

    public static async Task<SystemResult<OperationNote>> CreateAsync(
        CreateOperationNoteRequest req,
        IReadOnlyPriisDbContext dbContext,
        ICurrentUser currentUser,
        CancellationToken ct = default)
    {
        // 1. Validate input
        var validator = new InlineValidator<CreateOperationNoteRequest>();
        validator.RuleFor(x => x.Content).NotEmpty().MaximumLength(2000);
        var validation = validator.Validate(req);
        if (!validation.IsValid)
            return new ValidationFailures(validation.Errors);

        // 2. Domain checks
        var operationExists = await dbContext.Operations
            .AsNoTracking()
            .AnyAsync(o => o.Id == req.OperationId, ct);
        if (!operationExists)
            return SystemResult.Failure(nameof(req.OperationId), "Verksamheten finns inte.");

        // 3. Happy path — return entity (implicit conversion to SystemResult<T>)
        return new OperationNote
        {
            OperationId = req.OperationId,
            Content = req.Content
        };
    }
}
```

**Rules for library methods:**
- Use `IReadOnlyPriisDbContext` for read-only access within the factory
- Return `SystemResult<TEntity>` — never throw for expected validation failures
- Swedish error messages for domain failures
- State changes: implement as command methods (`SetContent(string content)`, etc.), never direct property assignment from outside the entity
- Entity properties that mutate state: `private set`

---

## Step 5: Generate TUnit Integration Tests

Minimum 3 tests per endpoint. Always write all three — never skip the auth tests.

```csharp
// tests/GR.PRIIS.API.IntegrationTests.TUnit/Operations/Notes/CreateOperationNoteEndpointTests.cs
namespace GR.PRIIS.API.IntegrationTests.TUnit.Operations.Notes;

internal sealed class CreateOperationNoteEndpointTests : BaseTUnitIntegrationTests
{
    [Test]
    public async Task CreateOperationNote_NoCookie_ReturnsUnauthorized()
    {
        var (response, result) = await ApiWebFactory
            .CreateClient()
            .POSTAsync<CreateOperationNoteEndpoint, CreateOperationNoteRequest, CreateOperationNoteResponse>(
                new CreateOperationNoteRequest(Guid.NewGuid(), "Test content"));

        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.Unauthorized);
        await Assert.That(result).IsNull();
    }

    [Test]
    public async Task CreateOperationNote_Forbidden_ReturnsForbidden()
    {
        var (client, _) = await ApiWebFactory
            .CreateClientAndLoginAsNoAccessUserAsync(SystemAction.CreateOperationNote);

        var (response, result) = await client
            .POSTAsync<CreateOperationNoteEndpoint, CreateOperationNoteRequest, CreateOperationNoteResponse>(
                new CreateOperationNoteRequest(Guid.NewGuid(), "Test content"));

        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.Forbidden);
        await Assert.That(result).IsNull();
    }

    [Test, AutoRollback]
    public async Task CreateOperationNote_ValidRequest_ReturnsCreated()
    {
        // Arrange
        var operationId = await ApiWebFactory.RunDbContextActionAsync(async db =>
        {
            // set up prerequisite data and return its ID
            var op = db.Operations.AsNoTracking().First();
            return op.Id;
        });

        var (client, _) = await ApiWebFactory.CreateClientAsUserAsync();

        // Act
        var (response, result) = await client
            .POSTAsync<CreateOperationNoteEndpoint, CreateOperationNoteRequest, CreateOperationNoteResponse>(
                new CreateOperationNoteRequest(operationId, "Test content"));

        // Assert
        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.Created);
        await Assert.That(result).IsNotNull();
        await Assert.That(result!.Id).IsNotEqualTo(Guid.Empty);
    }

    [Test, AutoRollback]
    public async Task CreateOperationNote_EmptyContent_ReturnsBadRequest_ResultIsNull()
    {
        var (client, _) = await ApiWebFactory.CreateClientAsUserAsync();

        var (response, result) = await client
            .POSTAsync<CreateOperationNoteEndpoint, CreateOperationNoteRequest, CreateOperationNoteResponse>(
                new CreateOperationNoteRequest(Guid.NewGuid(), ""));

        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.BadRequest);
        await Assert.That(result).IsNull();
    }
}
```

**TUnit rules:**
- `[Test]` not `[Fact]` / `[Theory]`
- `[AutoRollback]` on every test that inserts, updates, or deletes
- `await Assert.That(x).IsEqualTo(y)` — never `Assert.Equal(x, y)`
- Negative/error tests must assert `result` is `null`
- `BaseTUnitIntegrationTests` provides `ApiWebFactory` via `[ClassDataSource<TUnitApiWebFactory>]`

**Factory method reference:**
```csharp
ApiWebFactory.CreateClient()                                               // unauthenticated
ApiWebFactory.CreateClientAsUserAsync()                                    // default power user
ApiWebFactory.CreateClientAsRoleAsync(RoleType.RegisterAdministrator)     // specific role
ApiWebFactory.CreateClientAndLoginAsNoAccessUserAsync(SystemAction.X)     // user without X
ApiWebFactory.RunDbContextActionAsync(async db => { ... })                // returns value, no save
ApiWebFactory.RunDbContextActionAsync(async db => { ...; })               // mutates + saves
```

---

## Anti-Patterns — Never Generate

```
❌ .Include( on read-only GET endpoints — use .Select() navigation properties
❌ new List<T>() / new T[] / Array.Empty<T>() — use []
❌ [Fact] / [Theory] — use [Test]
❌ Assert.Equal(x, y) — use await Assert.That(x).IsEqualTo(y)
❌ Classes named FooService, FooHandler, FooManager, FooHelper
❌ throw for validation failures — return SystemResult.Failure(...)
❌ Missing [AutoRollback] on mutation tests
❌ Negative tests without asserting result is null
❌ Missing Policy(...) call — every endpoint requires authorization
❌ Deriving from FastEndpoints Endpoint<> directly — use ExtendedEndpoint
❌ Returning EF entity types from endpoints — project to records
```
