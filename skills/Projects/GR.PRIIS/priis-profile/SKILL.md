---
name: priis-profile
description: "[Project: GR.PRIIS] Base profile for the GR workspace — the PRIIS facts every Command profile shares: workspace layout, Azure DevOps tracker and PR tooling (org, project, repository ids, MCP server and az fallbacks), pattern skills per layer, sibling chain per repo, cross-repo contract touchpoints (SystemAction, enum metadata, swagger snapshot, SignalR), report language, known documentation drift, worktree include list, dependency hydration and shared local services. Load before any `<command>-priis-profile` (implement-feature-priis-profile, code-review-priis-profile). Load ONLY when working on the GR.PRIIS.Backend or GR.PRIIS.Frontend project or in the GR repository."
user-invocable: false
---

# `priis-profile` — PRIIS base profile

The PRIIS answers to the *Shared fields* of the `project-profile` Module (read it through the Command that loaded this profile). Command profiles (`implement-feature-priis-profile`, `code-review-priis-profile`) point here by field name and never restate these facts. Facts marked *verified <date>* were checked against the code on that date; when the code has moved on, follow the code and update the date here.

Workspace: the `GR` folder that holds both product repos, `~/Projects/GR` by default (workspace root; itself a git repo that tracks only workspace files such as `.agents/` and `.github/`, and **ignores** both product directories — so it is a shell for `git-worktrees` repo resolution, and worktrees are created per product repo) holding `GR.PRIIS.Backend/` (.NET 10, FastEndpoints, EF Core, TUnit) and `GR.PRIIS.Frontend/` (React 18, TypeScript, Vite, RTK Query, TanStack Router, Playwright), each its own git repo on `origin/main`. Artifacts go to the workspace root.

---

## Profile fields

| Field | Value |
|-------|-------|
| **Layout** | Two repos under one workspace root. Backend is the producer; frontend consumes the committed OpenAPI snapshot. |
| **Tracker** | Azure DevOps Boards, org `https://grutbildning.visualstudio.com` (the repo remote's and `az devops configure`'s form; `https://dev.azure.com/grutbildning` works too, both verified 2026-10-20), project `PRIIS`. CLI: `az boards`. The CLI **cannot** read work-item discussion comments here; ask the user to paste them. |
| **PR tooling** | Azure DevOps Repos, repository ids `GR.PRIIS.Backend` and `GR.PRIIS.Frontend`. Prefer the `azure-devops` MCP server (`@azure-devops/mcp`, registered per user with `claude mcp add azure-devops -- npx -y @azure-devops/mcp grutbildning`; no repo config ships it) over the `az` CLI, which truncates multi-line text on Windows: `repo_pull_request` get/list (`includeWorkItemRefs: true`), `repo_pull_request_thread` list, `wit_work_item` get (`expand: "Relations"` and `fields` are mutually exclusive — two calls for task → parent story). Writes live in the separate `*_write` tools. Fallback: `az repos pr show`, `az repos pr work-item list`, `az boards work-item show`, and for threads `az devops invoke --org https://dev.azure.com/grutbildning --area git --resource pullRequestThreads --route-parameters project=PRIIS repositoryId=<repo> pullRequestId=<id> --api-version 7.1 -o json` (output is cp1252). |
| **Pattern skills per layer** | See *Pattern skills* below. |
| **Sibling chain** | Backend: endpoint → library/entity method → entity + EF configuration → integration test class. Frontend: route file → feature component → endpoint builder + tags → schema → e2e test IDs. |
| **Contract touchpoints** | `SystemAction` integer values, `[EmitOpenApiMetadata]` enum metadata (`x-enumMetadata`), `x-roleAccessRules`, the committed `openapi/swagger.json` snapshot, the SignalR hub URL `/realtime/account`, Swedish (`sv-SE`) UI text with English URL paths. Details in *Cross-cutting and cross-repo checks* below. |
| **Plan-review checks** | Read by `/plan-review` › *Step 2*, one item per pillar. **Architecture:** domain logic in entities or nested `AsyncMutations` services, not in endpoints or DTOs. **Conventions:** classes `sealed` by default; interfaces only for external I/O or Library boundaries; endpoints on `ExtendedEndpoint` / `ExtendedCreateEndpoint` with `Policy(SystemAction…)`, returning `SystemResult`; reads use `.Select()` projections, not `.Include()` chains; frontend uses Radix UI themes, React Hook Form + Zod (`from 'zod'`, `zodResolver` from `@hookform/resolvers/zod`), TanStack Router file-based routes and the central test ids. **Security:** a `SystemAction` policy on every endpoint; scoped reads through `.ApplyAccessRules()` or delegation rules. **Edge cases:** validation messages in Swedish (`sv-SE`); temporal tables and concurrency handled. **Tests:** integration tests on TUnit with Testcontainers and `AutoRollback`, covering authorized, forbidden and unauthenticated flows. |
| **Report language** | English for artifacts, PR descriptions, commits and posted comments — the language of the rulebook. Switch to Swedish only when the user writes in Swedish or asks for it. Swedish UI copy, validation messages and acceptance-criteria lines are quoted verbatim inside the English text. |
| **Known drift** | Repo-local `<repo>/.claude/commands/`, both `.github/copilot-instructions.md` files and the repo-local `.claude/skills/` **other than** `priis-backend-review` / `priis-frontend-review` are stale and diverge from the registry skills. The two review skills are the reverse: the repo-local copies on `origin/main` are the upstream, and the registry copies mirror them (synced 2026-10-19). The backend scaffold template shows `CreateClientAndLoginAsNoAccessUserAsync` (gone). Three legacy `'zod/v4'` imports remain in the frontend. Older entities thread `IReadOnlyPriisDbContext` through static methods. Follow the code. |
| **Worktree include list** (*verified 2026-10-16*) | Backend, all gitignored: `source/GR.PRIIS.API/appsettings.local.json`, `source/GR.PRIIS.CLI/appsettings.local.json`, `source/GR.PRIIS.Worker/appsettings.local.json` — copy from the main checkout or the integration suite targets the default connection string. Frontend: none — every `source/priis-web/.env*` file is tracked. Do not copy `.claude/settings.local.json`. |
| **Dependency hydration** | Frontend: `(cd <repo-root>/source/priis-web && npm ci)` (~460 MB, minutes). Backend: none — `dotnet build` restores. Dependency symlinking: **off** (a lockfile change on the branch would otherwise mutate the main checkout's install); enable here if it is ever wanted. |
| **Shared local services** | The API on `http://127.0.0.1:5033` (contract sync, `codegen:refresh`), the Playwright dev server, and the local SQL database the integration suite uses. Shared between worktrees and with the user's own running app: a second concurrent run of the same repo verifies with targeted suites only and says so. |

---

## Pattern skills

| Scope | Load |
|-------|------|
| Backend — endpoint or library change | `priis-backend-fastendpoints`, `priis-backend-ef-core`, `modern-csharp`, `priis-backend-testing` |
| Backend — background job / event / notification | `priis-backend-ef-core`, `priis-backend-notifications`, `modern-csharp` |
| Backend — realtime | `priis-backend-signalr` |
| Backend — refactor | `priis-backend-dry` plus the above |
| Frontend — feature or page | `priis-frontend-component-patterns`, `priis-frontend-forms`, `priis-frontend-rtk-query`, `priis-frontend-routing`, `priis-frontend-testing`, `typescript-conventions` |

The registry names are the ones to load. Repo-local copies may carry other names (`priis-backend-modern-csharp`); do not follow those.

---

## Cross-cutting and cross-repo checks

| Concern | Where it lives | Consequence |
|---------|----------------|-------------|
| New `SystemAction` | Enum: `source/GR.PRIIS.Library/Common/Users/AccessRules/Actions/SystemAction.cs` (`[Display(Name = "…")]` is the Swedish label). Grants: `AccessRules/Roles/<Role>AccessRules.cs` → `AllowedActions`. | Two-repo change. |
| Entity change | Entity + `source/GR.PRIIS.Library/DataAccess/Migrations` | A migration; integration tests do not run migrations. |
| API shape change (request/response/enum) | Frontend `source/priis-web/openapi/swagger.json` snapshot | Contract sync; backend PR merges first or the frontend branch carries the snapshot. |
| Enum exposed to the frontend | `[EmitOpenApiMetadata]` on the backend enum; frontend facade `src/enums/<enum>.ts` is scaffolded on first codegen | Both repos. |
| SignalR hub URL `/realtime/account` | Fixed contract | Do not change without coordinating both repos. |
| Notification / job | `priis-backend-notifications` | TickerQ job + handler + definition. |

Cross-layer mapping for this stack (`core` › *Codebase investigation*): backend ↔ frontend means DTO synchronization, route paths, payload serialization and the RTK Query hooks; domain ↔ persistence means EF Core mappings, migrations, foreign keys and validation rules.

Recorded team decision: frontend and backend always deploy together, so version skew between the two is not a defect.
