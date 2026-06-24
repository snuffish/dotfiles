---
name: backend-testing
description: "[Project: GR.PRIIS.Backend] Testing conventions for GR.PRIIS.Backend — TUnit (preferred for new tests) and xUnit (existing). BaseTUnitIntegrationTests, factory methods, assertions, AutoRollback, and minimum coverage rules. Load when writing or modifying tests. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# Testing — Project Conventions

## Framework Overview

| Framework | Version | Status | Used in |
|-----------|---------|--------|---------|
| TUnit | 1.37.24 | **Preferred for all new tests** | `GR.PRIIS.API.IntegrationTests` |
| xUnit | 2.9.3 | Existing, do not convert | unit test projects |

**Rule:** Write all new tests in TUnit. Do not convert existing xUnit tests unless explicitly asked. When editing an existing xUnit test file, follow its existing style.

---

## Running TUnit Tests

TUnit runs on **Microsoft.Testing.Platform (MTP)**, not VSTest. The `--filter` flag is VSTest syntax and silently produces zero test runs with TUnit. Use `--treenode-filter` instead.

```bash
# Run all integration tests
dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release

# Filter by test class (run all tests in one class)
dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/CreateFooEndpointTests/*"

# Filter by test method (exact or prefix with wildcard)
dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/CreateFooEndpointTests/CreateFoo_ValidRequest_ReturnsCreated"

# dotnet run also works and accepts the same flags
dotnet run --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/CreateFooEndpointTests/*"
```

**Treenode filter format:** `/<Assembly>/<Namespace>/<Class>/<Method>` — use `*` as wildcard at any segment. For most filtering needs `"/*/*/ClassName/*"` is sufficient.

---

## TUnit Integration Tests

### Base Class

```csharp
internal abstract class BaseTUnitIntegrationTests
{
    [ClassDataSource<TUnitApiWebFactory>(Shared = SharedType.PerTestSession)]
    public TUnitApiWebFactory ApiWebFactory { get; set; } = null!;

    [After(Test)]
    public void ResetSharedMocks()
    {
        ApiWebFactory.ResetExternalServiceMocks();
        // also clears per-test email client registry
    }
}
```

Test classes derive from `BaseTUnitIntegrationTests`. The `ApiWebFactory` is shared per test session (one SQL Server container, seeded once). Mocks are reset after each test.

### Test Structure

```csharp
internal sealed class CreateFooEndpointTests : BaseTUnitIntegrationTests
{
    [Test]
    public async Task CreateFoo_NoCookie_ReturnsUnauthorized()
    {
        var (response, result) = await ApiWebFactory
            .CreateClient()
            .POSTAsync<CreateFooEndpoint, CreateFooRequest, CreateFooResponse>(
                new CreateFooRequest(Guid.NewGuid(), "Name"));

        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.Unauthorized);
        await Assert.That(result).IsNull();
    }

    [Test]
    public async Task CreateFoo_Forbidden_ReturnsForbidden()
    {
        var (client, _) = await ApiWebFactory
            .CreateClientAndLoginAsNoAccessUserAsync(SystemAction.CreateFoo);

        var (response, result) = await client
            .POSTAsync<CreateFooEndpoint, CreateFooRequest, CreateFooResponse>(
                new CreateFooRequest(Guid.NewGuid(), "Name"));

        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.Forbidden);
        await Assert.That(result).IsNull();
    }

    [Test, AutoRollback]
    public async Task CreateFoo_ValidRequest_ReturnsCreated()
    {
        // Arrange — set up prerequisite data
        var parentId = await ApiWebFactory.RunDbContextActionAsync(async db =>
        {
            var parent = db.Parents.AsNoTracking().First();
            return parent.Id;
        });

        var (client, _) = await ApiWebFactory.CreateClientAsUserAsync();

        // Act
        var (response, result) = await client
            .POSTAsync<CreateFooEndpoint, CreateFooRequest, CreateFooResponse>(
                new CreateFooRequest(parentId, "Valid Name"));

        // Assert
        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.Created);
        await Assert.That(result).IsNotNull();
        await Assert.That(result!.Id).IsNotEqualTo(Guid.Empty);
    }

    [Test, AutoRollback]
    public async Task CreateFoo_InvalidName_ReturnsBadRequest_ResultIsNull()
    {
        var (client, _) = await ApiWebFactory.CreateClientAsUserAsync();

        var (response, result) = await client
            .POSTAsync<CreateFooEndpoint, CreateFooRequest, CreateFooResponse>(
                new CreateFooRequest(Guid.NewGuid(), ""));   // empty name

        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.BadRequest);
        await Assert.That(result).IsNull();
    }
}
```

---

## Factory Methods

```csharp
// Unauthenticated — for testing 401
ApiWebFactory.CreateClient()

// Authenticated as default power user (integrationpoweruser@priis.se)
await ApiWebFactory.CreateClientAsUserAsync()
await ApiWebFactory.CreateClientAsUserAsync("custom@priis.se")

// Authenticated with a specific role
await ApiWebFactory.CreateClientAsRoleAsync(RoleType.RegisterAdministrator)
await ApiWebFactory.CreateClientAsRoleAsync(RoleType.OperationContactPerson)

// Authenticated with a user who does NOT have a specific SystemAction
// (automatically finds a role without that permission)
await ApiWebFactory.CreateClientAndLoginAsNoAccessUserAsync(SystemAction.CreateFoo)
await ApiWebFactory.CreateClientAndLoginAsNoAccessUserAsync([SystemAction.A, SystemAction.B])

// Full cookie-based login (use when testing auth flows, not general endpoint testing)
await ApiWebFactory.CreateClientAndLoginAsync()
await ApiWebFactory.CreateClientAndLoginAsync("email@priis.se", "Password!")
```

All async factory methods return `(HttpClient Client, Guid UserId)`.

---

## HTTP Test Helpers

FastEndpoints provides typed HTTP extension methods:

```csharp
// All return (HttpResponseMessage response, TResponse? result)
var (response, result) = await client.GETAsync<GetFooEndpoint, GetFooRequest, FooDto>(request);
var (response, result) = await client.POSTAsync<CreateFooEndpoint, CreateFooRequest, CreateFooResponse>(request);
var (response, result) = await client.PUTAsync<UpdateFooEndpoint, UpdateFooRequest, FooDto>(request);
var (response, result) = await client.DELETEAsync<DeleteFooEndpoint, DeleteFooRequest, EmptyResponse>(request);
var (response, result) = await client.PATCHAsync<PatchFooEndpoint, PatchFooRequest, FooDto>(request);
```

For endpoints without a response body:

```csharp
var response = await client.DELETEAsync<DeleteFooEndpoint, DeleteFooRequest>(request);
```

---

## TUnit Assertions

Always use `await Assert.That(...)` — never `Assert.Equal(...)` or FluentAssertions `.Should()` in TUnit tests.

```csharp
await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.OK);
await Assert.That(result).IsNotNull();
await Assert.That(result).IsNull();
await Assert.That(result!.Id).IsNotEqualTo(Guid.Empty);
await Assert.That(result!.Items.Length).IsGreaterThan(0);
await Assert.That(flag).IsTrue();
await Assert.That(flag).IsFalse();
await Assert.That(list).Contains(item);
```

---

## `[AutoRollback]`

Wrap the test in a transaction that rolls back on completion. Required on any test that mutates the database.

```csharp
[Test, AutoRollback]
public async Task CreateFoo_ValidRequest_ReturnsCreated() { ... }
```

Rules:
- Read-only tests (GET) do not need `[AutoRollback]`
- Any POST, PUT, PATCH, DELETE test that hits a real endpoint must have `[AutoRollback]`
- The TUnit test database is `GR.PRIIS-testing-tunit` — it is shared across the session and seeded once
- `TUnitApiWebFactory` seeds `ImmutableRoleUserSet.Full` (not `LegacyXUnitCompatible`)

---

## Database Setup in Tests

```csharp
// Read data (no save) — returns a value
var id = await ApiWebFactory.RunDbContextActionAsync(async db =>
{
    var entity = db.Foos.AsNoTracking().First(f => f.IsActive);
    return entity.Id;
});

// Mutate data (auto-saves after func completes)
await ApiWebFactory.RunDbContextActionAsync(async db =>
{
    var entity = await db.Foos.FindAsync(id);
    entity!.SetStatus(FooStatus.Inactive);
});

// Service-level setup via DI (for scenarios requiring domain services)
await ApiWebFactory.RunServiceProviderActionAsync(async sp =>
{
    var userManager = sp.GetRequiredService<PriisUserManager>();
    await userManager.AddRoleToUserAsync(user, new UserRoleDto(RoleType.Viewer, operationId));
    return Task.CompletedTask;
});
```

---

## Minimum Coverage Per Endpoint

Every new endpoint must have at least these tests:

| Test | Auth | Expected status |
|------|------|-----------------|
| No cookie | None (`CreateClient()`) | 401 Unauthorized |
| Forbidden | User without the required `SystemAction` | 403 Forbidden |
| Happy path | Authorized user | 200/201/204 |

Additional tests for input validation, edge cases, and business rule failures are strongly encouraged.

**Negative tests must always assert `result` is null:**
```csharp
await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.BadRequest);
await Assert.That(result).IsNull();  // ← required
```

---

## xUnit Patterns (Existing Test Projects)

When editing files in `GR.PRIIS.API.IntegrationTests` or the unit test projects, follow their existing style:

```csharp
// Attributes
[Fact]             // single test
[Theory]           // parameterized test
[InlineData(...)]  // theory input

// Assertions (FluentAssertions)
result.Should().Be(expected);
result.Should().NotBeNull();
result.Should().BeEquivalentTo(expected);
collection.Should().Contain(item);
```

Do not mix TUnit and xUnit assertions in the same file.

---

## Anti-Patterns Checklist

```
❌ [Fact] / [Theory] in TUnit test project — use [Test]
❌ Assert.Equal(expected, actual) in TUnit — use await Assert.That(actual).IsEqualTo(expected)
❌ result.Should().Be(...) in TUnit tests — that's FluentAssertions, wrong framework
❌ Missing [AutoRollback] on mutation tests
❌ Negative tests without asserting result is null
❌ Seeding custom test data without [AutoRollback]
❌ Using CreateClientAndLoginAsync for general endpoint testing (use CreateClientAsUserAsync — faster, no cookie round-trip)
❌ Asserting only status code on success path — also assert result is not null and key fields
❌ dotnet test --filter "FullyQualifiedName~ClassName" — VSTest syntax; silently runs 0 tests with TUnit/MTP
❌ dotnet test tests/GR.PRIIS.API.IntegrationTests ... — bare path fails; use --project
✅ dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/ClassName/*"
```
