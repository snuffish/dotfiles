---
name: priis-backend-testing
description: "[Project: GR.PRIIS.Backend] Testing conventions for GR.PRIIS.Backend — TUnit on Microsoft.Testing.Platform in every test project (xUnit is fully migrated and gone). BaseTUnitIntegrationTests, factory methods, per-test mocks, assertions, AutoRollback, test data helpers, and minimum coverage rules. Use when writing, modifying, fixing, or running tests, adding test coverage, or diagnosing a failing test. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# Testing — Project Conventions

## Contents

- Framework Overview
- Running TUnit Tests
- TUnit Integration Tests (base class, test structure)
- Factory Methods
- HTTP Test Helpers
- TUnit Assertions
- `[AutoRollback]`
- Database Setup in Tests
- Minimum Coverage Per Endpoint
- Anti-Patterns Checklist

---

## Framework Overview

Every project under `tests/` uses **TUnit** and nothing else. The version is pinned centrally in `Directory.Packages.props`.

| Project | Kind |
|---------|------|
| `GR.PRIIS.API.IntegrationTests` | Integration tests against a real SQL Server (Testcontainers) |
| `GR.PRIIS.API.UnitTests`, `GR.PRIIS.Library.UnitTests`, `GR.PRIIS.Worker.UnitTests`, `GR.PRIIS.ServiceDefaults.UnitTests` | Unit tests (NSubstitute, MockQueryable) |
| `GR.PRIIS.ArchitectureTests` | ArchUnitNET rules |

**Old pattern:** xUnit and FluentAssertions were removed from the repo in May 2026. If you meet `[Fact]`, `[Theory]`, `Assert.Equal(...)` or `.Should()` in a test, it is either ArchUnitNET's fluent API (`Classes().That()...Should()`) in the architecture tests or a stale branch — not a convention to follow.

---

## Running TUnit Tests

TUnit runs on **Microsoft.Testing.Platform (MTP)**, not VSTest (`global.json` sets `test.runner`). The `--filter` flag is VSTest syntax and silently produces zero test runs with TUnit. Use `--treenode-filter` instead.

The integration tests start a SQL Server container through Testcontainers, so **Docker Desktop must be running** before you run them. Without it the run fails while starting the container, not in any test.

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

`--treenode-filter` and `--list-tests` are MTP flags and go directly on the command line. A bare project path (`dotnet test tests/GR.PRIIS.API.IntegrationTests ...`) is also accepted, but arguments placed after `--` are silently dropped.

---

## TUnit Integration Tests

### Base Class

```csharp
internal abstract class BaseTUnitIntegrationTests
{
    [ClassDataSource<TUnitApiWebFactory>(Shared = SharedType.PerTestSession)]
    public required TUnitApiWebFactory ApiWebFactory { get; set; } = null!;

    // Per-test NSubstitute mocks for the external clients, keyed by TestContext.Current.Id
    protected IEmailClient EmailClientMock { get; }
    protected ISmsClient SmsClientMock { get; }
    protected IGeocodingClient GeocodingClientMock { get; }
    protected IGepositValidClient GepositClientMock { get; }

    [After(Test)]
    public void CleanUpPerTestMocks() { /* drops the mock instances that belong to this test */ }
}
```

Test classes derive from `BaseTUnitIntegrationTests`. The `ApiWebFactory` is shared per test session (one SQL Server container, seeded once). The external clients (email, SMS, geocoding, Geposit) are **per-test** mocks: configure them directly on the property inside the test — no setup or reset call is needed, and other tests running in parallel never see your configuration.

```csharp
// Arrange a mocked external call
GepositClientMock
    .ValidateAddressAsync(Arg.Any<Address>(), Arg.Any<CancellationToken>())
    .Returns(SystemResult.From<AddressSuggestion?>(null));

// Assert the external call did (not) happen
await GepositClientMock.Received(0)
    .SuggestAddressesAsync(Arg.Any<string>(), Arg.Any<int>(), Arg.Any<CancellationToken>());
```

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
            .CreateClientAsNoAccessUserAsync(SystemAction.CreateFoo);

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

// Authenticated as an existing user id (synchronous — no DB lookup)
ApiWebFactory.CreateClientAsUserId(userId)

// Authenticated with a specific role (one immutable seeded user per RoleType)
await ApiWebFactory.CreateClientAsRoleAsync(RoleType.RegisterAdministrator)
await ApiWebFactory.CreateClientAsRoleAsync(RoleType.OperationContactPerson)

// Authenticated with a user who does NOT have a specific SystemAction
// (automatically finds a role without that permission)
await ApiWebFactory.CreateClientAsNoAccessUserAsync(SystemAction.CreateFoo)
await ApiWebFactory.CreateClientAsNoAccessUserAsync([SystemAction.A, SystemAction.B])

// Full cookie-based login (use when testing auth flows, not general endpoint testing)
await ApiWebFactory.CreateClientAndLoginAsync()
await ApiWebFactory.CreateClientAndLoginAsync("email@priis.se", "Password!")
```

All async factory methods return `(HttpClient Client, Guid UserId)`. Clients are cached per user; pass `skipCache: true` when a test needs a fresh `HttpClient` (for example to mutate default headers).

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
await Assert.That(list).IsEmpty();
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
- The test database is `GR.PRIIS-testing` — it is shared across the session and seeded once
- Seeding is `DataSeeder.RunAsync(skipDemoData: true)` plus one immutable user per `RoleType` (`IntegrationTestSeedData.ImmutableRoleUsers`); `CreateClientAsRoleAsync` resolves those users, so never delete or alter them

---

## Database Setup in Tests

Prefer the extension methods in `tests/GR.PRIIS.API.IntegrationTests/TestDataHelpers/` over hand-built entities — they create valid aggregates with all required relations:

```csharp
// Operation with supplier, category, address and contact person
var operation = await ApiWebFactory.RunDbContextActionAsync(async db =>
{
    var operation = await db.CreateBasicOperationForTestAsync(ApiWebFactory.Services, operationName: "Solgården HVB");
    await db.SaveChangesAsync();
    return operation;
});

// Full matching ticket → iteration → selection → contracts
var data = await ApiWebFactory.RunDbContextActionAsync(async db =>
{
    var data = await db.CreateFullMatchingTestDataAsync(ApiWebFactory.Services, new FullMatchingTestDataOptions
    {
        ActivateSelectionAndAddContracts = true,
    });
    await db.SaveChangesAsync();
    return data;
});
```

Direct DbContext access:

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

// Operation mutations need the Operation.AsyncMutations service from the same scope
await ApiWebFactory.RunOperationMutationsActionAsync(async (db, mutations) =>
{
    var operation = await db.Operations.FirstAsync(o => o.Id == operationId);
    await mutations.ChangeStatusAsync(operation, RegisterStatus.Terminated, "Avslutad i test");
});

// Service-level setup via DI (for scenarios requiring domain services)
await ApiWebFactory.RunServiceProviderActionAsync(async sp =>
{
    var userManager = sp.GetRequiredService<PriisUserManager>();
    await userManager.AddRoleToUserAsync(user, new UserRoleDto(RoleType.OperationContactPerson, operationId));
    return Task.CompletedTask;
});
```

Note: the overload that **returns a value** does not call `SaveChangesAsync` — call it yourself inside the func when you both create data and need its id back (as in the helper examples above).

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

## Anti-Patterns Checklist

```
❌ [Fact] / [Theory] — xUnit; use [Test]
❌ Assert.Equal(expected, actual) — xUnit; use await Assert.That(actual).IsEqualTo(expected)
❌ result.Should().Be(...) — FluentAssertions is no longer referenced; use await Assert.That(result).IsEqualTo(...)
❌ Missing [AutoRollback] on mutation tests
❌ Negative tests without asserting result is null
❌ Seeding custom test data without [AutoRollback]
❌ Resetting or re-registering the external client mocks — they are per-test already; configure EmailClientMock etc. directly
❌ Using CreateClientAndLoginAsync for general endpoint testing (use CreateClientAsUserAsync — faster, no cookie round-trip)
❌ Asserting only status code on success path — also assert result is not null and key fields
❌ A new test that repeats an existing test's arrange to assert one new field or branch — add the assertion to the existing test, or turn it into [Arguments(...)] cases; new tests are for new scenarios
❌ A private CreateXAsync helper that already exists in another test class — move it to TestDataHelpers and use it from both
❌ Reflection (GetProperty(...).SetValue) to put an entity in a state — add a *ForTest method on the entity next to the existing ones
❌ Only the happy path of a new guard, catch or rollback — the branch the fix adds needs the test that fails without it
❌ Inserting a fixed value into a unique index (e.g. new Category { Name = "Test Category" }) — parallel tests block on each other's uncommitted row; use db.AddTestCategory() or a Guid suffix
❌ Mutating seeded rows other tests read (first seeded category and its parameters, shared seeded users) — create your own; see docs/Tests.md "Diagnosing timeouts and lock contention" and scripts/sql-lock-monitor.sh
❌ dotnet test --filter "FullyQualifiedName~ClassName" — VSTest syntax; silently runs 0 tests with TUnit/MTP
❌ dotnet test <project> -- --treenode-filter "..." — arguments after "--" are not forwarded under MTP; the whole suite runs
✅ dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/ClassName/*"
```
