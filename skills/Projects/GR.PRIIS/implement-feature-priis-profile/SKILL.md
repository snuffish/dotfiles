---
name: implement-feature-priis-profile
description: "[Project: GR.PRIIS] Command profile adapting /implement-feature to PRIIS conventions: Azure DevOps work item intake rules, feature branch naming, scaffolding templates, verify/ship skill integration, and entity sibling patterns. Load with implement-feature when building features in the GR workspace. Load ONLY when working in the GR.PRIIS repository or the GR folder that holds it."
user-invocable: false
---

# `implement-feature-priis-profile` — PRIIS project profile for `/implement-feature`

Reference data for the general `implement-feature` skill (`/implement-feature`), the orchestrator. It does not own phases, gates or sub-agent rules — those are the orchestrator's. Each section below is keyed to the orchestrator's phase it feeds.

The shared PRIIS fields — workspace, Layout, Tracker & PR tooling, References per layer, Sibling chain, Contract touchpoints, Report language, Known drift, Worktree include list, Dependency hydration and Shared local services — are in the `priis-profile` skill › *Profile fields*. Load it first; nothing here restates them.

---

## Profile fields

| Field | Value |
|-------|-------|
| **Shared fields** | See the `priis-profile` skill › *Profile fields*. |
| **Implementing ID** | Follow `.claude/skills/priis-backend-workflow/SKILL.md` › work-item intake on `origin/main` (`project-profile` › *Upstream content*): branch, commit and PR use the **Task or Bug** ID, never the parent story (or the story ID itself when no `Backend`/`Frontend`-tagged child task exists; never create tickets under `/implement-feature`). |
| **Scaffold skills** | `priis-backend-scaffold`, `priis-frontend-scaffold` |
| **Verify** | `priis-backend-verify` (incl. its architecture-tests phase), `priis-frontend-verify` (+ `npm run e2e`, which the verify skill lacks). |
| **Ship** | `priis-ship` (backend, frontend or both), `.claude/skills/_shared/workflow.md`, `priis-backend-workflow`, `priis-frontend-workflow`, `pr-desc`. Conventions in *Phase 6*. |
| **Worktree branch** | Follow `.claude/skills/_shared/workflow.md` on `origin/main` (`feature/<id>_<english-kebab-slug>`, `bugfix/`, `hotfix/`, underscore after ID; base = freshly fetched `origin/main`, or `origin/release/<major>.<minor>.X` for hotfixes). |

### Precedence overrides for delegated PRIIS skills

- `priis-ship` pushes and creates the PR right after its file prompt, passes the PR body inline, and moves the work item to `Pull Request` unconditionally. Under the orchestrator: push and PR creation wait for the ship gate; the PR body goes through a temp file (`pr-desc` › *Apply* item 3); the state transition is a tracker write.
- `priis-ship`, `priis-backend-verify` and `priis-frontend-verify` resolve the repo from the current working directory (`rev-parse --show-toplevel`, `cd frontend/source/priis-web`) when no `[worktree-context]` is handed in. Under the orchestrator they always receive the block and run against `repo-root`; the ship skill confirms the worktree's existing branch instead of `checkout -b`.

---

## Phase 0 — Intake

1. Fetch the work item per `priis-profile` › *Tracker & PR tooling* (`wit_work_item` MCP or `az boards work-item show --id <ID> --org https://dev.azure.com/<org> --expand relations --output json`).
2. Read the discussion with `wit_work_item` MCP (`action: list_comments`, `workItemId: <ID>`); `az` cannot read work-item comments here. Only when the MCP is unavailable, ask the user to paste the thread (a screenshot is fine). Also note any `product decision <date>` comments in the code; they can disagree with the thread.
3. Housekeeping to propose, never run unprompted: assign when `System.AssignedTo` is empty; move to `Active` when the state is not `Active`.
4. **Framing Gate (Step 9)**: when the ticket or project context is in Swedish, include the Swedish phrasing / translation alongside the English *Concept & Touch* for each re-phrased perspective (`implement-feature/references/framing.md`).

---

## Phase 1 — Research

References per layer, the sibling chain and the cross-cutting checks: `priis-profile` › *References per layer* and *Cross-cutting and backend↔frontend checks*.
- Entities: `sealed partial` with `Create(CreationData)` and a nested `AsyncMutations` class in its own partial file, as in `Operation` and `MatchingTicket`. Older entities still thread `IReadOnlyPriisDbContext` through static methods — do not copy that.

---

## Phase 2 — Plan

Blind-spot vectors specific to this workspace, in addition to `what-am-I-missing/references/vectors.md`: EF Core behaviour, TickerQ, SignalR and the RTK cache — read the installed source under `bin/`, `obj/` or `node_modules/` for the path the plan depends on; and any new enum member, `SystemAction`, DTO field or event that other code switches on.

---

## Phase 3 — Implement

Order: **backend → swagger snapshot → frontend**.

### Backend

- Endpoint bases in `backend/source/GR.PRIIS.API/Features/ExtendedEndpoint.cs`: `ExtendedEndpoint<TReq,TRes>`, `ExtendedEndpoint<TReq>` (no content), `ExtendedEndpointWithoutRequest[<TRes>]`, and `ExtendedCreateEndpoint<TReq,TRes,TResourceEndpoint>` for a 201 with a Location header. `Policy(...)` has single, `params`, `PolicyType` and delegatable overloads.
- Domain failures return `SystemResult.Failure(...)` / `ValidationFailures` — never throw. Error messages in Swedish.
- Raw `ExecuteUpdate[Async]` is banned (`backend/source/BannedSymbols.txt`). Use the `ExecuteUpdateAsync(setters, currentUser, ct)` overload (stamps `ChangedBy`) or `ExecuteUnauditedUpdateAsync` for non-auditable entities.
- **New `SystemAction`** (backend half): add the member in the correct numeric range with `[Display(Name = "…")]`, then add it to every role's `AllowedActions` that needs it and only those. `SystemActionTexts.cs` only maps numeric ranges to category names.
- **Migration**: follow the repo team skill `.claude/skills/priis-backend-ef-core/SKILL.md` §13 (`dotnet ef migrations add <Name> -p backend/source/GR.PRIIS.Library -s backend/source/GR.PRIIS.API`, trimmed `.Designer.cs` convention). Several migrations on the branch → `squash-ef-core-migrations` before shipping.
- **Tests** go in `backend/tests/GR.PRIIS.API.IntegrationTests` (TUnit on MTP). Minimum per endpoint: unauthenticated (`ApiWebFactory.CreateClient()`) → 401, `CreateClientAsNoAccessUserAsync(SystemAction.X)` → 403, and one happy path under `[Test, AutoRollback]`.

### Contract sync (only when the API surface changed)

The frontend reads the committed `frontend/source/priis-web/openapi/swagger.json`:
- Small change (a few schema properties or enum members): patch `openapi/swagger.json` by hand, then `npm run codegen`.
- Large change or new enum: `npm run codegen:refresh` with the API on `http://127.0.0.1:5033` (or `SWAGGER_URL`), then revert toolchain-only churn in the snapshot before committing.
- Generated output (`src/store/api/generated/*`, `e2e/generated/role-access-rules.gen.ts`, `routeTree.gen.ts`) is gitignored. Missing `src/enums/<enum>.ts` facades are scaffolded by `src/codegen/openapi-metadata/` and **must be committed**.

### Frontend

- Zod is v4, imported as `import { z } from 'zod'`; `zodResolver` from `@hookform/resolvers/zod`. Do not copy the three legacy `'zod/v4'` imports.
- Endpoint builders in `src/store/api/endpoint-builders/<domain>/index.ts`, registered with `injectEndpoints` in `api.ts`, exported via `src/store/api/index.ts`; tags in `endpoint-builders/<domain>/tags.ts` (`tagOf` in `src/store/api/tags.ts`). Cross-domain writes use `<domain>Changed()` / `<domain>Subscriptions` (frontend `docs/adr/0001`).
- Use path aliases (`~/components/form`, `~/components/buttons`, `~features/…`, `~enums`) over relative `../` imports.
- Route `staticData.type` is `'general' | 'resource' | 'tab'`; resource pages also set `pageCode` and `highlightedMenuLink`.
- Test IDs come from `e2e/test-ids.ts` via `$e2e/test-ids`.
- **New `SystemAction`** (frontend half): `src/enums/systemAction.ts` needs no edit after codegen. Add the action to `src/components/navigation/top-menu-items.ts` if it gates a menu entry and to `<ResourceDetails.Tab systemActions={[…]}>` if it gates a tab.
- Modals register through `features/modals/priis-modal-keys.ts` → `features/modals/components/priis-modals.tsx` → `openModal` from `modalSlice`.

---

## Phase 4 — Verify

- **Backend** (`priis-backend-verify`, including architecture tests): scope with `dotnet test --project backend/tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/<Class>/*"` (never `--filter`). Re-run TestContainers load drops alone with `--no-build`. **Migration check**: apply any new migration via `dotnet run --project backend/source/GR.PRIIS.CLI -- migrations -s -d` (`-d` deletes the local DB — ask the user first).
- **Frontend** (`priis-frontend-verify`; from `frontend/source/priis-web/`): `npm run organize-imports` (changed files only; never `:all`), `npm run lint`, `npm run build`, and `npm run e2e` for UI changes.
- **Backend↔frontend contract check**: `SystemAction` integer and enum metadata match on both sides, backend `SwaggerContractTests` pass, and frontend snapshot contains only the intended contract change.

---

## Phase 6 — Ship

Follow `.claude/skills/_shared/workflow.md` on `origin/main` for branch naming (`feature/<id>_<english-kebab-slug>`, `bugfix/`, `hotfix/`) and commit/PR subject format (`#<id>: <short English imperative description>`), plus these orchestrator overrides:
- **No AI-attribution trailers** (`Co-Authored-By`, `🤖 Generated with …`) in commits or PR bodies.
- **PR body**: invoke `/pr-desc --dry-run` (reads `docs/pull_request_template.md`), then follow `/implement-feature` Phase 6a (`implement-feature/references/pr-body.md`).
- **Work-item state** after the PR exists: propose `Pull Request` and run only on a yes.

---

## Quick reference

| Topic | Use | Not |
|-------|-----|-----|
| SystemAction label & grants | `[Display(Name = "…")]` on enum member + `AccessRules/Roles/<Role>AccessRules.cs` → `AllowedActions` | a texts file or static array in `UserRoleAccessRules.cs` |
| Migrations | `.claude/skills/priis-backend-ef-core/SKILL.md` §13; verify via `GR.PRIIS.CLI -- migrations -s -d` (ask before `-d`) | trusting `EnsureCreated` integration tests |
| Single test project | `dotnet test --project backend/tests/… --treenode-filter "/*/*/Class/*"` | positional directory or `--filter` |
| Swagger snapshot & imports | hand-patch small changes + `npm run codegen`; `npm run organize-imports` on changed files only | blanket `codegen:refresh` or `organize-imports:all` |
| Ship & PR body | `.claude/skills/_shared/workflow.md` + `/pr-desc --dry-run` → temp file, no AI trailers | inline `--description "…"`, Swedish title, or attribution trailers |
