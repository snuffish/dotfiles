---
name: source-command-backend-migrate-to-tunit
description: "[Project: GR.PRIIS.Backend] Migrate xUnit integration tests from GR.PRIIS.API.IntegrationTests to the TUnit project. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# source-command-migrate-to-tunit

Use this skill when the user asks to run the migrated source command `migrate-to-tunit`.

## Command Template

# /migrate-to-tunit — xUnit → TUnit Test Migration

Migrate a namespace or folder of xUnit integration tests from `tests/GR.PRIIS.API.IntegrationTests/` to the TUnit project at `tests/GR.PRIIS.API.IntegrationTests.TUnit/`.

**Usage:**

```
/migrate-to-tunit Administrations/DocumentTemplates
/migrate-to-tunit Contracts
/migrate-to-tunit FeedbackTickets
```

The argument is the sub-path relative to the test project root.

---

## Step 1: Discover Files

Glob all `.cs` files in `tests/GR.PRIIS.API.IntegrationTests/{arg}/` and read each one. Identify:

- Which tests use `[Fact]` vs `[Theory]` + `[MemberData]` vs `[Theory]` + `[InlineData]`
- Which tests use `[AutoRollback]` at **class** level vs **method** level
- Which HTTP clients are field-injected via constructor vs created inline
- Which assertions use FluentAssertions (`.Should()`)
- Which tests rely on demo-data users (`hadya@priis.se`, `samir@priis.se`, etc.) or pre-seeded domain data (contracts, operations, etc.)
- Which tests use `IClassFixture<T>` or `WithWebHostBuilder`

---

## Step 2: Check the Target Folder

- **Folder doesn't exist** — normal path, create it.
- **Folder exists with different files** — native TUnit tests written before migration. Add new files alongside; do not touch existing ones.
- **Folder exists with a file of the same name** — stop and report, do not overwrite.

---

## Step 3: Apply the Conversion Rules

### 3a — Test Method Naming

**Rename every test method.** xUnit names are verbose; TUnit names follow `{Subject}_{Scenario}_{ExpectedOutcome}`.

Rules:

- Each segment is a **PascalCase compound word** — `NoCookie` not `No_Cookie`, `ValidCredentials` not `Valid_Credentials`
- No `Should_` prefix — use present-tense verbs: `Returns`, `Redirects`, `Persists`
- Drop filler words: `With_Valid_Credentials` → `ValidCredentials`

**Examples from native TUnit tests:**

```
GetFeatureFlags_NoCookie_ReturnsUnauthorized
GetFeatureFlags_ValidCredentials_ReturnsAllValues
CascadeContractTemplateStatus_NoCookie_ReturnsUnauthorized
UpdateMyProfile_FederatedUser_BlocksNameChange_ReturnsBadRequest
```

**Common conversions:**

| xUnit                                         | TUnit                                         |
| --------------------------------------------- | --------------------------------------------- |
| `X_With_No_Cookie_Should_Return_Unauthorized` | `GetX_NoCookie_ReturnsUnauthorized`           |
| `X_With_Valid_Credentials_Should_Return_OK`   | `GetX_ValidCredentials_ReturnsOk`             |
| `Create_X_With_Valid_Data_Should_Succeed`     | `CreateX_ValidRequest_ReturnsNoContent`       |
| `X_Should_Return_NotFound`                    | `GetX_NonExistentId_ReturnsNotFound`          |
| `X_For_LenaUser_Should_Return_Forbidden`      | `GetX_UserWithoutPermission_ReturnsForbidden` |
| `List_X_With_CategoryId_Should_Return_OK`     | `ListX_FilteredByCategoryId_ReturnsOk`        |

When the subject is obvious from the class name, omit it: `NoCookie_ReturnsUnauthorized`.

---

### 3b — Class Declaration and Cleanup

```csharp
// xUnit
public class FooTests : BaseIntegrationTests
{
    private readonly HttpClient _client;
    private readonly ApiWebFactory _apiWebFactory;
    public FooTests(ITestOutputHelper output, ApiWebFactory apiWebFactory) : base(output, apiWebFactory)
    {
        _client = apiWebFactory.CreateClient();
        _apiWebFactory = apiWebFactory;
    }
    protected override void Dispose(bool disposing) { _client.Dispose(); base.Dispose(disposing); }
}

// TUnit — remove constructor, fields, and Dispose
internal sealed class FooTests : BaseTUnitIntegrationTests
{
}
```

**Remove entirely:** constructor, all fields set from it (`_client`, `_apiWebFactory`), `Dispose(bool)` override.

**Access pattern:** `_apiWebFactory.X(...)` → `ApiWebFactory.X(...)` | `_client` → `ApiWebFactory.CreateClient()` inline per call site.

---

### 3c — Test Attributes

| xUnit                                        | TUnit                                                         |
| -------------------------------------------- | ------------------------------------------------------------- |
| `[Fact]`                                     | `[Test]`                                                      |
| `[Fact, AutoRollback]`                       | `[Test, AutoRollback]`                                        |
| `[Theory]` + `[MemberData(nameof(X))]`       | `[Test]` + `[MethodDataSource(nameof(X))]`                    |
| `[Theory]` + `[InlineData(v1, v2)]` repeated | `[Test]` + `[Arguments(v1, v2)]` repeated                     |
| `[AutoRollback]` on **class**                | Move to **method level** — only on methods that mutate the DB |

A test needs `[AutoRollback]` if it creates/modifies entities. Auth-only tests (checking 401/403 on a fresh request) never need it.

---

### 3d — Parameterized Tests (`[Theory]` → `[MethodDataSource]`)

```csharp
// xUnit
[Theory, MemberData(nameof(MyParams))]
public async Task Test(T1 a, T2 b) { ... }

public static TheoryData<T1, T2> MyParams()
{
    var d = new TheoryData<T1, T2>();
    d.Add(val1, val2);
    return d;
}

// TUnit — always use separate parameters, never a single tuple
[Test, MethodDataSource(nameof(MyParams))]
public async Task Test(T1 a, T2 b) { ... }

public static IEnumerable<(T1, T2)> MyParams()
{
    yield return (val1, val2);
}
```

**⚠️ Never receive the whole tuple as a single parameter (TUnit0301).** The data source returns tuples; the method receives them as separate parameters:

```csharp
// Wrong
public async Task Test((T1 a, T2 b) data) { }
// Correct
public async Task Test(T1 a, T2 b) { }
```

**⚠️ Wrap mutable reference types in `Func<T>` (TUnit0046).** When a test mutates a parameter (e.g. sets `req.CategoryId = id`), the data source must return a factory so each test gets a fresh instance:

```csharp
// Data source
public static IEnumerable<(Func<MyRequest>, string)> RequestData()
{
    yield return (() => new MyRequest { SearchText = "abc" }, "Category A");
}

// Test method
public async Task Test_Filter(Func<MyRequest> reqFactory, string categoryName)
{
    var req = reqFactory();
    req.CategoryId = await GetCategoryIdAsync(categoryName); // safe — fresh instance
    ...
}
```

---

### 3e — FluentAssertions → TUnit Assertions

| xUnit (FluentAssertions)                                                             | TUnit                                                                                            |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| `x.Should().Be(y)`                                                                   | `await Assert.That(x).IsEqualTo(y)`                                                              |
| `x.Should().NotBe(y)`                                                                | `await Assert.That(x).IsNotEqualTo(y)`                                                           |
| `x.Should().BeNull()`                                                                | `await Assert.That(x).IsNull()`                                                                  |
| `x.Should().NotBeNull()`                                                             | `await Assert.That(x).IsNotNull()`                                                               |
| `x.Should().BeTrue()`                                                                | `await Assert.That(x).IsTrue()` — also for `bool?`: use `.IsTrue()`, not `.IsEqualTo(true)` (TUnitAssertions0015) |
| `x.Should().BeFalse()`                                                               | `await Assert.That(x).IsFalse()`                                                                 |
| `x.Should().BeEmpty()`                                                               | `await Assert.That(x).IsEmpty()`                                                                 |
| `x.Should().NotBeEmpty()`                                                            | `await Assert.That(x).IsNotEmpty()`                                                              |
| `x.Should().BeOfType<T>()`                                                           | `await Assert.That(x).IsTypeOf<T>()`                                                             |
| `x.Should().HaveCount(n)`                                                            | `await Assert.That(x.Count).IsEqualTo(n)` — arrays use `.Length`                                 |
| `x.Should().ContainSingle()`                                                         | `await Assert.That(x.Count).IsEqualTo(1)`                                                        |
| `x.Should().ContainSingle(pred)`                                                     | `await Assert.That(x.Count(pred)).IsEqualTo(1)`                                                  |
| `x.Should().HaveCountGreaterThan(n)`                                                 | `await Assert.That(x.Count > n).IsTrue()`                                                        |
| `x.Should().Contain(pred)`                                                           | `await Assert.That(x.Any(pred)).IsTrue()`                                                        |
| `x.Should().NotContain(pred)`                                                        | `await Assert.That(x.Any(pred)).IsFalse()`                                                       |
| `x.Should().OnlyContain(pred)`                                                       | `await Assert.That(x.All(pred)).IsTrue()`                                                        |
| `x.Should().AllSatisfy(item => { item.P.Should().Contain("s"); })`                   | `await Assert.That(x.All(item => item.P.Contains("s", StringComparison.Ordinal))).IsTrue()`      |
| `x.Should().Contain(item)`                                                           | `await Assert.That(x.Contains(item)).IsTrue()`                                                   |
| `x.Should().NotContainNullOrWhiteSpaceOnly()` / `x.Should().NotBeNullOrWhiteSpace()` | `await Assert.That(x).IsNotEmpty()`                                                              |
| `x.Should().BeOnOrAfter(y)`                                                          | `await Assert.That(x >= y).IsTrue()`                                                             |
| `x.Should().BeOnOrBefore(y)`                                                         | `await Assert.That(x <= y).IsTrue()`                                                             |
| `x.Should().BeAfter(y)`                                                              | `await Assert.That(x > y).IsTrue()`                                                              |
| `x.Should().BeCloseTo(y, precision: TimeSpan.FromSeconds(5))`                        | `await Assert.That(x).IsEqualTo(y).Within(TimeSpan.FromSeconds(5))`                              |
| `x.Should().MatchRegex(pattern)`                                                     | `await Assert.That(Regex.IsMatch(x, pattern)).IsTrue()` + `using System.Text.RegularExpressions` |
| `x.Should().BeInAscendingOrder(...)` / `x.Should().BeInSqlOrder(expr, desc)`         | see §3f                                                                                          |

**Exception assertions:**

```csharp
// xUnit
var ex = await Assert.ThrowsAsync<ArgumentException>(() => SomeAsync());
ex.ParamName.Should().Be("url");

// TUnit — .Throws<T>() returns T? (nullable); use ! since the assertion guarantees non-null
var ex = await Assert.That(async () => await SomeAsync()).Throws<ArgumentException>();
await Assert.That(ex!.ParamName).IsEqualTo("url");
```

**⚠️ Use TUnit's native string assertions — never wrap with `string.IsNullOrEmpty/WhiteSpace`:**

```csharp
// Wrong — verbose anti-pattern
await Assert.That(string.IsNullOrWhiteSpace(x)).IsFalse();
await Assert.That(string.IsNullOrEmpty(x)).IsFalse();

// Correct — TUnit has string-specific assertions
await Assert.That(x).IsNotEmpty();   // not null and not empty
await Assert.That(x).IsEmpty();      // null or empty
```

**⚠️ CA1307 — `string.Contains` needs `StringComparison.Ordinal`:**

```csharp
s.Contains("literal", StringComparison.Ordinal)  // ✅
response.Headers.Contains("Set-Cookie")           // ✅ — HttpResponseHeaders.Contains has no overload, exempt
```

**⚠️ CA1829 — use `.Count` property, not `.Count()` method on indexable collections:**

```csharp
result.Items.Count    // ✅
result.Items.Count()  // ✗ — triggers CA1829
```

**⚠️ CA1841 — use `ContainsValue` not `Values.Contains` for Dictionary:**

```csharp
dict.ContainsValue("x")   // ✅
dict.Values.Contains("x") // ✗ — triggers CA1841
```

**⚠️ Never compare collection contents with `IsEqualTo`** — compares by reference. Use:

```csharp
await Assert.That(actual.SequenceEqual(expected)).IsTrue();
```

---

### 3f — SQL Order Assertions (`BeInSqlOrder`)

`GR.Library.FluentAssertions.BeInSqlOrder` is unavailable in TUnit. Use `SqlStringComparer` from `tests/GR.PRIIS.API.IntegrationTests.TUnit/Assertions/SqlStringComparer.cs`.

Add `using GR.PRIIS.API.IntegrationTests.TUnit.Assertions;`.

**String column only:**

```csharp
var actual = result.Items.Select(x => selector.Compile()(x)?.ToString()).ToList();
var expected = (orderByDescending
    ? actual.OrderByDescending(x => x, SqlStringComparer.Instance)
    : actual.OrderBy(x => x, SqlStringComparer.Instance)).ToList();
await Assert.That(actual.SequenceEqual(expected)).IsTrue();
```

**Mixed columns** (some `string`, some value types — detect via `Expression<Func<T, object?>>.Body.Type`):

```csharp
var compiledSelector = propertyOrderBy.Compile();
var actual = result!.Items!.Select(compiledSelector).ToList();
var expected = propertyOrderBy.Body.Type == typeof(string)
    ? (orderByDescending
        ? actual.OrderByDescending(x => x?.ToString(), SqlStringComparer.Instance).ToList()
        : actual.OrderBy(x => x?.ToString(), SqlStringComparer.Instance).ToList())
    : (orderByDescending
        ? actual.OrderByDescending(x => x).ToList()
        : actual.OrderBy(x => x).ToList());
await Assert.That(actual.SequenceEqual(expected)).IsTrue();
```

---

### 3g — `WithWebHostBuilder` Concurrency

Some xUnit tests use `IClassFixture<T>` with a custom `WebApplicationFactory`. In TUnit each test calls `ApiWebFactory.WithWebHostBuilder(...)` inline.

**Problem:** Concurrent `WithWebHostBuilder().CreateClient()` calls all trigger `Serilog.ReloadableLogger.Freeze()` on the same static `Log.Logger`, throwing `InvalidOperationException: The logger is already frozen`.

**Fix:** A shared `SemaphoreSlim(1, 1)` serialises all factory startups. If tests within a folder all need the same override pattern, create a static helper:

```csharp
internal static class MyTestClientFactory
{
    // Serialises WithWebHostBuilder().CreateClient() calls to prevent concurrent
    // Serilog ReloadableLogger.Freeze() on the same static Log.Logger.
    internal static readonly SemaphoreSlim StartupLock = new(1, 1);

    internal static async Task<HttpClient> CreateClientAsync(
        TUnitApiWebFactory apiWebFactory,
        AuthenticateResult authResult,
        IReadOnlyDictionary<string, string?>? configOverrides = null)
    {
        await StartupLock.WaitAsync();
        try
        {
            return apiWebFactory.WithWebHostBuilder(builder =>
            {
                if (configOverrides is { Count: > 0 })
                    builder.ConfigureAppConfiguration((_, cb) => cb.AddInMemoryCollection(configOverrides));
                builder.ConfigureTestServices(services =>
                {
                    services.AddSingleton<IAuthenticationService>(new FakeAuthenticationService { FixedResult = authResult });
                    services.Configure<LibraryOptions>(opt => opt.FrontendUrl = new("https://test.priis.se"));
                });
            }).CreateClient();
        }
        finally { StartupLock.Release(); }
    }
}
```

If the test also needs `AllowAutoRedirect = false`, acquire `StartupLock` directly and call `CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false })`.

**Do NOT use `[NotInParallel]` on the whole class** — it serialises all tests with that key across the entire suite and causes DB timeout cascades in unrelated tests.

---

### 3h — Test Data and Isolation

#### ⚠️ Never modify immutable seeded users

TUnit seeds a fixed set of immutable integration users (e.g. `integration.caseworkerindependent@priis.se`, `integration.placementmanager@priis.se`, `integration.operationcontactperson@priis.se`). These users are **shared across all parallel tests** in the suite.

**Do not add, remove, or change any roles, preferences, or data on these users during a test.** Doing so causes race conditions and flaky failures in unrelated tests running in parallel.

This means:
- **Never** call `EnsureOperationContactPersonRoleAsync("integration.X", operationId)` — it adds an `OperationUserRole` to the shared user.
- **Never** call `CreateClientAsRoleAsync(RoleType.X)` and then mutate that user's roles, preferences, or ticket associations in the DB.
- **Never** use `dbContext.Users.FirstAsync(u => u.Email == "integration.X@priis.se")` and modify the result.

**Instead:** create a fresh user per test inside `[AutoRollback]`, or use the fresh per-test user that helpers like `CreateFullMatchingTestDataAsync` already create (available via `testData.Operation.UserRoles[0].UserId`). To give that fresh user an additional system role:

```csharp
// Give the fresh per-operation contact person a CaseworkerIndependent role too
var contactPersonId = testData.Operation.UserRoles[0].UserId;
await ApiWebFactory.RunDbContextActionAsync(async db =>
{
    var user = await db.Users.Include(u => u.Roles).FirstAsync(u => u.Id == contactPersonId);
    user.Roles.Add(new AdministrationUserRole(contactPersonId, Role.CaseworkerIndependentId,
        Administration.Gothenburg.ForvaltningenForFunktionsstod));
    await db.SaveChangesAsync();
});
var (client, _) = ApiWebFactory.CreateClientAsUserId(contactPersonId);
```

The fresh user is unique per test and rolled back by `[AutoRollback]`, so parallel tests cannot interfere with it.

---

#### No pre-seeded domain data

`TUnitApiWebFactory` sets `SkipDemoData = true`. Contracts, operations, contract templates, subareas, suppliers, categories etc. are **not** pre-populated. Any `dbContext.Contracts.FirstAsync()` or `dbContext.Operations.FirstAsync()` that expects pre-existing rows fails with `Sequence contains no elements`.

**Rule: every test that needs domain data must create it with `[AutoRollback]`.**

| What you need                             | Helper                                                                                              |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------- |
| A complete contract with all dependencies | `dbContext.CreateTestContractAsync(ApiWebFactory.Services)`                                         |
| A contract with a specific initial status | `dbContext.CreateBasicSubareaContractForTestAsync(operation, status, subarea: subarea)` — see below |
| A contract template (with subareas)       | `dbContext.CreateBasicContractTemplateForTestAsync()`                                               |
| An active operation                       | `dbContext.Operations.Where(o => o.Status == Active).FirstAsync()` — one is always seeded           |

**To create a contract with a specific initial status**, do NOT use `CreateTestContractAsync` + `ExecuteUpdateAsync` to patch the status afterward. EF Core applies global and temporal query filters to `ExecuteUpdateAsync`, which can silently skip the update. Instead, set the status at creation time:

```csharp
var contractTemplate = await dbContext.CreateBasicContractTemplateForTestAsync();
var subarea = contractTemplate.Subareas.First();
var operation = await dbContext.Operations.Where(o => o.Status == RegisterStatus.Active).FirstAsync();
var contract = await dbContext.CreateBasicSubareaContractForTestAsync(operation, desiredStatus, subarea: subarea);
```

**List-endpoint tests** that assert `result.Items.Should().NotBeEmpty()` also need self-contained data. Add `[AutoRollback]` and create an entity before calling the endpoint. Tests that filter by demo-specific contract numbers (e.g. `SearchText = "12345"`) should be redesigned to filter by properties of the freshly created entity instead.

**Test data helper usings.** All test data extension methods (`CreateTestContractAsync`, `CreateBasicSubareaContractForTestAsync`, `CreateBasicContractTemplateForTestAsync`, `CreateBasicOperationForTestAsync`, etc.) share one namespace regardless of which file they are defined in:

```csharp
using GR.PRIIS.API.IntegrationTests.TestDataHelpers;
```

Exception: `TestDataSupplierHelper` uses `GR.PRIIS.API.IntegrationTest.Library.TestDataHelpers`.

**Always use `Administration.Gothenburg.ForvaltningenForFunktionsstod` — never `Administrations.FirstAsync()`**

Any test that needs an `AdministrationId` (for creating users with `AdministrationUserRole`, scoping tickets, etc.) must **not** call `dbContext.Administrations.FirstAsync()`. The first administration returned depends on DB insertion order, which differs between TUnit and xUnit and can cause wrong-scope failures or flaky tests. Use the stable static constant instead — it is always seeded, requires no DB roundtrip, and is the same value xUnit tests assume:

```csharp
// Wrong — seeding order differs; produces wrong scope in TUnit
var administrationId = await dbContext.Administrations.Select(a => a.Id).FirstAsync();

// Correct — stable, always present, no extra query
var administrationId = Administration.Gothenburg.ForvaltningenForFunktionsstod;

// Example: assigning role to a freshly created user
user.Roles.Add(new AdministrationUserRole(user.Id, Role.CaseworkerIndependentId, administrationId));
```

This applies everywhere: notification handler helpers, endpoint tests, any place that picks "some administration."

#### Demo users and authentication

**Named demo users don't exist** in TUnit (e.g. `hadya@priis.se`, `samir@priis.se`, `ines@priis.se`). Choose the right replacement based on what the test verifies:

| Scenario                                                                        | TUnit replacement                                                                                                                                               |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User without a specific permission → **403 Forbidden**                          | `ApiWebFactory.CreateClientAndLoginAsNoAccessUserAsync(SystemAction.X)`                                                                                         |
| User with ReadContract but scoped to another administration → **404 Not Found** | `ApiWebFactory.CreateClientAsRoleAsync(RoleType.CaseworkerGuided)` — scoped user can't see the fresh "Test Administration" created by `CreateTestContractAsync` |
| User with a specific role (happy path)                                          | `ApiWebFactory.CreateClientAsRoleAsync(RoleType.X)` — assert by returned `userId`, not email                                                                    |
| Any authenticated user (no role constraint)                                     | `ApiWebFactory.CreateClientAsUserAsync()` — test-auth header, no DB write                                                                                       |
| Real cookie login needed (e.g. tests the login flow)                            | `ApiWebFactory.CreateClientAndLoginAsync()`                                                                                                                     |
| OperationContactPerson for a test operation (e.g. `ludvig` + `EnsureOperationContactPersonRoleAsync`) | `ApiWebFactory.CreateClientAsUserId(testData.Operation.UserRoles[0].UserId)` — see below |

To find what `SystemAction` a forbidden test needs, read the endpoint's `Configure()` method and find `Policy(SystemAction.X)`.

**OperationContactPerson for a specific test operation** — `EnsureOperationContactPersonRoleAsync` on a shared immutable user (e.g. `"integration.operationcontactperson"`) causes parallel-test races and lock contention. Instead, use the fresh per-operation contact person that `CreateFullMatchingTestDataAsync` (via `CreateBasicOperationForTestAsync`) already creates. It is immediately available on the returned entity:

```csharp
// xUnit
await _apiWebFactory.EnsureOperationContactPersonRoleAsync("ludvig", testData.Operation.Id);
var (client, _) = await _apiWebFactory.CreateClientAndLoginAsync("ludvig", "Givdul_1", skipCache: true);

// TUnit — the fresh contact person is already on the entity; no DB round-trip, no shared user
var (client, _) = ApiWebFactory.CreateClientAsUserId(testData.Operation.UserRoles[0].UserId);
```

`Operation.UserRoles` is `IReadOnlyList<OperationUserRole>` (indexable) — use `[0]`, not `.First()`, to satisfy CA1826.

This pattern also applies to endpoint list tests that scope results to the caller's operation (e.g. `ListMatchingInquiriesEndpoint`): `CreateClientAsUserAsync()` uses the global default integration user who may not be an OperationContactPerson for the freshly created operation, causing the list to return 0 items. Use `CreateClientAsUserId(testData.Operation.UserRoles[0].UserId)` for these tests too.

**Role-specific demo users** — replace with `CreateClientAsRoleAsync` and drop any hardcoded email assertion:

```csharp
// xUnit
var (client, _) = await _apiWebFactory.CreateClientAndLoginAsync("amalia", "Ailama_1");
result!.Should().Contain(u => u.Email == "amalia@priis.se");

// TUnit
var (client, adminUserId) = await ApiWebFactory.CreateClientAsRoleAsync(RoleType.RegisterAdministrator);
await Assert.That(result!.Any(u => u.Id == adminUserId)).IsTrue();
```

#### Multi-role user

When a test needs one user with **two different roles** (e.g. to verify role priority), never add a second role to a shared integration user — create a fresh user with both roles:

```csharp
var userId = await ApiWebFactory.RunDbContextActionAsync(async db =>
{
    var user = new InternalUser
    {
        Email = $"multirole.{Guid.NewGuid():N}@test.local",
        PhoneNumber = "0700000000",
        EmailConfirmed = true,
        SecurityStamp = Guid.NewGuid().ToString()
    };
    user.Roles.Add(new AdministrationUserRole(user.Id, Role.PlacementManagerId, AdministrationId));
    user.Roles.Add(new AdministrationUserRole(user.Id, Role.CaseworkerIndependentId, AdministrationId));
    db.Users.Add(user);
    await db.SaveChangesAsync();
    return user.Id;
});
var (client, _) = ApiWebFactory.CreateClientAsUserId(userId);
```

---

#### Seeded user lockout

Parallel tests that make wrong-password attempts against the same seeded user can lock the account mid-suite, causing unrelated happy-path tests to fail with 400.

- **Invalid-credential tests** (just confirming 400): use a non-existent email like `"nonexistent@priis.test"` — no lockout counter is incremented.
- **Valid-credential tests** (checking cookies, AllowedActions, LastLogin): create a fresh unique user per test with `[AutoRollback]` and `skipCache: true`:

```csharp
var email = $"valid.login.{Guid.NewGuid():N}@priis.test";
const string password = "ValidLogin!123";
await ApiWebFactory.RunServiceProviderActionAsync(async sp =>
{
    var userManager = sp.GetRequiredService<PriisUserManager>();
    var user = new InternalUser { Email = email, PhoneNumber = "0700000000", EmailConfirmed = true };
    await userManager.CreateAsync(user, password);
    await userManager.AddUserRoleAsync(user, new SystemAdminUserRole(user.Id));
    return Task.CompletedTask;
});
var (client, _) = await ApiWebFactory.CreateClientAndLoginAsync(email, password, skipCache: true);
```

#### Notification handler tests

xUnit notification tests extend `NotificationHandlerIntegrationTestBase`. TUnit uses a different base with per-test email isolation:

```csharp
// xUnit (primary constructor, sync assert)
public sealed class XxxTests(ITestOutputHelper o, ApiWebFactory f)
    : NotificationHandlerIntegrationTestBase(o, f) { }

// TUnit (standard class, async assert)
internal sealed class XxxTests : NotificationHandlerTUnitIntegrationTestBase { }
```

Change `AssertNotificationChannelCalls(...)` → `await AssertNotificationChannelCallsAsync(...)`.


#### Email mock access

`BaseTUnitIntegrationTests` exposes `EmailClientMock` (NSubstitute `IEmailClient`, isolated per test via `PerTestEmailClientRegistry`). The xUnit equivalent was `_apiWebFactory.Services.GetRequiredService<IEmailClient>()`.

```csharp
var emailClientMock = EmailClientMock;
emailClientMock
    .SendEmailAsync(Arg.Any<string>(), Arg.Any<string>(), Arg.Do<string>(html => capturedHtml = html), Arg.Any<CancellationToken>())
    .Returns(Task.FromResult(SystemResult.Success));
```

---

## Step 4: Write the New Files

Create each file at `tests/GR.PRIIS.API.IntegrationTests.TUnit/{arg}/{OriginalFilename}`.

**Namespace:** `GR.PRIIS.API.IntegrationTests.{Ns}` → `GR.PRIIS.API.IntegrationTests.TUnit.{Ns}`

**Global usings** already provided by `Usings.cs` (no need to add):

- `TUnit.Assertions`, `TUnit.Core`
- `GR.PRIIS.API.IntegrationTests.Extensions` (HttpClient helpers)
- `AutoRollback` alias

Add only usings actually needed by the migrated code.

---

## Step 5: Delete the Source Files

After the build is clean, delete all original xUnit files:

```powershell
Remove-Item "tests/GR.PRIIS.API.IntegrationTests/{arg}/{File}.cs"
```

---

## Step 6: Build and Run

```bash
# Must be zero errors, zero warnings
dotnet build tests/GR.PRIIS.API.IntegrationTests.TUnit --configuration Release

# TUnit uses Microsoft.Testing.Platform — use dotnet run, not dotnet test
dotnet run --project tests/GR.PRIIS.API.IntegrationTests.TUnit --configuration Release --no-build
```

Report pass/fail count. Fix all failures before declaring done.

---

## Common Failure Patterns

| Symptom                                                   | Cause                                                                    | Fix                                                                                                             |
| --------------------------------------------------------- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| `NullReferenceException` in `CreateClientAndLoginAsync`   | Demo user doesn't exist in TUnit DB                                      | Replace with `CreateClientAndLoginAsNoAccessUserAsync(SystemAction.X)` or `CreateClientAsRoleAsync(RoleType.X)` |
| `Sequence contains no elements`                           | Test queries pre-seeded domain data that doesn't exist in TUnit          | Create required data with `[AutoRollback]` — see §3h                                                            |
| Endpoint returns unexpected BadRequest after status setup | `ExecuteUpdateAsync` silently skipped by EF Core query/temporal filter   | Create entity with the correct initial status — see §3h                                                         |
| `IsEqualTo` passes on same content but wrong reference    | `IsEqualTo` on `List<T>` is reference equality                           | Use `actual.SequenceEqual(expected)`                                                                            |
| Seeded user login returns 400 unexpectedly                | Account locked by parallel wrong-password test                           | Use non-existent email for bad-credential tests; fresh user for success tests                                   |
| `InvalidOperationException: The logger is already frozen` | Concurrent `WithWebHostBuilder().CreateClient()` calls                   | Wrap in a shared `SemaphoreSlim(1, 1)` — see §3g                                                                |
| `[AutoRollback]` on class causes interference             | Class-level executor conflicts with parallelism                          | Move to method level only                                                                                       |
| Zero tests run with `--treenode-filter`                   | Filter path format differs for this project                              | Run without filter; use `--list-tests` to verify discovery                                                      |
| SQL timeout on `UserLastLogins`                           | Many parallel real cookie logins cause DB lock contention                | Switch to `CreateClientAsUserAsync()` — no DB write                                                             |
| `CS1501: 'Contains' has no 2-argument overload`           | `StringComparison.Ordinal` added to `HttpResponseHeaders.Contains`       | Only apply to `string.Contains()`, not header/collection Contains                                               |
| `CS0176: cannot be accessed with an instance reference`   | Static member accessed via instance (`ApiWebFactory.TwoFactorUserEmail`) | Use type name: `TUnitApiWebFactory.TwoFactorUserEmail`                                                          |
| `DELETEAsync` — wrong status code access                  | Returns tuple `(HttpResponseMessage Response, TResponse? Result)`        | Use `response.Response.StatusCode`                                                                              |
| TUnit0046 warning                                         | Mutable reference type returned directly from data source                | Wrap in `Func<T>` in data source; call `factory()` in test                                                      |
| TUnit0301 warning                                         | Test method receives whole tuple as single parameter                     | Destructure into separate parameters                                                                            |
| CA1841 warning                                            | `dict.Values.Contains("x")` on a Dictionary                              | Use `dict.ContainsValue("x")`                                                                                   |
| CA1826 warning                                            | `.First()` on `IReadOnlyList<T>` (indexable)                             | Use `[0]` instead — e.g. `testData.Operation.UserRoles[0].UserId`                                               |
| Endpoint scoped to operation returns 0 items or 404      | `CreateClientAsUserAsync()` default user is not an OCP for the test operation | Use `ApiWebFactory.CreateClientAsUserId(testData.Operation.UserRoles[0].UserId)` |
| Flaky failures in unrelated tests                        | Test mutated a shared immutable integration user (added role, changed preference) | Never modify immutable seeded users — see §3h warning at top |
| Test user has wrong administration scope / unexpected 404 or scoping failure | `dbContext.Administrations.FirstAsync()` returns a different administration than xUnit seeded | Use `Administration.Gothenburg.ForvaltningenForFunktionsstod` everywhere — see §3h |
| `Sequence contains no elements` in `CreateBasicOperationForTestAsync` with `withPermitOutOfAgeRange = true` | `StoredFiles` table is empty in TUnit (demo data skipped) | Already fixed in `TestDataOperationHelper` — uses `FirstOrDefaultAsync() ?? AddPlaceholderStoredFile(db)` |
| Build warning: `string.IsNullOrWhiteSpace(x).IsFalse()` in migrated file | Verbose anti-pattern — was the old mapping before TUnit string assertions were documented | Replace with `await Assert.That(x).IsNotEmpty()` — see §3e |

---

## Checklist Before Declaring Done

- [ ] All source xUnit files deleted
- [ ] Build: zero errors, zero warnings
- [ ] Test run: all migrated tests green; total count = prior count + new tests
- [ ] Test names follow `{Subject}_{Scenario}_{ExpectedOutcome}` — no `Should_`, no verbatim xUnit names
- [ ] No demo-data users (`hadya@priis.se` etc.) — replaced per §3h
- [ ] No reliance on pre-seeded domain data — every test creates its own with `[AutoRollback]`
- [ ] No FluentAssertions `.Should()` calls remaining
- [ ] No `string.IsNullOrEmpty/WhiteSpace(x).IsFalse()` — use `await Assert.That(x).IsNotEmpty()` instead
- [ ] `[AutoRollback]` at method level only (not class level)
- [ ] `string.Contains("literal")` calls use `StringComparison.Ordinal` — `HttpResponseHeaders.Contains` exempt
- [ ] Collections compared with `SequenceEqual`, not `IsEqualTo`
- [ ] `WithWebHostBuilder().CreateClient()` calls guarded by a shared `SemaphoreSlim` — see §3g
- [ ] Mutable data-source params wrapped in `Func<T>` to satisfy TUnit0046
- [ ] Tuple params destructured into separate method parameters to satisfy TUnit0301
- [ ] Status-setup done at entity creation time, not via `ExecuteUpdateAsync` patch
- [ ] No immutable seeded users mutated — roles, preferences, and ticket associations are only added to fresh per-test users
- [ ] OperationContactPerson tests use `testData.Operation.UserRoles[0].UserId` + `CreateClientAsUserId` — no `EnsureOperationContactPersonRoleAsync` on shared immutable users
- [ ] All `AdministrationId` lookups use `Administration.Gothenburg.ForvaltningenForFunktionsstod`, not `Administrations.FirstAsync()`
