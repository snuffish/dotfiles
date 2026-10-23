---
name: priis-profile
description: "[Project: GR.PRIIS] Base profile for the GR.PRIIS monorepo — the PRIIS facts every Command profile shares: workspace layout, Azure DevOps tracker and PR tooling (org, project, repository ids, MCP server and az fallbacks), pattern skills per layer, sibling chain per half, backend↔frontend contract touchpoints (SystemAction, enum metadata, swagger snapshot, SignalR), report language, known documentation drift, worktree include list, dependency hydration and shared local services. Load before any `<command>-priis-profile` (implement-feature-priis-profile, code-review-priis-profile). Load ONLY when working in the GR.PRIIS repository (its backend/ or frontend/) or the GR folder that holds it."
user-invocable: false
---

# `priis-profile` — PRIIS base profile

The PRIIS answers to the *Shared fields* of the `project-profile` Module (read it through the Command that loaded this profile). Command profiles (`implement-feature-priis-profile`, `code-review-priis-profile`) point here by field name and never restate these facts. Facts marked *verified <date>* were checked against the code on that date; when the code has moved on, follow the code and update the date here.

Workspace (*verified 2026-10-24*): one git repo, `GR.PRIIS`, at `~/Projects/GR/GR.PRIIS` by default, on `origin/main`. It holds `backend/` (.NET 10, FastEndpoints, EF Core, TUnit) and `frontend/` (React 18, TypeScript, Vite, RTK Query, TanStack Router, Playwright; the package is `frontend/source/priis-web/`), plus `devops/` (pipelines), `docs/` (PR template) and the root `.claude/skills/`. The two former repos `GR.PRIIS.Backend` and `GR.PRIIS.Frontend` were merged into it on 2026-10-20 (`25f5e64d7`). The `GR` folder above it is not a git repo; it only holds older artifacts and workspace files. A session may open either folder: artifacts go to `~/Projects/GR/` (outside the repo) whichever folder the session opened, and worktrees are created in `GR.PRIIS`.

---

## Profile fields

| Field | Value |
|-------|-------|
| **Layout** | One monorepo, `GR.PRIIS`, with two halves: `backend/` is the producer and `frontend/` consumes the committed OpenAPI snapshot. A change that spans both halves is one branch and one PR, so `pr-counterpart` finds no counterpart: report "single-repo change". Commands run from the repo root; npm scripts run from `frontend/source/priis-web/`. |
| **Tracker** | Azure DevOps Boards, org `https://grutbildning.visualstudio.com` (the repo remote's and `az devops configure`'s form; use it for every `az` call: `https://dev.azure.com/grutbildning` failed with "requires user authentication" for `az devops invoke` on 2026-10-23, though both forms worked on 2026-10-20), project `PRIIS`. CLI: `az boards`. The CLI **cannot** read work-item discussion comments here; ask the user to paste them. |
| **PR tooling** | Azure DevOps Repos, repository id `GR.PRIIS` (remote `git@ssh.dev.azure.com:v3/grutbildning/PRIIS/GR.PRIIS`; the former `GR.PRIIS.Backend` / `GR.PRIIS.Frontend` repos only hold PRs from before 2026-10-20). Prefer the `azure-devops` MCP server (`@azure-devops/mcp`, registered per user with `claude mcp add azure-devops -- npx -y @azure-devops/mcp grutbildning`; no repo config ships it) over the `az` CLI, which truncates multi-line text on Windows: `repo_pull_request` get/list (`includeWorkItemRefs: true`), `repo_pull_request_thread` list, `wit_work_item` get (`expand: "Relations"` and `fields` are mutually exclusive — two calls for task → parent story). Writes live in the separate `*_write` tools. Fallback: `az repos pr show`, `az repos pr work-item list`, `az boards work-item show`, and for threads `az devops invoke --org https://grutbildning.visualstudio.com --area git --resource pullRequestThreads --route-parameters project=PRIIS repositoryId=GR.PRIIS pullRequestId=<id> --api-version 7.1 -o json` (output is cp1252). |
| **PR labels** (*verified 2026-10-23*) | Owned by the repo skill `.claude/skills/priis-ship/SKILL.md` › `## Step 7 — Create draft PR`, items 2 and 3; read it from `origin/main` (`project-profile` › *Upstream content*). Items 2–3 apply; the rest of Step 7 (draft creation, work-item link and state) does not. The rule: `Backend` when `git diff --name-only origin/<target>...HEAD` has a path under `backend/`, `Frontend` for `frontend/`, `Bugfix` when the implementing work item is a Bug; a PR touching neither folder gets no area label. **Add only, never remove** (reviewers set others, such as `Waiting for reviewer`). Read: `az devops invoke --org https://grutbildning.visualstudio.com --area git --resource pullRequestLabels --route-parameters project=PRIIS repositoryId=GR.PRIIS pullRequestId=<id> --http-method GET --api-version 7.1 --query "value[].name" -o tsv`. Add one: the same with `--http-method POST --in-file <file>`, the file holding `{"name": "<label>"}`. Use this REST endpoint, as `priis-ship` does, rather than the MCP `repo_pull_request_write` `labels` field, whose add-or-replace behaviour on update is unverified. `priis-ship` writes these commands with `--org https://dev.azure.com/grutbildning`; use the *Tracker* org instead (verified with these exact commands on !18785, 2026-10-23). |
| **Pattern skills per layer** | See *Pattern skills* below. |
| **Sibling chain** | `backend/`: endpoint → library/entity method → entity + EF configuration → integration test class. `frontend/`: route file → feature component → endpoint builder + tags → schema → e2e test IDs. |
| **Contract touchpoints** | `SystemAction` integer values, `[EmitOpenApiMetadata]` enum metadata (`x-enumMetadata`), `x-roleAccessRules`, the committed `openapi/swagger.json` snapshot, the SignalR hub URL `/realtime/account`, Swedish (`sv-SE`) UI text with English URL paths. Details in *Cross-cutting and cross-repo checks* below. |
| **Plan-review checks** | Read by `/plan-review` › *Step 2*, one item per pillar. **Architecture:** domain logic in entities or nested `AsyncMutations` services, not in endpoints or DTOs. **Conventions:** classes `sealed` by default; interfaces only for external I/O or Library boundaries; endpoints on `ExtendedEndpoint` / `ExtendedCreateEndpoint` with `Policy(SystemAction…)`, returning `SystemResult`; reads use `.Select()` projections, not `.Include()` chains; frontend uses Radix UI themes, React Hook Form + Zod (`from 'zod'`, `zodResolver` from `@hookform/resolvers/zod`), TanStack Router file-based routes and the central test ids. **Security:** a `SystemAction` policy on every endpoint; scoped reads through `.ApplyAccessRules()` or delegation rules. **Edge cases:** validation messages in Swedish (`sv-SE`); temporal tables and concurrency handled. **Tests:** integration tests on TUnit with Testcontainers and `AutoRollback`, covering authorized, forbidden and unauthenticated flows. |
| **Report language** | English for artifacts, PR descriptions, commits and posted comments — the language of the rulebook. Switch to Swedish only when the user writes in Swedish or asks for it. Swedish UI copy, validation messages and acceptance-criteria lines are quoted verbatim inside the English text. |
| **Known drift** | The repo-root `.claude/skills/` of `GR.PRIIS` is the upstream: its skills use the monorepo paths and load in every session started in the repo. The registry copies under `~/.terminal/skills/Projects/GR.PRIIS/priis-*` (other than the profiles) date from 2026-10-19, before the merge, and still use the old repo paths; follow the repo copy where they differ (*verified 2026-10-23*). `priis-backend-dry` and `priis-backend-migrate-to-tunit` exist only in the registry, and `priis-fullstack-review`, `priis-ship` and `priis-local-env` only in the repo. The backend scaffold template shows `CreateClientAndLoginAsNoAccessUserAsync` (gone). Three legacy `'zod/v4'` imports remain in the frontend. Older entities thread `IReadOnlyPriisDbContext` through static methods. Follow the code. |
| **Worktree include list** (*verified 2026-10-23*) | Backend, all gitignored by `backend/.gitignore`: `backend/source/GR.PRIIS.API/appsettings.local.json`, `backend/source/GR.PRIIS.CLI/appsettings.local.json`, `backend/source/GR.PRIIS.Worker/appsettings.local.json` — copy from the main checkout when they exist, or the integration suite targets the default connection string. Frontend: none — every `frontend/source/priis-web/.env*` file is tracked. Do not copy `.claude/settings.local.json`. |
| **Dependency hydration** | Frontend: `(cd <repo-root>/frontend/source/priis-web && npm ci)` (~460 MB, minutes). Backend: none — `dotnet build` restores. Dependency symlinking: **off** (a lockfile change on the branch would otherwise mutate the main checkout's install); enable here if it is ever wanted. |
| **Shared local services** | The API on `http://127.0.0.1:5033` (contract sync, `codegen:refresh`), the Playwright dev server, and the local SQL database the integration suite uses. Shared between worktrees and with the user's own running app: a second concurrent run in the repo verifies with targeted suites only and says so. |

---

## Pattern skills

| Scope | Load |
|-------|------|
| Backend — endpoint or library change | `priis-backend-fastendpoints`, `priis-backend-ef-core`, `modern-csharp`, `priis-backend-testing` |
| Backend — background job / event / notification | `priis-backend-ef-core`, `priis-backend-notifications`, `modern-csharp` |
| Backend — realtime | `priis-backend-signalr` |
| Backend — refactor | The endpoint or library row above (`priis-backend-dry` is registry-only and not in the session's skill list) |
| Frontend — feature or page | `priis-frontend-component-patterns`, `priis-frontend-forms`, `priis-frontend-rtk-query`, `priis-frontend-routing`, `priis-frontend-testing`, `typescript-conventions` |

Load each skill by the name the session lists, which comes from the repo-root `.claude/skills/` (*Known drift*). The repo also carries `priis-backend-modern-csharp`; the general `modern-csharp` reference covers the same ground. A change that spans both halves is reviewed with `priis-fullstack-review`.

---

## Cross-cutting and backend↔frontend checks

| Concern | Where it lives | Consequence |
|---------|----------------|-------------|
| New `SystemAction` | Enum: `backend/source/GR.PRIIS.Library/Common/Users/AccessRules/Actions/SystemAction.cs` (`[Display(Name = "…")]` is the Swedish label). Grants: `AccessRules/Roles/<Role>AccessRules.cs` → `AllowedActions`. Frontend: `src/enums/systemAction.ts`. | Both halves, in the same PR. |
| Entity change | Entity + `backend/source/GR.PRIIS.Library/DataAccess/Migrations` | A migration; integration tests do not run migrations. |
| API shape change (request/response/enum) | `frontend/source/priis-web/openapi/swagger.json` snapshot | Contract sync; the same PR updates the snapshot. |
| Enum exposed to the frontend | `[EmitOpenApiMetadata]` on the backend enum; frontend facade `src/enums/<enum>.ts` is scaffolded on first codegen | Both halves. |
| SignalR hub URL `/realtime/account` | Fixed contract | Do not change without changing both halves. |
| Notification / job | `priis-backend-notifications` | TickerQ job + handler + definition. |

Cross-layer mapping for this stack (`core` › *Codebase investigation*): backend ↔ frontend means DTO synchronization, route paths, payload serialization and the RTK Query hooks; domain ↔ persistence means EF Core mappings, migrations, foreign keys and validation rules.

Recorded team decision: frontend and backend always deploy together, so version skew between the two is not a defect.
