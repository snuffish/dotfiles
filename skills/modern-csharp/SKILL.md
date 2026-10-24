---
name: modern-csharp
description: "General C# 14 idioms and best practices — collection expressions, primary constructors, records, sealed classes, extension blocks, pattern matching, nullable reference types, and comment/XML-doc conventions. Load when writing or reviewing C# code in any C# project."
---

# Modern C# 14 Idioms and Best Practices

General C# 14 idioms for any C# project. A workspace rulebook or project-scoped Reference that says otherwise wins (`core` › *Precedence*). Where a project enforces these with `dotnet format` or an analyzer, its configuration is the final word.

---

## 1. Collection Expressions

Prefer collection expressions over the old constructors: one syntax for every collection type, and the compiler picks the most efficient construction for the target.

```csharp
// ✅ Correct
string[] names = ["Alice", "Bob", "Charlie"];
List<Guid> ids = [id1, id2, id3];
string[] empty = [];                           // not Array.Empty<string>()
List<string> merged = [..existing, newItem];   // spread operator for combining

// ❌ Avoid
new List<string>()
new string[] { "a", "b" }
new[] { "a", "b" }
Array.Empty<string>()
Enumerable.Empty<int>()
```

A collection expression has no natural type, so it needs a target type: `var merged = [..existing, newItem];` does not compile (CS9176). Declare the type on the left, or use it where a parameter, property or return type supplies one.

In properties and method returns:

```csharp
protected static Permission[] RequiredPermissions { get; private set; } = [];   // ✅

public IReadOnlyList<string> GetNames() => [.. _names.Select(n => n.ToUpper())];  // ✅
```

---

## 2. Primary Constructors for Dependency Injection

Endpoints, handlers and services take their dependencies through a primary constructor. No field declarations are needed; the parameters are captured automatically. (The examples use FastEndpoints; the rule is the same for controllers and minimal-API handlers.)

```csharp
// ✅ Correct — primary constructor with DI
public sealed class CreateFooEndpoint(
    AppDbContext dbContext,
    ICurrentUser currentUser,
    IMemoryCache cache)
    : Endpoint<CreateFooRequest, CreateFooResponse>
{
    public override async Task HandleAsync(CreateFooRequest req, CancellationToken ct)
    {
        // dbContext, currentUser, cache available directly — no this.field needed
        var result = await Foo.CreateAsync(req, dbContext, currentUser);
        await dbContext.SaveChangesAsync(ct);
        await Send.OkAsync(result, ct);
    }
}

// ❌ Old pattern — do not write this
public sealed class CreateFooEndpoint : Endpoint<CreateFooRequest, CreateFooResponse>
{
    private readonly AppDbContext _dbContext;
    private readonly ICurrentUser _currentUser;

    public CreateFooEndpoint(AppDbContext dbContext, ICurrentUser currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }
}
```

**Subtlety:** Primary constructor parameters are captured by lambdas and closures. If you assign a parameter to a field to prevent capture in lambdas (a performance concern), document why.

---

## 3. Records

Records provide value equality and immutable DTOs.

```csharp
// Positional records — for request DTOs (compact, works with FastEndpoints binding)
public sealed record CreateFooRequest(Guid ParentId, string Name, string? Description = null);

// Nominal records with required init — for response DTOs
public sealed record FooDto
{
    public required Guid Id { get; init; }
    public required string Name { get; init; }
    public string? Description { get; init; }
}

// Nominal with required init — for EF Select projections
var dto = new FooDto { Id = f.Id, Name = f.Name };
```

**Do NOT use records for:**

- EF Core entities (EF needs mutable tracked objects with `private set` for state changes)
- Domain objects that have command methods (`SetStatus()`, etc.)
- Objects with complex equality semantics

---

## 4. `sealed` by Default

All concrete classes should be `sealed` unless inheritance is deliberately designed:

```csharp
// ✅ Always seal these:
public sealed class CreateFooEndpoint(...) : Endpoint<...> { }
public sealed class CreateFooRequestValidator : Validator<CreateFooRequest> { }
public sealed class FooCreatedEventHandler : INotificationHandler<FooCreated> { }

// ✅ Break the seal only for deliberate base classes:
public abstract class BaseUserEndpoint<TRequest>(...) : Endpoint<TRequest, UserResponse> { }
public sealed class CreateInternalUserEndpoint(...) : BaseUserEndpoint<CreateInternalUserRequest> { }
```

Marking a class `sealed` enables JIT devirtualization and signals intent to future readers.

---

## 5. C# 14 Extension Blocks

C# 14 adds extension blocks: `extension(<receiver>) { … }` declares extension members for that receiver. A block lives **inside** a top-level, non-generic `static class`, just like `this`-parameter extension methods. A block at namespace or file level does not compile (CS9283).

```csharp
// ✅ Prefer for new extension members
public static class OperationStatusExtensions
{
    extension(OperationStatus status)
    {
        public string ToDisplayString() => status switch
        {
            OperationStatus.Active   => "Active",
            OperationStatus.Inactive => "Inactive",
            OperationStatus.Pending  => "Pending",
            _                        => status.ToString()
        };

        public bool IsTerminal() => status is OperationStatus.Closed or OperationStatus.Cancelled;
    }

    // Still valid: the classic form compiles to the same IL and can sit in the same class
    public static string ToShortCode(this OperationStatus status) => status.ToString()[..1];
}
```

Use blocks for new extension members: they group the members of one receiver, and they also allow extension properties and static extension members. The `this`-parameter form is not deprecated. The two are binary- and source-compatible, so existing methods need no conversion.

---

## 6. Raw String Literals

Use raw string literals for multi-line content — email templates, SQL, JSON, long strings. No escape sequences needed.

```csharp
// ✅ Raw string literal (""" ... """)
var emailBody = """
    Hi {Name},

    Your case #{CaseNumber} has been registered.

    Kind regards,
    The Support Team
    """;

// ✅ Raw string with interpolation ($""" ... """)
var greeting = $"""
    Hi {name},

    Your case #{caseNumber} has been registered.
    """;

// ❌ Old string concatenation
var body = "Hi " + name + ",\r\n\r\nYour case #" + caseNumber + " has been registered.";
```

**SQL is the exception: never interpolate values into SQL text.** A string built beforehand can only reach `FromSqlRaw` / `SqlQueryRaw` / `ExecuteSqlRaw`, which send the value verbatim, so this is SQL injection. Pass the interpolated raw string straight to `FromSql` (or `SqlQuery` / `ExecuteSql`) instead. It takes a `FormattableString` and turns every `{value}` into a `DbParameter`, so the placeholder gets no quotes:

```csharp
// ❌ Injectable: the value is pasted into the SQL text
var sql = $"""SELECT Id, Name FROM Operations WHERE SupplierId = '{supplierId}'""";
var rows = dbContext.Operations.FromSqlRaw(sql);

// ✅ Parameterised: {supplierId} becomes @p0
var rows = dbContext.Operations.FromSql($"""
    SELECT Id, Name
    FROM Operations
    WHERE SupplierId = {supplierId}
      AND Status = 'Active'
    """);
```

---

## 7. Pattern Matching in Switch Expressions

Prefer switch expressions over switch statements for mapping/transforming:

```csharp
// ✅ Switch expression for enum → expression mapping
public override Expression<Func<OperationListItem, object?>> GetOrderByExpression(OperationOrderBy orderBy)
    => orderBy switch
    {
        OperationOrderBy.Name        => x => x.Name,
        OperationOrderBy.SupplierName => x => x.SupplierName,
        OperationOrderBy.Status      => x => x.Status,
        _                            => x => x.Id
    };

// ✅ Type patterns
public static string Describe(object obj) => obj switch
{
    OperationNote note    => $"Note: {note.Content}",
    OperationContact c    => $"Contact: {c.Name}",
    null                  => "empty",
    _                     => obj.ToString() ?? ""
};
```

---

## 8. `required` + `init`

For DTO/record properties that must be set at object creation but should not change:

```csharp
// ✅ required + init — must be set in object initializer, immutable after
public sealed record OperationDto
{
    public required Guid Id { get; init; }
    public required string Name { get; init; }
    public string? Description { get; init; }    // optional — no required
}

// EF projection
var dto = new OperationDto { Id = o.Id, Name = o.Name };

// ✅ Entity properties that shouldn't be reassigned externally
public sealed class OperationNote : AuditableEntity
{
    public Guid Id { get; init; } = Guid.NewGuid();   // set once at creation
    public string Content { get; private set; } = "";  // mutable via command method
}
```

---

## 9. Nullable Reference Types

The project is NRT-enabled (`<Nullable>enable</Nullable>`). Treat compiler warnings as errors.

```csharp
// ✅ Correct NRT usage
public string? Description { get; init; }             // nullable — may be absent
public string Name { get; init; } = "";               // non-nullable — always present

// Use ? for optional method returns
public async Task<FooDto?> FindByIdAsync(Guid id, CancellationToken ct)
    => await dbContext.Foos.AsNoTracking()
        .Where(f => f.Id == id)
        .Select(f => new FooDto { ... })
        .FirstOrDefaultAsync(ct);

// ❌ Avoid null-forgiving unless you've proved it safe
var name = dto!.Name;      // only if you know dto cannot be null here
var item = list.First()!;  // use FirstOrDefault + null check instead

// ❌ Avoid default! as an escape hatch
public string Name { get; set; } = default!;  // use = "" or make it nullable
```

---

## 10. `[GeneratedRegex]`

Use source-generated regex for static patterns — compile-time validation and zero allocation at runtime.

```csharp
// ✅ Source-generated regex
[GeneratedRegex(@"^\+?[0-9\s\-\(\)]{7,20}$")]
private static partial Regex PhonePattern();

// Used in validation:
RuleFor(x => x.Phone)
    .Must(p => PhonePattern().IsMatch(p))
    .WithMessage("Ogiltigt telefonnummer.");

// ❌ Instance-constructed regex (avoid for static patterns)
private static readonly Regex PhonePattern = new(@"^\+?[0-9\s\-\(\)]{7,20}$");
```

## 11. Local Functions over Anonymous Lambdas (IDE0039)

When defining a delegate variable (e.g., for passing to an assertion in testing or for scoped helper execution), use a C# local function instead of assigning an anonymous lambda to a variable.

**PascalCase Naming Rule**: Local functions are treated as methods and **MUST** start with an uppercase letter (PascalCase), not camelCase.

```csharp
// ✅ Correct (Local Function - PascalCase)
async Task Act()
{
    await service.ExecuteAsync();
}
var ex = await Assert.That(Act).Throws<Exception>();

// ❌ Forbidden (Anonymous Lambda or camelCase Local Function)
var act = async () => await service.ExecuteAsync();
async Task act() { await service.ExecuteAsync(); }
```

---

## 12. Comments and XML Documentation

Write a comment only to state something the code cannot show on its own — a non-obvious constraint, an invariant, or the reason a surprising choice is necessary. A `<summary>` states what a type or member is *responsible for*, in the present tense, written **from scratch for the code as it is now** — not how it got here.

```csharp
// ❌ History, incident narrative, and "why my change is correct" — noise the moment it merges
/// The Linux container must provide libfontconfig1 for the native renderer to load (see Dockerfile).
/// Registering the embedded font fixed the CI crash.
// Changed from PNG to SVG in PR #123.
// Mirrors the access-check pattern in GetFooProfileEndpoint; stricter than the Excel export's query.

// ✅ States the current responsibility / a real constraint
/// Builds the display-ready model for the "Matchningsdokumentation" PDF: verifies access,
/// resolves the chosen selection, and projects it into locale-formatted values.
// Access check runs WITHOUT IgnoreQueryFilters so the CategoryProtection global filter still applies.
```

- **Describe the code's own job, not its relationship to sibling code.** "Mirrors X", "stricter than Y", "same as the Z export" is archaeology that rots the moment the other side changes. Shared patterns are fine — just say what *this* type does.
- **No history, changelog, or PR/CI references in comments.** Git and the PR already carry that. A comment describing *what changed* or *why the fix works* is written for the reviewer, not the next reader.
- **Keep docs true to current behavior.** When you change what the code needs or does, update or delete the affected comment in the *same* edit — a stale doc (e.g. "requires libfontconfig1" after the dependency is gone) is worse than none.
- **Prefer plain over clever.** Generic, conventional phrasing beats a war-story; the reader should learn the responsibility, not the debugging session that produced it.
- **Slim by default.** One or two sentences for a member, a short paragraph for a type. A `<remarks>` block running past a few lines is a sign the explanation belongs in the PR description or an ADR, not the source.
- **Never address the reader.** A doc is not a note to the user or the reviewer. No arguing a choice ("that costs twice", "the one thing X cannot be without"), no rhetorical framing, no listing the alternatives that were rejected. State the constraint in a clause and stop.
- **Do comment genuine surprises.** A constraint the compiler can't express — ordering that matters, a filter that must run, a culture that must be invariant, a magic value's meaning — is exactly what a comment is for.

---

## Quick Reference: Avoid → Prefer

| Avoid | Prefer |
|-----------|-----------|
| `new List<T>()` | `[]` |
| `new T[] { a, b }` | `[a, b]` |
| `Array.Empty<T>()` | `[]` |
| `Enumerable.Empty<T>()` | `(IEnumerable<T>)[]` |
| `this._field = param` in constructor | Primary constructor capture |
| A new `public static … (this Foo foo)` extension method | An `extension(Foo foo) { … }` block in the same static class (existing `this` methods can stay) |
| `new Regex(pattern)` static field | `[GeneratedRegex] partial` method |
| `throw new ArgumentException(...)` for expected failures | Return the project's result type (e.g. `Result.Failure(...)`) |
| `var act = async () => ...` | `async Task Act() { ... }` (PascalCase local function) |
| `// mirrors X / same as the Y export` (cross-ref archaeology) | State what *this* type does |
| `// fixed CI / changed in PR #n` (history in a comment) | Leave history to git/PR; document current behavior |
| Multi-paragraph `<remarks>` arguing why an approach was chosen | One clause naming the constraint; the rest goes in the PR |
| Doc written as a message to the reader/reviewer | Doc written about the code, for the next reader |
| Stale doc left behind after behavior changed | Update or delete it in the same edit |
