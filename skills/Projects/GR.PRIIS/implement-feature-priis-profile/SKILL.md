---
name: implement-feature-priis-profile
description: "[Project: GR.PRIIS] Command profile adapting /implement-feature to PRIIS conventions: Azure DevOps work item intake rules, feature branch naming, scaffolding templates, verify/ship skill integration, and entity sibling patterns. Load with implement-feature when building features in the GR workspace. Load ONLY when working on GR.PRIIS or in the GR repository."
user-invocable: false
---

# `implement-feature-priis-profile` — PRIIS project profile for `/implement-feature`

Reference data for the general `implement-feature` skill (`/implement-feature`), the orchestrator. It does not own phases, gates or sub-agent rules — those are the orchestrator's. Each section below is keyed to the orchestrator's phase it feeds. Facts marked *verified <date>* were checked against the code on that date; when the code has moved on, follow the code and update the date here.

The shared PRIIS fields — the workspace, Layout, Tracker, PR tooling, Pattern skills per layer, Sibling chain, Contract touchpoints, Report language, Known drift, Worktree include list, Dependency hydration and Shared local services — are in the `priis-profile` skill › *Profile fields*. Load it first; nothing here restates them.

---

## Profile fields

| Field | Value |
|-------|-------|
| **Shared fields** | See the `priis-profile` skill › *Profile fields*. |
| **Implementing ID** | Branch, commit and PR use the **Task or Bug** ID, never the parent story. For a User Story, look for a `Backend` / `Frontend`-tagged child task in the relations; if none exists use the story ID itself. Do not create one. |
| **Scaffold skills** | `priis-backend-scaffold`, `priis-frontend-scaffold` |
| **Verify** | `priis-backend-verify` (incl. its architecture-tests phase), `priis-frontend-verify` (+ `npm run e2e`, which the verify skill lacks). |
| **Ship** | `priis-backend-ship` (covers both repos), `priis-backend-workflow`, `priis-frontend-workflow`, `pr-summary`. Conventions in *Phase 6*. |
| **Worktree branch** | `feature/<id>_<english-kebab-slug>` (`bugfix/`, `hotfix/`) — the same convention as *Phase 6*; never `worktree-<name>`. Base: freshly fetched `origin/main` in both repos. |

### Precedence overrides for delegated PRIIS skills

- `priis-backend-ship` stops on a User Story, pushes and creates the PR right after its file prompt, passes the PR body inline, and moves the work item to `Pull Request` unconditionally. Under the orchestrator: a story without a tagged child task ships under its own ID; push and PR creation wait for the ship gate; the PR body goes through a temp file (`pr-summary` §5.2); the state transition is a tracker write.
- `priis-backend-ship`, `priis-backend-verify` and `priis-frontend-verify` resolve the repo from the current working directory (`rev-parse --show-toplevel`, `cd source/priis-web`) when no `[worktree-context]` is handed in. Under the orchestrator they always receive the block and run against `repo-root`; the ship skill confirms the worktree's existing branch instead of `checkout -b`.

---

## Phase 0 — Intake

1. Fetch the work item:

   ```bash
   az boards work-item show --id <ID> --org https://dev.azure.com/grutbildning --expand relations --output json
   ```

2. Ask the user to paste the discussion thread (a screenshot is fine). `az devops invoke … comments` fails to parse the preview API version and `az rest` returns the sign-in page. Planning decisions — and the real remaining work on a story reopened after testing — often live only there. Also note any `product decision <date>` comments in the code; they can disagree with the thread.
3. Housekeeping to propose, never run unprompted: assign when `System.AssignedTo` is empty; move to `Active` when the state is not `Active`.

---

## Phase 1 — Research

Pattern skills, the sibling chain and the cross-cutting checks: the `priis-profile` skill › *Pattern skills* and *Cross-cutting and cross-repo checks*. What each check means for an implementation:

- New `SystemAction` → both halves in Phase 3.
- Entity change → a migration step in the plan, plus the migration check in Phase 4 (tests do not run migrations).
- API shape change → a contract-sync step in the plan (Phase 3 *Contract sync*).

### Sibling patterns

- Entities: `sealed partial` with `Create(CreationData)` and a nested `AsyncMutations` class in its own partial file, as in `Operation` and `MatchingTicket`. Older entities still thread `IReadOnlyPriisDbContext` through static methods — do not copy that.

---

## Phase 2 — Plan

Blind-spot vectors specific to this workspace, in addition to the orchestrator's: EF Core behaviour, TickerQ, SignalR and the RTK cache — read the installed source under `bin/`, `obj/` or `node_modules/` for the path the plan depends on; and any new enum member, `SystemAction`, DTO field or event that other code switches on.

---

## Phase 3 — Implement

Order: **backend → swagger snapshot → frontend**.

### Backend (verified 2026-10-14)

- Endpoint bases in `source/GR.PRIIS.API/Features/ExtendedEndpoint.cs`: `ExtendedEndpoint<TReq,TRes>`, `ExtendedEndpoint<TReq>` (no content), `ExtendedEndpointWithoutRequest[<TRes>]`, and `ExtendedCreateEndpoint<TReq,TRes,TResourceEndpoint>` for a 201 with a Location header. `Policy(...)` has single, `params`, `PolicyType` and delegatable overloads.
- Domain failures return `SystemResult.Failure(...)` / `ValidationFailures` — never throw. Error messages in Swedish.
- Raw `ExecuteUpdate[Async]` is banned (`source/BannedSymbols.txt`). Use the `ExecuteUpdateAsync(setters, currentUser, ct)` overload (stamps `ChangedBy`) or `ExecuteUnauditedUpdateAsync` for non-auditable entities.
- **New `SystemAction`** (backend half): add the member in the correct numeric range with `[Display(Name = "…")]`, then add it to every role's `AllowedActions` that needs it and only those. `SystemActionTexts.cs` only maps numeric ranges to category names.
- **Migration** (from the backend repo root; `dotnet-ef` is a local tool): `dotnet ef migrations add <Name> -p source/GR.PRIIS.Library -s source/GR.PRIIS.API`. Review the generated file. Several migrations on the branch → `squash-ef-core-migrations` before shipping.
- **Tests** go in `tests/GR.PRIIS.API.IntegrationTests` (TUnit on MTP). Minimum per endpoint: unauthenticated (`ApiWebFactory.CreateClient()`) → 401, `CreateClientAsNoAccessUserAsync(SystemAction.X)` → 403, and one happy path under `[Test, AutoRollback]`.

### Contract sync (only when the API surface changed)

The frontend never talks to the backend at build time; it reads the committed `source/priis-web/openapi/swagger.json`.

- Small change (a few schema properties or enum members): patch `openapi/swagger.json` by hand, then `npm run codegen`. A full `codegen:refresh` on this machine rewrites ~500 unrelated lines because the local ASP.NET runtime emits a different OpenAPI shape.
- Large change or new enum: `npm run codegen:refresh` with the API on `http://127.0.0.1:5033` (or `SWAGGER_URL`), then revert toolchain-only churn in the snapshot before committing.
- Generated output (`src/store/api/generated/*`, `e2e/generated/role-access-rules.gen.ts`, `routeTree.gen.ts`) is gitignored. Missing `src/enums/<enum>.ts` facades are scaffolded by `src/codegen/openapi-metadata/` and **must be committed** — CI fails on an uncommitted scaffold.

### Frontend (verified 2026-10-14)

- Zod is v4, imported as `import { z } from 'zod'`; `zodResolver` from `@hookform/resolvers/zod`. Do not copy the three legacy `'zod/v4'` imports.
- Endpoint builders in `src/store/api/endpoint-builders/<domain>/index.ts`, registered with `injectEndpoints` in the same folder's `api.ts`, which exports that domain's hooks; `src/store/api/index.ts` is only a barrel (one line per domain). `createApi`, the base query and the `tagTypes` array live in `src/store/api/base.ts`; each domain's tags live in its own `endpoint-builders/<domain>/tags.ts` (`tagOf` in `src/store/api/tags.ts`). Mutations declare `invalidatesTags`; a write to another domain's data announces `<domain>Changed()`, a query showing another domain's data provides its `<domain>Subscriptions` entry — never another domain's raw tags (lint-enforced, frontend `docs/adr/0001`).
- Use path aliases (`~/components/form`, `~/components/buttons`, `~features/…`, `~enums`) over relative `../` imports — convention, not lint-enforced.
- Route `staticData.type` is `'general' | 'resource' | 'tab'`; resource pages also set `pageCode` and `highlightedMenuLink`.
- Test IDs come from `e2e/test-ids.ts` via `$e2e/test-ids` — the only `e2e/` import ESLint allows in `src/`.
- **New `SystemAction`** (frontend half): `src/enums/systemAction.ts` needs no edit after codegen. Add the action to the menu item's `actions` in `src/components/navigation/top-menu-items.ts` if it gates a menu entry (the check is OR — a role with no other matching action still hides the item), and to `<ResourceDetails.Tab systemActions={[…]}>` if it gates a tab.
- Modals register through `features/modals/priis-modal-keys.ts` → `features/modals/components/priis-modals.tsx` → `openModal` from `modalSlice`.

---

## Phase 4 — Verify

**Backend** (`priis-backend-verify`, including its architecture-tests phase):

- Scope a run with `dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/<Class>/*"` — `--project` is required on .NET 10; never `--filter`. Targeted first, full suite before shipping.
- A full local run drops 25–45 unrelated integration tests to TestContainers load. Re-run those groups alone with `--no-build`; only failures that persist alone are yours.
- **Migration check**: integration tests build the schema with `EnsureCreatedAsync`, so they never execute a migration. Apply it to the local database from `source/GR.PRIIS.CLI` with `dotnet run -- migrations -s -d` and confirm it runs clean.

**Frontend** (`priis-frontend-verify`; from `source/priis-web/`): `npm run organize-imports` (changed files only; never `:all`), `npm run lint`, `npm run build`, and `npm run e2e` for UI changes. The default e2e leg needs no backend; the `setup` project only joins when `PW_API_BASE_URL` is set, and that leg must not use `--no-deps`.

**Cross-repo contract check**: the `SystemAction` integer and the enum metadata match on both sides, the backend `SwaggerContractTests` pass, and the frontend snapshot contains exactly the intended contract change.

---

## Phase 6 — Ship

- Branch: `feature/<id>_<english-kebab-slug>` (`bugfix/`, `hotfix/` per the workflow skill). Note the underscore after the ID.
- Commit subject and PR title, both repos: `#<id>: <short English imperative description>`. Single line. **No AI-attribution trailers** (`Co-Authored-By`, `🤖 Generated with …`) in commits or PR bodies — this overrides the harness default.
- PR body: invoke `/pr-summary` in preview mode per repo (it reads `docs/pull_request_template.md`), then follow the orchestrator's Phase 6a. Draft PR. For a paired change, open the backend PR first; the `This PR relates to: !<other-pr-id>` footer is filled once both IDs exist.
- Work-item state after the PR exists: `Pull Request` — propose it, run it on a yes.

---

## Quick reference

| Topic | Use | Not |
|-------|-----|-----|
| ADO org | `https://dev.azure.com/grutbildning` | `grutbildning.visualstudio.com` |
| Work-item discussion | ask the user to paste it | `az devops invoke … comments` |
| SystemAction label | `[Display(Name = "…")]` on the enum member | a texts file |
| SystemAction grants | `AccessRules/Roles/<Role>AccessRules.cs` → `AllowedActions` | a static array in `UserRoleAccessRules.cs` |
| Frontend SystemAction enum | regenerated by codegen | hand-edited `systemAction.ts` |
| Migration | `dotnet ef migrations add <Name> -p source/GR.PRIIS.Library -s source/GR.PRIIS.API` | a `--migrate` flag |
| Migration verified by | applying it via `GR.PRIIS.CLI` `migrations -s -d` | the integration tests (they use `EnsureCreated`) |
| 401 / 403 test clients | `ApiWebFactory.CreateClient()` / `CreateClientAsNoAccessUserAsync(SystemAction.X)` | `CreateClientAndLoginAsNoAccessUserAsync` |
| Single test project | `dotnet test --project tests/… --treenode-filter "/*/*/Class/*"` | positional directory, `--filter` |
| Zod / resolver | `from 'zod'` / `@hookform/resolvers/zod` | `'zod/v4'` / `zod-v4-resolver` |
| Codegen plugin | `src/codegen/openapi-metadata/` | `enum-metadata-plugin.ts` |
| Swagger snapshot | hand-patch for small changes, then `npm run codegen` | blanket `codegen:refresh` |
| Import tidy-up | `npm run organize-imports` (changed files only) | `organize-imports:all` |
| PR body | `/pr-summary` preview → temp file → cross-link after both PRs exist | hand-written body, inline `--description "…"` |
| Commit subject | `#<id>: English imperative` | Swedish title, attribution trailers |
