---
name: priis-backend-dry
description: "[Project: GR.PRIIS] DRY (Don't Repeat Yourself) patterns for the GR.PRIIS backend (`backend/`) — identifying and eliminating duplication across endpoints, domain methods, validators, queries, and tests. Load when refactoring, scaffolding new features, or reviewing code for repeated logic. Load ONLY when working in the GR.PRIIS repository or the GR folder that holds it."
---

# DRY Patterns — Project Conventions

This skill describes how to avoid repeating yourself in the GR.PRIIS backend (`backend/`) across the API, Library, and test layers. **Every pattern here maps to code that already exists in this repo.** When in doubt, grep for the referenced symbols before writing new code.

---

## Quick-Reference Decision Tree

```text
Writing validation?                  → use *Rules() extensions or shared AbstractValidators
Writing a domain mutation?           → put logic in entity method / Library static; endpoint stays thin
Returning the same shape?            → extract a static Expression<Func<T,TDto>> or shared query method
Projecting an entity hierarchy?      → use .HierarchySelect() + .IfTypeThenSelect<TDerived>()
Translating an enum?                 → annotate members with [Display(Name = "…")] and call .GetDisplayName()
Building an Excel sheet?             → use WriteTitle() / WriteMetadataRow() + ClosedXML InsertTable() + FormatTable()
Joining ChangedBy user to a list?    → use .LeftJoin(dbContext.Users) — NOT a HashSet loop
Collecting ChangedBy users (export)? → follow the AddChangedByIds + temporal fallback exemplar (ExportRegisterEndpoint.cs:413)
Writing a test?                      → use ApiWebFactory factory methods; extract private arrange helpers
Chaining SystemResult?               → use .Then() / .ThenAsync() — never repeat if (!result.IsSuccess)
Filtering scoped by access rules?    → use .ApplyAccessRules() / .ApplyAccessRulesOr()
Paginating a list?                   → use .ToPaginatedListAsync() — never manual Skip/Take + CountAsync
Searching across text fields?        → use req.Search.BuildTokenizedPredicate<T>(1, x => x.Field, ...)
```

---

## Pattern Reference Index

Consult the dedicated reference catalogs behind context pointers:

### 1. [Endpoint & Validation Patterns](references/endpoint-and-validation-patterns.md)
- **1. Shared Validators — `*Rules()` Extension Methods**: Reuse FluentValidation rules across create/update commands.
- **2. `ExtendedEndpoint` Hierarchy**: Standardized endpoints with built-in auth, validation, and error translation.
- **3. `SystemResult` Chaining — `.Then()` / `.ThenAsync()`**: Functional error handling and pipeline flows.
- **4. Shared Access Rule Filtering — `ApplyAccessRules()`**: Consistent permission filtering on `IQueryable`.

### 2. [Query & Projection Patterns](references/query-and-projection-patterns.md)
- **5. Shared Read Projections — Static `Expression<Func<T,TDto>>`**: Avoid duplicating `.Select()` projections.
- **6. Joining ChangedBy User to List Queries — `UserExtensions.LeftJoin()`**: Standard audit user joining (plus `6a` temporal fallback exemplar in `backend/source/GR.PRIIS.API/Features/Reports/Register/ExportRegisterEndpoint.cs:413`).
- **7. Shared Static Expression Properties on Entities**: Reusable query filters on entities.
- **8. Shared Pagination — `ToPaginatedListAsync()`**: Centralized page calculation and count queries.
- **9. Tokenized Full-Text Search — `BuildTokenizedPredicate()`**: Multi-term search queries.
- **10. Hierarchy Projections — `HierarchySelect()` + `IfTypeThenSelect()`**: Type-safe polymorphic hierarchy mapping.

### 3. [Domain Helpers, Testing & Anti-Patterns](references/domain-helpers-and-testing.md)
- **11. Shared Library Factory / Domain Methods**: Domain logic encapsulation in Library entities.
- **12. Shared Test Factory Methods**: Common builder methods for integration and unit test setups.
- **13. Shared Enum-to-String Translation — `[Display]` + `GetDisplayName()`**: Swedish UI/export display values for enums via `EnumMetadataCache.GetDisplayName()`.
- **14. Shared Excel Worksheet Helpers — `WorksheetExtensions` (`WriteTitle`, `WriteMetadataRow`, `FormatTable`)**: Standard report header and table formatting.
- **15. Mixed Existing/New Entity Collections — `ExistingOrNewEntities<T>`**: Syncing relation collections.
- **16. Anti-Patterns Checklist**: Key pitfalls to avoid in backend code.
