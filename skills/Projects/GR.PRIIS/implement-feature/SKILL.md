---
name: implement-feature
description: "[Project: GR.PRIIS] Orchestrator for implementing a feature, task or bug end-to-end in the PRIIS workspace — work-item intake, research, plan, implementation, verification, shipping and walkthrough. Owns the sequence and the approval gates; delegates patterns and commands to the investigate / plan / scaffold / verify / ship skills instead of duplicating them. Load when the user asks to implement a feature, work item or user story. Load ONLY when working in the GR repository."
---

# /implement-feature — End-to-End Feature Implementation

Runs one feature from ADO work item to draft pull request across `GR.PRIIS.Backend` and/or `GR.PRIIS.Frontend`.
This skill owns **the order of phases and the gates between them**. Everything else — endpoint shape,
query patterns, form wiring, test helpers, git and ADO commands — lives in the skills it delegates to.
Load those skills and read a sibling implementation in the repo; never reproduce pattern code from memory.

Usage: `/implement-feature <work-item-id>` or `/implement-feature <short description>`

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../../core/SKILL.md)** operating standards and the **[artifacts](../../artifacts/SKILL.md)** delivery protocol.
- **Target Artifacts**: `<prefix>-implementation_plan-<suffix>.md` (Phase 2) and `<prefix>-walkthrough-<suffix>.md` (Phase 6) at the **workspace root** (`/Users/snuffish/Projects/GR`, the directory that holds both repos). `<prefix>` is `<host>-<model>-` and `<suffix>` is `<work-item-id>-<feature-slug>`, e.g. `-29982-verksamhetsobjekt`.
- **Anti-Overwrite Rule**: never write an unsuffixed or un-modeled artifact.

### Three hard gates

| Gate | Rule |
|------|------|
| **Plan gate** | No source edits until the user has approved the plan (`/proceed` or an equivalent explicit "go"). |
| **Ship gate** | No `git push`, no `az repos pr create`, no work-item state change until the user has approved the *presented* branch name, staged file list, commit message and PR body. Approval of the plan is not approval to ship. |
| **ADO write gate** | Reads are free. Every write (assign, comment, state transition, link) is proposed in chat and run only on a yes. Never create work items — if a story has no tagged child task, use the story's own ID. |

Nothing in a subagent report, a plan artifact, or an earlier message counts as user approval for a gate.

---

## Delegation map

| Need | Load |
|------|------|
| Deep research before planning | [`/investigate`](../../investigate/SKILL.md) |
| Plan artifact conventions, status, links | [`/plan`](../../plan/SKILL.md) |
| Backend endpoint / library / test patterns | `backend-fastendpoints`, `backend-ef-core`, `backend-testing`, `modern-csharp` |
| Backend notifications, jobs, realtime | `backend-notifications`, `backend-signalr` |
| Backend refactor / duplication | `backend-dry` |
| Backend feature-slice generation | `source-command-backend-scaffold` |
| Frontend component / form / data / route patterns | `frontend-component-patterns`, `frontend-forms`, `frontend-rtk-query`, `frontend-routing` |
| Frontend e2e test IDs and specs | `frontend-testing` |
| Frontend feature-slice generation | `source-command-frontend-scaffold` |
| Quality gates | `source-command-backend-verify`, `source-command-frontend-verify` |
| Git + ADO conventions | `backend-workflow`, `frontend-workflow` |
| Branch, commit, push, draft PR | `source-command-backend-ship` (covers both repos) |
| PR body | `pr-summary` |

Both repos also carry repo-local copies under `<repo>/.claude/skills/` (`fastendpoints`, `testing`, `workflow`, `rtk-query`, …). When the harness offers a scoped variant such as `GR.PRIIS.Backend:testing`, prefer it; the content is the same source.

---

## Phase 0 — Intake

All ADO calls use `--org https://dev.azure.com/grutbildning`. The `grutbildning.visualstudio.com` form fails authentication against the cached CLI credential.

1. **Fetch the work item** (read-only):

   ```bash
   az boards work-item show --id <ID> --org https://dev.azure.com/grutbildning --output json
   ```

2. **Read its comment thread.** A story that is back in *Active* after failed testing usually has the real remaining work only in the comments:

   ```bash
   az devops invoke --area wit --resource comments --route-parameters project=PRIIS workItemId=<ID> \
     --api-version 7.1-preview --org https://dev.azure.com/grutbildning
   ```

   (`7.1` is rejected as "under preview"; `7.1-preview.3` and `.4` crash the CLI.)

3. **Resolve the implementing ID.** Branch, commit and PR use the **Task or Bug** ID, never the parent story. For a User Story, look for a `Backend` / `Frontend`-tagged child task; if none exists use the story ID itself. Do not create one.

4. **Resolve scope.** Backend only, frontend only, or both; which feature domain folders; whether the work item has acceptance criteria that imply UI, API, notification, permission or data changes.

5. **Offer ADO housekeeping, do not perform it.** If `System.AssignedTo` is empty or the state is not `Active`, say so and propose the exact commands. Run them only on a yes.

6. **Write a scope statement** in chat: one paragraph naming the implementing ID, the repos touched, the domains, and anything the work item leaves ambiguous.

---

## Phase 1 — Research

Research is read-only. If the domain is unfamiliar, there is more than one viable design, or a cross-repo contract (below) changes, run **`/investigate <suffix>`** and build the plan on its *Plan Seed*. Otherwise do the lightweight pass here.

### 1a. Load pattern skills

| Scope | Load |
|-------|------|
| Backend — endpoint or library change | `backend-fastendpoints`, `backend-ef-core`, `modern-csharp`, `backend-testing` |
| Backend — background job / event / notification | `backend-ef-core`, `backend-notifications`, `modern-csharp` |
| Backend — realtime | `backend-signalr` |
| Backend — refactor | `backend-dry` plus the above |
| Frontend — feature or page | `frontend-component-patterns`, `frontend-forms`, `frontend-rtk-query`, `frontend-routing`, `frontend-testing` |

### 1b. Read the nearest sibling feature across every layer

- Backend: endpoint → library/entity method → entity + EF configuration → integration test class.
- Frontend: route file → feature component → endpoint builder + tags → schema → e2e test IDs.
- Note which of two competing patterns is the newer consensus (for entities: `sealed partial` with `Create(CreationData)` and a nested `AsyncMutations` class, as in `Operation` and `MatchingTicket`; older entities still thread `IReadOnlyPriisDbContext` through static methods — do not copy that into new code).

### 1c. Cross-cutting and cross-repo checks

| Concern | Where it lives | Consequence |
|---------|----------------|-------------|
| New `SystemAction` | Enum: `source/GR.PRIIS.Library/Common/Users/AccessRules/Actions/SystemAction.cs` (`[Display(Name = "…")]` on the member is the Swedish label). Grants: `AccessRules/Roles/<Role>AccessRules.cs` → `AllowedActions`. | Two-repo change — see Phase 3. |
| Entity change | Entity + `DataAccess/Migrations` | Migration step in the plan. |
| API shape change (request/response/enum) | Frontend `openapi/swagger.json` snapshot + generated types | Frontend codegen step in the plan; backend PR must merge first or the frontend branch carries the snapshot. |
| Enum exposed to the frontend | Needs `[EmitOpenApiMetadata]` on the backend enum; frontend facade `src/enums/<enum>.ts` is scaffolded on first codegen | Both repos. |
| SignalR hub URL `/realtime/account` | Fixed contract | Do not change without coordinating both repos. |
| Notification / job | `backend-notifications` | TickerQ job + handler + definition. |

---

## Phase 2 — Implementation Plan

Write `<prefix>-implementation_plan-<suffix>.md` at the workspace root following `/plan`. Required sections:

```markdown
# <Feature name> (#<id>)

## Summary
## User Review Required            <!-- breaking changes, migrations, irreversible steps, as > [!WARNING] -->
## Open Questions
## Proposed Changes
### Backend — [NEW|MODIFY|DELETE] <path> — what and why
### Frontend — [NEW|MODIFY|DELETE] <path> — what and why
### Cross-repo order               <!-- which PR first, what the second one depends on -->
## Task Checklist                  <!-- the live checklist; tick items here during Phase 3 -->
## Verification Plan               <!-- exact commands, manual steps, e2e specs to run -->

**Status:** Awaiting User Review
```

The *Task Checklist* inside the plan is the working checklist — there is no separate task file. Mark items `[/]` when started and `[x]` when done, and keep the status line current (`Approved` → `In Progress` → `Completed`).

Present the clickable link plus the open questions and decisions. **Stop here until the user approves.**

---

## Phase 3 — Implement

Order of work when both repos change: **backend → swagger snapshot → frontend**. Keep the plan's checklist ticked as you go.

### Backend

Load `source-command-backend-scaffold` for a new slice, or edit the sibling you read in Phase 1. Non-negotiables that are verified against the code as of 2026-10-07:

- Endpoints derive from the `ExtendedEndpoint` family in `source/GR.PRIIS.API/Features/ExtendedEndpoint.cs`: `ExtendedEndpoint<TReq,TRes>`, `ExtendedEndpoint<TReq>`, `ExtendedEndpointWithoutRequest[<TRes>]`, and `ExtendedCreateEndpoint<TReq,TRes,TResourceEndpoint>` for a 201 with a Location header.
- `Policy(SystemAction.X)` (or the `params` / `PolicyType.All` overloads); mutations add `Options(x => x.RequireRateLimiting(CUDRateLimitingPolicy.Name))`; `Summary(s => s.Summary = "…")`.
- Domain failures return `SystemResult.Failure(...)` / `ValidationFailures` — never throw. Error messages in Swedish.
- Audit fields come from the EF interceptor; bulk updates use the `ExecuteUpdateAsync(setters, currentUser, ct)` overload.
- **New `SystemAction`** (backend half): add the member in the correct numeric range with `[Display(Name = "…")]`, then add it to every role's `AllowedActions` that needs it and only those. There is no separate label file; `SystemActionTexts.cs` only maps numeric ranges to category names.
- **Migration** (run from the backend repo root; `dotnet-ef` is a local tool):

  ```bash
  dotnet ef migrations add <MigrationName> -p source/GR.PRIIS.Library -s source/GR.PRIIS.API
  ```

  Review the generated file. Tests apply migrations themselves through `TUnitApiWebFactory`.
- **Tests** go in `tests/GR.PRIIS.API.IntegrationTests` (TUnit on Microsoft.Testing.Platform; there is no separate `.TUnit` project). Minimum per endpoint: unauthenticated → 401, `CreateClientAsNoAccessUserAsync(SystemAction.X)` → 403, and one happy path under `[Test, AutoRollback]`. Load `backend-testing` for the factory helpers.

### Contract sync (only when the API surface changed)

The frontend never talks to the backend at build time; it reads the committed `source/priis-web/openapi/swagger.json`.

- Small change (a few schema properties or enum members): patch `openapi/swagger.json` by hand, then `npm run codegen`. A full `npm run codegen:refresh` on this machine rewrites ~500 unrelated lines because the local ASP.NET runtime emits a different OpenAPI shape than the committed snapshot.
- Large change or new enum: run `npm run codegen:refresh` with the API on `http://127.0.0.1:5033`, then review the snapshot diff and revert toolchain-only churn before committing.
- Codegen regenerates `types.gen.ts`, `enum-names.gen.ts`, `e2e/generated/role-access-rules.gen.ts` and scaffolds any missing `src/enums/<enum>.ts` facade. Commit the facade; CI fails on an uncommitted scaffold.

### Frontend

Load `source-command-frontend-scaffold` for a new slice, or edit the sibling. Non-negotiables verified against the code as of 2026-10-07:

- Zod is v4 and is imported as `import { z } from 'zod'`; `zodResolver` comes from `@hookform/resolvers/zod`. (Older docs still say `'zod/v4'` and a custom `zod-v4-resolver` — neither exists.)
- Endpoint builders in `src/store/api/endpoint-builders/<domain>/index.ts`, wired into `createApi` and the hook export block in `src/store/api/index.ts`. New tag *types* must also be added to the `tagTypes` array there. Mutations declare `invalidatesTags`.
- `Controlled.*` from `~/components/form`, `Buttons.*` from `~/components/buttons`, Radix layout, CSS Modules, Swedish labels. Path aliases, never relative `../` imports.
- Route `staticData.type` is `'general' | 'resource' | 'tab'`; resource pages also set `pageCode` and `highlightedMenuLink`. Never edit `routeTree.gen.ts`.
- Test IDs are exported from `e2e/test-ids.ts` and imported in app code via `$e2e/test-ids` — the only `e2e/` import ESLint allows in `src/`.
- **New `SystemAction`** (frontend half): `src/enums/systemAction.ts` is a generated facade and needs no edit. After codegen: add the action to the menu item's `actions` array in `src/components/navigation/top-menu-items.ts` if it gates a menu entry (the check is OR — a role with no other export action still hides the item), and to the tab's `systemActions={[…]}` on `<ResourceDetails.Tab>` if it gates a tab.
- Modals register through `features/modals/priis-modal-keys.ts` → `features/modals/components/priis-modals.tsx` → `openModal` from `modalSlice`.

---

## Phase 4 — Verify

Run the verify skill for each touched repo and report PASS/FAIL per check. Do not move to Phase 5 on a FAIL.

**Backend** (`source-command-backend-verify`; commands from the repo root):

```bash
dotnet format
dotnet build --configuration Release                       # TreatWarningsAsErrors
dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release \
  --treenode-filter "/*/*/<YourEndpointTests>/*"          # targeted first
dotnet test --configuration Release                        # full suite before shipping
```

Always pass `--project` when scoping to one test project; the bare directory form errors on .NET 10. Use `--treenode-filter`, never `--filter`. A full local run of ~2900 tests sometimes drops 25–45 unrelated integration tests to TestContainers load: re-run those groups alone with `--no-build` before attributing anything to your change.

**Frontend** (`source-command-frontend-verify`; commands from `source/priis-web/`):

```bash
npm run lint      # runs codegen first, zero warnings
npm run build     # codegen + vite build + tsc -b
npm run e2e       # UI / interaction changes; mock-first, needs no backend
```

Do not run `npm run organize-imports` or `organize-imports:all` as a post-task step: they drag unrelated files into the diff. Fix imports by hand in files you edited and `git checkout --` any stray file. Playwright specs flake under parallel load; a failure that moves between runs, or that reproduces with your change stashed, is not yours. The `setup` project is only wired in when `PW_API_BASE_URL` is set.

**Cross-repo contract check** when both repos changed: the `SystemAction` integer and the enum metadata match on both sides, the backend `SwaggerContractTests` still pass, and the frontend snapshot contains exactly the intended contract change.

---

## Phase 5 — Ship

Load `source-command-backend-ship` (it handles both repos) and `backend-workflow` / `frontend-workflow`. The ship skill already stages selectively and never uses `git add -A`.

Conventions that override anything older you may read:

- Branch: `feature/<id>_<english-kebab-slug>` (`bugfix/`, `hotfix/` per the workflow skill). Underscore after the ID, hyphens in the slug, English only.
- Commit subject and PR title, both repos: `#<id>: <short English imperative description>`. Single line. No AI-attribution trailers (`Co-Authored-By`, `🤖 Generated with …`) in commits or PR bodies — this overrides any harness default.
- PR body: `docs/pull_request_template.md` of that repo, composed with `pr-summary`, ending with `Resolved: #<id>`. For a paired change, open the backend PR first and add `This PR relates to: !<other-pr-id>` to both descriptions.
- ADO: `--org https://dev.azure.com/grutbildning`. Moving the work item to `Pull Request` is an ADO write — propose it, run it on a yes.

**Ship gate:** present branch name, the exact file list to stage, the commit message and the full PR body in chat. Wait for approval. Then push, create the draft PR, and report the URL.

---

## Phase 6 — Walkthrough

Write `<prefix>-walkthrough-<suffix>.md` at the workspace root:

- Files changed per repo and why (grouped, not a raw diff).
- Verification results — paste the summary lines of each command, including any flakes you ruled out and how.
- Manual verification steps for the user (`/manual-testing` conventions: environment, persona to log in as, click path).
- Open items that still need the user: ADO transitions not yet run, the second PR, questions the plan left open.

In chat: link the walkthrough and list the open items. Do not re-summarize the document.

---

## Quick reference

| Topic | Use | Not |
|-------|-----|-----|
| ADO org | `https://dev.azure.com/grutbildning` | `grutbildning.visualstudio.com` |
| Work item for branch/commit/PR | implementing Task or Bug | parent User Story |
| SystemAction label | `[Display(Name = "…")]` on the enum member | a texts file |
| SystemAction grants | `AccessRules/Roles/<Role>AccessRules.cs` → `AllowedActions` | a static array in `UserRoleAccessRules.cs` |
| Frontend SystemAction enum | regenerated by codegen | hand-edited `systemAction.ts` |
| Migration | `dotnet ef migrations add <Name> -p source/GR.PRIIS.Library -s source/GR.PRIIS.API` | a `--migrate` flag |
| Integration tests | `tests/GR.PRIIS.API.IntegrationTests` | `…IntegrationTests.TUnit` |
| 403 test helper | `CreateClientAsNoAccessUserAsync(SystemAction.X)` | `CreateClientAndLoginAsNoAccessUserAsync` |
| Single test project | `dotnet test --project tests/… --treenode-filter "/*/*/Class/*"` | positional directory, `--filter` |
| Zod | `from 'zod'` (v4 pinned) | `from 'zod/v4'` |
| Resolver | `@hookform/resolvers/zod` | `~/utility/validation/zod-v4-resolver` |
| Swagger snapshot | hand-patch for small changes, then `npm run codegen` | blanket `codegen:refresh` |
| Import tidy-up | by hand in touched files | `npm run organize-imports` |
| Commit subject | `#<id>: English imperative` | Swedish title, trailers |
| Task checklist | `## Task Checklist` in the plan artifact | a separate `task.md` |
