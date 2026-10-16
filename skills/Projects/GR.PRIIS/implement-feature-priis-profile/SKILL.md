---
name: implement-feature-priis-profile
description: "[Project: GR.PRIIS] Project profile consumed by the general /implement-feature orchestrator — the PRIIS workspace's resolved facts for every phase: Azure DevOps intake rules, implementing-ID rule, which backend/frontend pattern, scaffold, verify and ship skills to load, the sibling chain per repo, the cross-repo contract touchpoints (SystemAction, enum metadata, swagger snapshot, SignalR), verified implementation and verification facts, ship conventions and known documentation drift. Load together with implement-feature when implementing a feature, work item or user story in the GR workspace. Load ONLY when working on the GR.PRIIS.Backend or GR.PRIIS.Frontend project or in the GR repository."
---

# `implement-feature-priis-profile` — PRIIS project profile for `/implement-feature`

Reference data for the general [`/implement-feature`](../../../implement-feature/SKILL.md) orchestrator. It does not own phases, gates or sub-agent rules — those are the orchestrator's. Each section below is keyed to the orchestrator's phase it feeds. Facts marked *verified <date>* were checked against the code on that date; when the code has moved on, follow the code and update the date here.

Workspace: `/Users/snuffish/Projects/GR` (workspace root; itself a git repo that tracks only workspace files such as `.agents/` and `.github/`, and **ignores** both product directories — so it is a shell for `git-worktrees` repo resolution, and worktrees are created per product repo) holding `GR.PRIIS.Backend/` (.NET 10, FastEndpoints, EF Core, TUnit) and `GR.PRIIS.Frontend/` (React 18, TypeScript, Vite, RTK Query, TanStack Router, Playwright), each its own git repo on `origin/main`. Artifacts go to the workspace root.

---

## Profile fields

| Field | Value |
|-------|-------|
| **Layout** | Two repos under one workspace root. Backend is the producer; frontend consumes the committed OpenAPI snapshot. |
| **Tracker** | Azure DevOps Boards, org `https://dev.azure.com/grutbildning` (never the `visualstudio.com` host — it fails auth). CLI: `az boards`. The CLI **cannot** read work-item discussion comments here. |
| **Implementing ID** | Branch, commit and PR use the **Task or Bug** ID, never the parent story. For a User Story, look for a `Backend` / `Frontend`-tagged child task in the relations; if none exists use the story ID itself. Do not create one. |
| **Pattern skills per layer** | See *Phase 1* below. |
| **Sibling chain** | Backend: endpoint → library/entity method → entity + EF configuration → integration test class. Frontend: route file → feature component → endpoint builder + tags → schema → e2e test IDs. |
| **Scaffold skills** | `source-command-backend-scaffold`, `source-command-frontend-scaffold` |
| **Verify** | `source-command-backend-verify` (incl. its architecture-tests phase), `source-command-frontend-verify` (+ `npm run e2e`, which the verify skill lacks). |
| **Ship** | `source-command-backend-ship` (covers both repos), `backend-workflow`, `frontend-workflow`, `pr-summary`. Conventions in *Phase 6*. |
| **Contract touchpoints** | `SystemAction` integer values, `[EmitOpenApiMetadata]` enum metadata (`x-enumMetadata`), `x-roleAccessRules`, the committed `openapi/swagger.json` snapshot, the SignalR hub URL `/realtime/account`, Swedish (`sv-SE`) UI text with English URL paths. |
| **Known drift** | Repo-local `<repo>/.claude/skills/`, `<repo>/.claude/commands/` and both `.github/copilot-instructions.md` files are stale and diverge from the registry skills. The backend scaffold template shows `CreateClientAndLoginAsNoAccessUserAsync` (gone). Three legacy `'zod/v4'` imports remain in the frontend. Older entities thread `IReadOnlyPriisDbContext` through static methods. Follow the code. |
| **Worktree branch** | `feature/<id>_<english-kebab-slug>` (`bugfix/`, `hotfix/`) — the same convention as *Phase 6*; never `worktree-<name>`. Base: freshly fetched `origin/main` in both repos. |
| **Worktree include list** (`git-worktrees` §5c, *verified 2026-10-16*) | Backend, all gitignored: `source/GR.PRIIS.API/appsettings.local.json`, `source/GR.PRIIS.CLI/appsettings.local.json`, `source/GR.PRIIS.Worker/appsettings.local.json` — copy from the main checkout or the integration suite targets the default connection string. Frontend: none — every `source/priis-web/.env*` file is tracked. Do not copy `.claude/settings.local.json`. |
| **Dependency hydration** (`git-worktrees` §5c) | Frontend: `(cd <repo-root>/source/priis-web && npm ci)` (~460 MB, minutes). Backend: none — `dotnet build` restores. Dependency symlinking: **off** (a lockfile change on the branch would otherwise mutate the main checkout's install); enable here if it is ever wanted. |
| **Shared local services** (`git-worktrees` §5e) | The API on `http://127.0.0.1:5033` (contract sync, `codegen:refresh`), the Playwright dev server, and the local SQL database the integration suite uses. Shared between worktrees and with the user's own running app: a second concurrent run of the same repo verifies with targeted suites only and says so. |

### Precedence overrides for delegated PRIIS skills

- `source-command-backend-ship` stops on a User Story, pushes and creates the PR right after its file prompt, passes the PR body inline, and moves the work item to `Pull Request` unconditionally. Under the orchestrator: a story without a tagged child task ships under its own ID; push and PR creation wait for the ship gate; the PR body goes through a temp file (`pr-summary` §5.2); the state transition is a tracker write.
- `source-command-backend-ship`, `source-command-backend-verify` and `source-command-frontend-verify` resolve the repo from the current working directory (`rev-parse --show-toplevel`, `cd source/priis-web`) when no `[worktree-context]` is handed in. Under the orchestrator they always receive the block and run against `repo-root`; the ship skill confirms the worktree's existing branch instead of `checkout -b`.

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

### Pattern skills

| Scope | Load |
|-------|------|
| Backend — endpoint or library change | `backend-fastendpoints`, `backend-ef-core`, `modern-csharp`, `backend-testing` |
| Backend — background job / event / notification | `backend-ef-core`, `backend-notifications`, `modern-csharp` |
| Backend — realtime | `backend-signalr` |
| Backend — refactor | `backend-dry` plus the above |
| Frontend — feature or page | `frontend-component-patterns`, `frontend-forms`, `frontend-rtk-query`, `frontend-routing`, `frontend-testing` |

### Sibling patterns

- Entities: `sealed partial` with `Create(CreationData)` and a nested `AsyncMutations` class in its own partial file, as in `Operation` and `MatchingTicket`. Older entities still thread `IReadOnlyPriisDbContext` through static methods — do not copy that.

### Cross-cutting and cross-repo checks

| Concern | Where it lives | Consequence |
|---------|----------------|-------------|
| New `SystemAction` | Enum: `source/GR.PRIIS.Library/Common/Users/AccessRules/Actions/SystemAction.cs` (`[Display(Name = "…")]` is the Swedish label). Grants: `AccessRules/Roles/<Role>AccessRules.cs` → `AllowedActions`. | Two-repo change — see Phase 3. |
| Entity change | Entity + `source/GR.PRIIS.Library/DataAccess/Migrations` | Migration step in the plan, plus the migration check in Phase 4 (tests do not run migrations). |
| API shape change (request/response/enum) | Frontend `source/priis-web/openapi/swagger.json` snapshot | Contract-sync step in the plan; backend PR merges first or the frontend branch carries the snapshot. |
| Enum exposed to the frontend | `[EmitOpenApiMetadata]` on the backend enum; frontend facade `src/enums/<enum>.ts` is scaffolded on first codegen | Both repos. |
| SignalR hub URL `/realtime/account` | Fixed contract | Do not change without coordinating both repos. |
| Notification / job | `backend-notifications` | TickerQ job + handler + definition. |

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
- Endpoint builders in `src/store/api/endpoint-builders/<domain>/index.ts`, wired into `src/store/api/index.ts` (`createApi` and the hook exports). New tag types go in its `tagTypes` array; `Tags` / `tagOf` live in `src/store/api/tags.ts`. Mutations declare `invalidatesTags`.
- Use path aliases (`~/components/form`, `~/components/buttons`, `~features/…`, `~enums`) over relative `../` imports — convention, not lint-enforced.
- Route `staticData.type` is `'general' | 'resource' | 'tab'`; resource pages also set `pageCode` and `highlightedMenuLink`.
- Test IDs come from `e2e/test-ids.ts` via `$e2e/test-ids` — the only `e2e/` import ESLint allows in `src/`.
- **New `SystemAction`** (frontend half): `src/enums/systemAction.ts` needs no edit after codegen. Add the action to the menu item's `actions` in `src/components/navigation/top-menu-items.ts` if it gates a menu entry (the check is OR — a role with no other matching action still hides the item), and to `<ResourceDetails.Tab systemActions={[…]}>` if it gates a tab.
- Modals register through `features/modals/priis-modal-keys.ts` → `features/modals/components/priis-modals.tsx` → `openModal` from `modalSlice`.

---

## Phase 4 — Verify

**Backend** (`source-command-backend-verify`, including its architecture-tests phase):

- Scope a run with `dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/<Class>/*"` — `--project` is required on .NET 10; never `--filter`. Targeted first, full suite before shipping.
- A full local run drops 25–45 unrelated integration tests to TestContainers load. Re-run those groups alone with `--no-build`; only failures that persist alone are yours.
- **Migration check**: integration tests build the schema with `EnsureCreatedAsync`, so they never execute a migration. Apply it to the local database from `source/GR.PRIIS.CLI` with `dotnet run -- migrations -s -d` and confirm it runs clean.

**Frontend** (`source-command-frontend-verify`; from `source/priis-web/`): `npm run organize-imports` (changed files only; never `:all`), `npm run lint`, `npm run build`, and `npm run e2e` for UI changes. The default e2e leg needs no backend; the `setup` project only joins when `PW_API_BASE_URL` is set, and that leg must not use `--no-deps`.

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
