---
name: implement-feature
description: "Orchestrator skill for implementing a new feature end-to-end in the PRIIS workspace — research, planning, scaffolding, coding, verification, and shipping. Load when the user asks to implement a feature, work item, or user story."
---

# /implement-feature — End-to-End Feature Implementation

This skill orchestrates the complete lifecycle of a feature implementation in the `priis.se` workspace. Execute every phase in order. Do not skip a phase.

> [!IMPORTANT]
> **No Automatic Pull Requests / Code Shipping:** Never push branches (`git push`) or create Pull Requests (`az repos pr create`) automatically without explicit user approval. Always present your staged files, branch names, commit messages, and PR descriptions to the user in the chat for review first, and await explicit approval before shipping.

---

## Phase 0 — Identify Scope

Before anything else, determine:

1. **Target project(s):** Backend only (`GR.PRIIS.Backend`), Frontend only (`GR.PRIIS.Frontend`), or both.
2. **Work item type:** User Story, Task, or Bug — and the implementing **Task or Bug** ID (not the parent story).
3. **Affected domains:** Which feature folder(s) are involved (e.g. `Operations`, `Matching`, `RegisterTickets`).

If the user provided a work item ID, fetch it now using the CLI:

```bash
az boards work-item show --id <ID> --org https://grutbildning.visualstudio.com --output json
```

Read the full title and description from the output to sharpen your understanding before planning.

If the work item's `System.AssignedTo` field is unassigned (null or missing in the JSON), assign the ticket to yourself (the logged-in Azure user) using the CLI:

```bash
az boards work-item update --id <ID> --assigned-to "$(az account show --query user.name -o tsv)" --org https://grutbildning.visualstudio.com
```

> **Rule:** Always use `az boards` / `az repos` CLI for all ADO operations (work items, PRs, queries). Never open the browser for work item lookups unless the content is only available via UI (e.g. attachments, screenshots).

---

## Phase 1 — Research

**Read all relevant context before writing a single line of code.**

### 1a. Load Pattern Skills

Based on scope, load and internalize these skills in full:

| Scope | Skills to load |
|-------|---------------|
| Backend — new endpoint | `backend-fastendpoints`, `backend-ef-core`, `modern-csharp` |
| Backend — new background job | `backend-ef-core`, `backend-notifications`, `modern-csharp` |
| Backend — tests only | `backend-testing` |
| Backend — refactor | `backend-dry`, `backend-ef-core`, `modern-csharp` |
| Frontend — new feature | `frontend-component-patterns`, `frontend-forms`, `frontend-rtk-query`, `frontend-routing` |
| Frontend — tests only | `frontend-testing` |
| Either — shipping | `backend-workflow` or `frontend-workflow` |

### 1b. Read Existing Domain Code

Navigate to the domain folder(s) and read:

- Existing endpoints in the same feature domain (understand naming, folder structure, request/response shapes)
- The relevant EF entity file(s) to understand the data model
- An existing similar test file to see the established test patterns

### 1c. Check for Cross-Cutting Concerns

| Concern | Where to check |
|---------|---------------|
| New `SystemAction` needed? | `source/GR.PRIIS.Library/Common/Users/AccessRules/UserRoleAccessRules.cs` + `SystemActionTexts.cs` |
| New EF migration needed? | Confirm entity changes; plan migration step |
| SignalR/realtime needed? | Load `backend-signalr` skill |
| Notifications needed? | Load `backend-notifications` skill |
| Breaking API change? | Flag it — frontend must be updated in the same PR or a coordinated pair |

---

## Phase 2 — Implementation Plan

Create or update `implementation_plan.md` in the artifact brain directory.

The plan must include:

```markdown
# [Feature Name]

## Summary
One paragraph describing what will change and why.

## User Review Required
[Document any breaking changes, migration steps, or irreversible decisions using > [!WARNING] alerts]

## Open Questions
[Any clarifying questions that would change the implementation]

## Proposed Changes

### Backend
#### [NEW/MODIFY/DELETE] <filename>
Explain what changes and why.

### Frontend
#### [NEW/MODIFY/DELETE] <filename>
Explain what changes and why.

## Verification Plan
- Commands to run
- Manual steps if applicable
```

Set `request_feedback: true`, `user_facing: true` on the artifact.

**STOP. Do not write any code until the user explicitly approves the plan.**

---

## Phase 3 — Task Checklist

Once approved, create `task.md` in the artifact brain directory. Break work into component-level items:

```markdown
- [ ] Implement Backend
  - [ ] Add SystemAction enum value (if needed)
  - [ ] Scaffold endpoint + validator
  - [ ] Implement library factory method
  - [ ] Write TUnit integration tests
  - [ ] EF Core migration (if needed)
- [ ] Implement Frontend
  - [ ] RTK Query endpoint builder + tags
  - [ ] Form schema (zod/v4)
  - [ ] Component
  - [ ] Route file (if new page)
  - [ ] Playwright test IDs
- [ ] Verification & Formatting (Run post-initial implementation)
  - [ ] dotnet format
  - [ ] dotnet build --configuration Release
  - [ ] dotnet test --configuration Release
  - [ ] organize-imports + lint + build
```

Mark items `[/]` as you start, `[x]` when done.

---

## Phase 4 — Backend Implementation

> Read `backend-fastendpoints`, `backend-ef-core`, `modern-csharp`, and `backend-testing` skills first if not already done.

### 4a. SystemAction (if new permission needed)

Add to **both** sync points before writing the endpoint:

```csharp
// 1. UserRoleAccessRules.cs — add to allowed actions for the correct role(s)
public static readonly SystemAction[] RegisterAdministratorActions =
[
    ...,
    SystemAction.CreateOperationNote,   // ← new
];

// 2. SystemActionTexts.cs — Swedish display name
[SystemAction.CreateOperationNote] = "Skapa driftnotering",
```

After adding, run `/verify` phase 6 (SystemAction Sync) mentally to confirm frontend `systemAction.ts` also needs updating.

### 4b. Endpoint

Always derive from `ExtendedEndpoint` (never FastEndpoints base types directly):

```csharp
// source/GR.PRIIS.API/Features/{Domain}/{Verb}{Feature}Endpoint.cs
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
        Summary(s => s.Summary = "Skapa en notering på en verksamhet");
    }

    public override async Task HandleAsync(CreateOperationNoteRequest req, CancellationToken ct)
    {
        var result = await OperationNote.CreateAsync(req, dbContext, currentUser, ct);
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

**Endpoint variant selection:**

| Situation | Base class |
|-----------|-----------|
| POST/PUT with request body + response | `ExtendedEndpoint<TReq, TRes>` |
| DELETE / no-content mutation | `ExtendedEndpoint<TReq>` |
| GET with no route params | `ExtendedEndpointWithoutRequest<TRes>` |
| DELETE with no body, no response | `ExtendedEndpointWithoutRequest` |

### 4c. Library Method

Use `IReadOnlyPriisDbContext` for reads, `PriisDbContext` only in the endpoint layer:

```csharp
// source/GR.PRIIS.Library/Features/{Domain}/{Entity}.cs
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

    // 2. Domain checks (Swedish error messages)
    var operationExists = await dbContext.Operations
        .AsNoTracking()
        .AnyAsync(o => o.Id == req.OperationId, ct);
    if (!operationExists)
        return SystemResult.Failure(nameof(req.OperationId), "Verksamheten finns inte.");

    // 3. Happy path — implicit conversion to SystemResult<T>
    return new OperationNote { OperationId = req.OperationId, Content = req.Content };
}
```

**Key rules:**

- Return `SystemResult.Failure(...)` — never `throw` for expected domain failures
- Swedish error messages
- `ChangedBy`/`ChangedOnUTC` are set by the EF interceptor — never set them manually
- Bulk updates: use `ExecuteUpdateAsync(setters, currentUser, ct)` overload
- Collections: `[]` not `new List<T>()`

### 4d. EF Core Migration (if entity changes)

```bash
cd GR.PRIIS.Backend/source/GR.PRIIS.API
dotnet ef migrations add <MigrationName> --project ../GR.PRIIS.Library -- --migrate
```

Review the generated migration file before committing. Never apply migrations in tests — `TUnitApiWebFactory` handles migration application automatically.

### 4e. TUnit Integration Tests

Minimum 3 tests per endpoint. **Never skip the auth tests.**

```csharp
// tests/GR.PRIIS.API.IntegrationTests.TUnit/{Domain}/{Verb}{Feature}EndpointTests.cs
internal sealed class CreateOperationNoteEndpointTests : BaseTUnitIntegrationTests
{
    [Test]
    public async Task CreateOperationNote_NoCookie_ReturnsUnauthorized()
    {
        var (response, result) = await ApiWebFactory
            .CreateClient()
            .POSTAsync<CreateOperationNoteEndpoint, CreateOperationNoteRequest, CreateOperationNoteResponse>(
                new CreateOperationNoteRequest(Guid.NewGuid(), "Content"));

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
                new CreateOperationNoteRequest(Guid.NewGuid(), "Content"));

        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.Forbidden);
        await Assert.That(result).IsNull();
    }

    [Test, AutoRollback]
    public async Task CreateOperationNote_ValidRequest_ReturnsCreated()
    {
        var operationId = await ApiWebFactory.RunDbContextActionAsync(async db =>
        {
            var op = db.Operations.AsNoTracking().First();
            return op.Id;
        });

        var (client, _) = await ApiWebFactory.CreateClientAsUserAsync();
        var (response, result) = await client
            .POSTAsync<CreateOperationNoteEndpoint, CreateOperationNoteRequest, CreateOperationNoteResponse>(
                new CreateOperationNoteRequest(operationId, "Test content"));

        await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.Created);
        await Assert.That(result).IsNotNull();
        await Assert.That(result!.Id).IsNotEqualTo(Guid.Empty);
    }
}
```

**TUnit assertion syntax:** `await Assert.That(actual).IsEqualTo(expected)` — never `Assert.Equal` or `.Should()`.
**Filter syntax for TUnit:** `--treenode-filter "/*/*/ClassName/*"` — never `--filter "FullyQualifiedName~..."` (VSTest syntax, silently runs 0 tests).

---

## Phase 5 — Frontend Implementation

> Read `frontend-component-patterns`, `frontend-forms`, `frontend-rtk-query`, and `frontend-routing` skills first if not already done.

### 5a. RTK Query Endpoint Builder

**Location:** `source/priis-web/src/store/api/endpoint-builders/{domain}/index.ts`

```typescript
// Query (GET)
export const listOperationNotes = (builder: Builder) =>
    builder.query<ListOperationNotesResponse, { operationId: string }>({
        query: ({ operationId }) => ({ method: 'get', url: `operations/${operationId}/notes` }),
        providesTags: (_result, _error, { operationId }) => [
            { type: Tags.operations.notes, id: operationId },
        ],
    });

// Mutation (POST/PUT/DELETE)
export const createOperationNote = (builder: Builder) =>
    builder.mutation<{ id: string }, { operationId: string; content: string }>({
        query: ({ operationId, content }) => ({
            method: 'post',
            url: `operations/${operationId}/notes`,
            body: { content },
        }),
        invalidatesTags: (_result, _error, { operationId }) => [
            { type: Tags.operations.notes, id: operationId },
        ],
    });
```

Wire into `api/index.ts` (endpoints object + hook exports).

### 5b. Form Schema

**Location:** `source/priis-web/src/features/{domain}/schema.ts`

```typescript
import { z } from 'zod/v4';   // ← ALWAYS 'zod/v4', never 'zod'
import { ErrorMessages } from '~strings/error-messages';

export const createOperationNoteSchema = z.object({
    content: z.string().min(1, { message: ErrorMessages.required }),
});

export type CreateOperationNoteFormValues = z.infer<typeof createOperationNoteSchema>;
```

Use `zodResolver` from `~/utility/validation/zod-v4-resolver` — never from `@hookform/resolvers/zod`.

### 5c. Component

```typescript
// Path aliases: ~components, ~features, ~api, ~enums, ~strings
// CSS Modules for styles, Radix UI for layout
// Controlled.* for form fields, Swedish labels everywhere
import { zodResolver } from '~/utility/validation/zod-v4-resolver';
import { useCreateOperationNoteMutation } from '~api';

export function CreateOperationNoteForm({ operationId, onSuccess }: Props) {
    const [createNote] = useCreateOperationNoteMutation();
    const { control, handleSubmit } = useForm<CreateOperationNoteFormValues>({
        resolver: zodResolver(createOperationNoteSchema),
        defaultValues: { content: '' },
        shouldUnregister: true,
    });

    const submit: SubmitHandler<CreateOperationNoteFormValues> = (data) => {
        createNote({ operationId, content: data.content })
            .unwrap()
            .then(() => onSuccess())
            .catch(() => {});
    };

    return (
        <form onSubmit={handleSubmit(submit)}>
            <Flex direction="column" gap="3">
                <Controlled.TextArea control={control} name="content" label="Notering" />
                <Buttons.Primary type="submit">Lägg till</Buttons.Primary>
            </Flex>
        </form>
    );
}
```

### 5d. Route File (if new page)

```typescript
// source/priis-web/src/routes/operations/$operationId/notes.tsx
import { createFileRoute } from '@tanstack/react-router';
import { OperationNotesPage } from '~features/operation/operation-notes-page';

export const Route = createFileRoute('/operations/$operationId/notes')({
    component: OperationNotesPage,
    staticData: { type: 'general', title: 'Noteringar' },
});
```

**Never edit `routeTree.gen.ts`** — it is auto-generated by Vite on save.

### 5e. Playwright Test IDs

Add to `source/priis-web/e2e/test-ids.ts`:

```typescript
export const operationNoteTestIds = {
    createButton: 'operation-note-create-button',
    contentInput: 'operation-note-content-input',
    submitButton: 'operation-note-submit-button',
    noteItem: (index: number) => `operation-note-item-${index}`,
};
```

Apply `data-testid={operationNoteTestIds.createButton}` in the component — never hardcode strings in tests.

---

## Phase 6 — Verification

Run all checks. Report PASS/FAIL for each. **Do not ship if any check fails.**

### Backend verification

```bash
# 1. Format (CI enforces this — a format diff = CI failure)
cd GR.PRIIS.Backend
dotnet format

# 2. Build (zero errors, zero warnings — project uses TreatWarningsAsErrors)
dotnet build --configuration Release

# 3. Unit tests
dotnet test --project tests/GR.PRIIS.Library.UnitTests --configuration Release

# 4. Integration tests (or targeted run for the changed domain)
dotnet test --project tests/GR.PRIIS.API.IntegrationTests.TUnit --configuration Release
# Targeted: --treenode-filter "/*/*/CreateOperationNoteEndpointTests/*"

# 5. Architecture tests
dotnet test --project tests/GR.PRIIS.ArchitectureTests --configuration Release
```

### Frontend verification

```bash
cd GR.PRIIS.Frontend/source/priis-web
npx organize-imports-cli tsconfig.json   # import sorting
npm run lint                              # ESLint
npm run build                            # TypeScript + Vite compile
```

### Anti-pattern scan (backend)

Grep changed `.cs` files for:

- `.Include(` on read-only queries → replace with `.Select()`
- `new List<`, `new []`, `Array.Empty<` → use `[]`
- `throw new` inside `Library/Features/` → use `SystemResult.Failure(...)`
- `async void` (non-event-handlers) → use `async Task`
- `.Result` / `.Wait()` → use `await`
- Class names ending in `Service`, `Handler`, `Manager`, `Helper`
- `async` methods missing `CancellationToken ct` parameter

### Anti-pattern scan (frontend)

Check changed `.ts/.tsx` files for:

- `import { z } from 'zod'` → must be `'zod/v4'`
- `from '@hookform/resolvers/zod'` → must be `~/utility/validation/zod-v4-resolver`
- Relative imports (`../`, `../../`) → use path aliases
- `style={{ }}` inline styles → use CSS Modules
- English labels/placeholder text in JSX → Swedish only
- Missing `invalidatesTags` on mutation endpoints
- Hardcoded `data-testid` strings in test files → export from `test-ids.ts`

---

## Phase 7 — Ship

> Read `backend-workflow` and/or `frontend-workflow` skills. Alternatively, run `/ship <work-item-id>` which automates this phase.

> [!IMPORTANT]
> **User Approval Required for Branch Push and PR Creation:** Do NOT push branches (`git push`) or create Pull Requests (`az repos pr create`) automatically. You must present the planned branch name, commit message, staged files, and PR title/description to the user in the chat for review first, and await explicit approval before running those commands.

### Manual steps

1. **Stage selectively** — never `git add -A`:

   ```bash
   git add source/GR.PRIIS.API/Features/... source/GR.PRIIS.Library/...
   ```

2. **Commit format:** `#<work-item-id>: <Swedish work item title>`

   ```text
   #28048: Begär ändring av totalt antal platser
   ```

3. **Push and create draft PR:**
    - Branch format: `feature/<id>_<english-kebab-slug>` (e.g., `feature/30048_add-oppenvard-barn-q4` — notice the underscore after the ID, but hyphens/kebab-case for the rest of the slug, NOT underscores like `add_oppenvard_barn_q4`). **CRITICAL: The slug MUST always be in English. Never use Swedish in branch names.**
    - PR title = commit message
   - PR body: fill in `docs/pull_request_template.md` template; end with `Resolved: #<id>`. If PRs are created for both Frontend and Backend, add `This PR relates to: !<other-pr-id>` at the end of the PR description to link them together.
   - Create PR via CLI:

      ```bash
      az repos pr create --org https://grutbildning.visualstudio.com --project PRIIS --title "#<id>: <description>" --draft --work-items <id>
      ```

   - Move work item to `Pull Request` state:

      ```bash
      az boards work-item update --id <id> --state "Pull Request" --org https://grutbildning.visualstudio.com
      ```

---

## Phase 8 — Walkthrough

Create or update `walkthrough.md` in the artifact brain directory. Include:

- Summary of all files changed and why
- Test results (copy the summary output)
- Any manual verification steps the user should take
- If UI changes: embed screenshots or browser recording links

Do **not** re-summarize the walkthrough in the chat response — just point the user to it and highlight any open items that need their attention.

---

## Quick Reference — Cross-Cutting Rules

| Rule | Never | Always |
|------|-------|--------|
| C# collections | `new List<T>()`, `Array.Empty<T>()` | `[]` |
| C# domain failures | `throw new Exception(...)` | `return SystemResult.Failure(...)` |
| EF reads in GET endpoints | `.Include(...)` | `.AsNoTracking().Select(...)` |
| EF writes | Manual `ChangedBy =` | Let interceptor handle audit fields |
| EF context in Library methods | `PriisDbContext` | `IReadOnlyPriisDbContext` |
| Zod imports | `from 'zod'` | `from 'zod/v4'` |
| zodResolver imports | `@hookform/resolvers/zod` | `~/utility/validation/zod-v4-resolver` |
| Frontend imports | Relative `../` | Path aliases `~api`, `~components`, etc. |
| TUnit filter flag | `--filter "FullyQualifiedName~..."` | `--treenode-filter "/*/*/ClassName/*"` |
| TUnit assertions | `Assert.Equal(x, y)` | `await Assert.That(x).IsEqualTo(y)` |
| PR mutation | `git add .` | `git add <specific files>` |
| ADO work item lookup | Browser navigation | `az boards work-item show --id <ID> --org https://grutbildning.visualstudio.com` |
| ADO PR creation | Browser navigation | `az repos pr create --org https://grutbildning.visualstudio.com --project PRIIS` |
| ADO state update | Browser navigation | `az boards work-item update --id <ID> --state "..." --org https://grutbildning.visualstudio.com` |
| Error messages in code | English | Swedish |
