---
name: modern-csharp
description: General C# 14 idioms and best practices — collection expressions, primary constructors, records, sealed classes, extension blocks, pattern matching, and nullable reference types. Load when writing or reviewing C# code in any C# project.
---

# Modern C# 14 Idioms and Best Practices

This skill documents the C# 14 features and conventions used in this codebase. These are not optional style preferences — they are enforced by CI (`dotnet format`) and code review.

---

## 1. Collection Expressions

Use collection expressions everywhere. The old constructors are forbidden.

```csharp
// ✅ Correct
string[] names = ["Alice", "Bob", "Charlie"];
List<Guid> ids = [id1, id2, id3];
var empty = Array.Empty<string>();      // ❌ wrong
var empty = (string[])[];              // ✅ correct: []
var merged = [..existing, newItem];    // spread operator for combining

// ❌ Forbidden
new List<string>()
new string[] { "a", "b" }
new[] { "a", "b" }
Array.Empty<string>()
Enumerable.Empty<int>()
```

In properties and method returns:

```csharp
protected static SystemAction[] SystemActions { get; private set; } = [];   // ✅

public IReadOnlyList<string> GetNames() => [.. _names.Select(n => n.ToUpper())];  // ✅
```

---

## 2. Primary Constructors for Dependency Injection

All FastEndpoints endpoints and services use primary constructors for DI. No field declarations needed — the parameters are captured automatically.

```csharp
// ✅ Correct — primary constructor with DI
public sealed class CreateFooEndpoint(
    PriisDbContext dbContext,
    ICurrentUser currentUser,
    FusionCache fusionCache)
    : ExtendedEndpoint<CreateFooRequest, CreateFooResponse>
{
    public override async Task HandleAsync(CreateFooRequest req, CancellationToken ct)
    {
        // dbContext, currentUser, fusionCache available directly — no this.field needed
        var result = await Foo.CreateAsync(req, dbContext, currentUser);
        await SendAndSaveChangesAsync(result, dbContext, ct);
    }
}

// ❌ Old pattern — do not write this
public sealed class CreateFooEndpoint : ExtendedEndpoint<CreateFooRequest, CreateFooResponse>
{
    private readonly PriisDbContext _dbContext;
    private readonly ICurrentUser _currentUser;

    public CreateFooEndpoint(PriisDbContext dbContext, ICurrentUser currentUser)
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
public sealed class CreateFooEndpoint(...) : ExtendedEndpoint<...> { }
public sealed class CreateFooRequestValidator : Validator<CreateFooRequest> { }
public sealed class FooCreatedEventHandler : INotificationHandler<FooCreated> { }

// ✅ Break the seal only for deliberate base classes:
public abstract class BaseUserEndpoint<TRequest>(...) : ExtendedEndpoint<TRequest, UserResponse> { }
public sealed class CreateInternalUserEndpoint(...) : BaseUserEndpoint<CreateInternalUserRequest> { }
```

Marking a class `sealed` enables JIT devirtualization and signals intent to future readers.

---

## 5. C# 14 Extension Blocks

C# 14 introduces extension blocks as a replacement for static extension method classes. This codebase uses them for domain type extensions.

```csharp
// ✅ C# 14 extension block syntax
extension(OperationStatus status)
{
    public string ToDisplayString() => status switch
    {
        OperationStatus.Active   => "Aktiv",
        OperationStatus.Inactive => "Inaktiv",
        OperationStatus.Pending  => "Väntande",
        _                        => status.ToString()
    };

    public bool IsTerminal() => status is OperationStatus.Closed or OperationStatus.Cancelled;
}

// ❌ Old C# static extension class syntax (avoid for new extension methods)
public static class OperationStatusExtensions
{
    public static string ToDisplayString(this OperationStatus status) => ...;
}
```

Extension blocks replace the `public static class FooExtensions` pattern. When adding new extension methods to domain types, use extension blocks.

---

## 6. Raw String Literals

Use raw string literals for multi-line content — email templates, SQL, JSON, long strings. No escape sequences needed.

```csharp
// ✅ Raw string literal (""" ... """)
var emailBody = """
    Hej {Name},

    Ditt ärende #{CaseNumber} har registrerats.

    Med vänliga hälsningar,
    PRIIS
    """;

// ✅ Raw string with interpolation ($""" ... """)
var query = $"""
    SELECT Id, Name
    FROM Operations
    WHERE SupplierId = '{supplierId}'
      AND Status = 'Active'
    """;

// ❌ Old string concatenation
var body = "Hej " + name + ",\r\n\r\nDitt ärende #" + caseNumber + " har registrerats.";
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
// ✅ Source-generated regex (as used in IRuleBuilderExtensions.cs)
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

## Quick Reference: Forbidden → Preferred

| Forbidden | Preferred |
|-----------|-----------|
| `new List<T>()` | `[]` |
| `new T[] { a, b }` | `[a, b]` |
| `Array.Empty<T>()` | `[]` |
| `Enumerable.Empty<T>()` | `(IEnumerable<T>)[]` |
| `this._field = param` in constructor | Primary constructor capture |
| `static class FooExtensions { public static ... this Foo }` | `extension(Foo foo) { ... }` |
| `new Regex(pattern)` static field | `[GeneratedRegex] partial` method |
| `throw new ArgumentException(...)` for expected failures | `return SystemResult.Failure(...)` |
| `var act = async () => ...` | `async Task Act() { ... }` (PascalCase local function) |
