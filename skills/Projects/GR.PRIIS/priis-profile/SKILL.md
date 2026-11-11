---
name: priis-profile
description: "[Project: GR.PRIIS] Base profile for the GR.PRIIS monorepo — the PRIIS facts every Command profile shares: workspace layout, Azure DevOps tracker and PR tooling, References per layer, sibling chain per half, backend↔frontend contract touchpoints (SystemAction, enum metadata, swagger snapshot, SignalR), report language, known documentation drift, worktree include list, dependency hydration and shared local services. Load before any `<command>-priis-profile` (implement-feature-priis-profile, code-review-priis-profile). Load ONLY when working in the GR.PRIIS repository or the GR folder that holds it."
user-invocable: false
---

# `priis-profile` — PRIIS base profile

The PRIIS answers to the *Shared fields* of the `project-profile` Module (read it through the Command that loaded this profile). Command profiles (`implement-feature-priis-profile`, `code-review-priis-profile`) point here by field name and never restate these facts. Facts marked *verified <date>* were checked against the code on that date; when the code has moved on, follow the code and update the date here.

Workspace (*verified 2026-10-31*): one git repo, `GR.PRIIS`, at `~/Projects/GR/GR.PRIIS` by default, on `origin/main`. It holds `backend/` (.NET 10, FastEndpoints, EF Core, TUnit) and `frontend/` (React 18, TypeScript, Vite, RTK Query, TanStack Router, Playwright; the package is `frontend/source/priis-web/`), plus `devops/` (pipelines), `docs/` (PR template) and the root `.claude/skills/`. The two former backend and frontend repos were merged into it on 2026-10-20 (`25f5e64d7`). The `GR` folder above it is not a git repo; it only holds workspace files and artifacts. A session may open either folder: artifacts go to `<artifact-dir>` (`artifact-protocol`, here `~/.cache/agent-artifacts/GR.PRIIS/`) whichever folder the session opened, and worktrees are created in `GR.PRIIS`.

---

## Profile fields

| Field | Value |
|-------|-------|
| **Layout** | One monorepo, `GR.PRIIS`, with two halves: `backend/` is the producer and `frontend/` consumes the committed OpenAPI snapshot. A change that spans both halves is one branch and one PR, so `pr-counterpart` finds no counterpart: report "single-repo change". Commands run from the repo root; npm scripts run from `frontend/source/priis-web/`. |
| **Tracker & PR tooling** | Read the team conventions in `.claude/skills/_shared/azure-devops.md` and `.claude/skills/_shared/workflow.md` on `origin/main` (`project-profile` › *Upstream content*): Azure DevOps org `<org>` from `git remote get-url origin` (`ssh.dev.azure.com:v3/<org>/PRIIS/GR.PRIIS`), used as `https://dev.azure.com/<org>` (`https://<org>.visualstudio.com` also works; on auth error run `az login`), project `PRIIS`, repository `GR.PRIIS`, `azure-devops` MCP server + `az` CLI fallbacks (Note: `az boards` cannot read work-item discussion comments; ask the user to paste them). **Personal override:** use `az` (`az devops invoke`, `az pipelines`, `az repos pr policy`) with `--query` for bulk structured reads (thread lists, changed files, policies, builds, timelines, logs) because the MCP returns large unfiltered JSON inside an untrusted-content wrapper; keep the MCP for single PR/work-item reads and writes (`pr-post-comments/references/azure-devops-mcp.md`). |
| **PR labels** | Owned by `.claude/skills/priis-ship/SKILL.md` › `## Step 7 — Create draft PR` (items 2–3) and `.claude/skills/_shared/azure-devops.md` on `origin/main` (`Backend` for `backend/`, `Frontend` for `frontend/`, `Bugfix` when the work item is a Bug; **add only, never remove**; read/add via `az devops invoke --area git --resource pullRequestLabels`). |
| **Implementation mode** | `workspace`: edits by any Command, `/proceed` on a plan included, land in `<repo>/.claude/worktrees/<slug>` (`git-worktrees` › *Modes*); `/no-wt` opts out. |
| **References per layer** | See *References per layer* below. |
| **Sibling chain** | `backend/`: endpoint → library/entity method → entity + EF configuration → integration test class. `frontend/`: route file → feature component → endpoint builder + tags → schema → e2e test IDs. |
| **Contract touchpoints** | `SystemAction` integer values, `[EmitOpenApiMetadata]` enum metadata (`x-enumMetadata`), `x-roleAccessRules`, the committed `openapi/swagger.json` snapshot, the SignalR hub URL `/realtime/account`, Swedish (`sv-SE`) UI text with English URL paths. Details in *Cross-cutting and backend↔frontend checks* below. |
| **Plan-review checks** | Read by `/plan --review` › *Case D step 3*, one item per pillar. **Architecture:** domain logic in entities or nested `AsyncMutations` services, not in endpoints or DTOs. **Conventions:** classes `sealed` by default; interfaces only for external I/O or Library boundaries; endpoints on `ExtendedEndpoint` / `ExtendedCreateEndpoint` with `Policy(SystemAction…)`, returning `SystemResult`; reads use `.Select()` projections, not `.Include()` chains; frontend uses Radix UI themes, React Hook Form + Zod (`from 'zod'`, `zodResolver` from `@hookform/resolvers/zod`), TanStack Router file-based routes and the central test ids. **Security:** a `SystemAction` policy on every endpoint; scoped reads through `.ApplyAccessRules()` or delegation rules. **Edge cases:** validation messages in Swedish (`sv-SE`); temporal tables and concurrency handled. **Tests:** integration tests on TUnit with Testcontainers and `AutoRollback`, covering authorized, forbidden and unauthenticated flows. |
| **Post-merge checks** | Read by `/resolve-conflicts` › *Step 5*. `priis-verify`; `python3 .claude/scripts/check_skill_drift.py`. After a stale-client `TS2305` in the frontend, `npm run build` in `frontend/source/priis-web` (it regenerates the client first). |
| **Skill-review checks** | Read by `/skill-review`. Drift script `.claude/scripts/check_skill_drift.py`, claims in `.claude/skills-claims.json`. Body budget 20,000 B (advisory, `SIZE_BUDGET` in the script). CI `devops/ci-skills.yml` validates every PR to `main` with no path filter, so a STALE claim fails the PR. Repo skill text never names personal skills or tooling (`~/.terminal`, `claude-mem`, `/plan`, registry-only skills). |
| **Report language** | English for artifacts, PR descriptions, commits and posted comments — the language of the rulebook. Switch to Swedish only when the user writes in Swedish or asks for it. Swedish UI copy, validation messages and acceptance-criteria lines are quoted verbatim inside the English text. |
| **Known drift** | The repo-root `.claude/skills/` of `GR.PRIIS` is the upstream (`core` › *Precedence*, [ADR-0005](../../../../docs/adr/0005-team-skills-vs-personal-skills-boundary.md)). Three legacy `'zod/v4'` imports remain in the frontend. Older entities thread `IReadOnlyPriisDbContext` through static methods. Follow the code. |
| **Worktree include list** | Backend, all gitignored by `backend/.gitignore`: `backend/source/GR.PRIIS.API/appsettings.local.json`, `backend/source/GR.PRIIS.CLI/appsettings.local.json`, `backend/source/GR.PRIIS.Worker/appsettings.local.json` — copy from the main checkout when they exist. Frontend: none (all `.env*` files are tracked). Do not copy `.claude/settings.local.json`. |
| **Dependency hydration** | Frontend: `(cd <repo-root>/frontend/source/priis-web && npm ci)`. Backend: none — `dotnet build` restores. Dependency symlinking: **off**. |
| **Shared local services** | The API on `http://127.0.0.1:5033` (contract sync, `codegen:refresh`), the Playwright dev server, and the local SQL database the integration suite uses. Shared between worktrees and with the user's own running app: a second concurrent run in the repo verifies with targeted suites only and says so. The first Playwright run in a freshly hydrated worktree can time out on its first locator while the dev server cold-compiles; retry once warm before calling it a failure. Integration-test seed users (the default user and every seeded role user) have `HasAccessToProtectedData = true` (`backend/tests/GR.PRIIS.API.IntegrationTests/Seeding/IntegrationTestSeedData.cs`), so a test that needs a user without protected-data access creates its own; until the team's `priis-backend-testing` says so, this line is the pointer. |

---

## References per layer

| Scope | Load |
|-------|------|
| Backend — endpoint or library change | `priis-backend-fastendpoints`, `priis-backend-ef-core`, `priis-backend-modern-csharp` (plus personal `modern-csharp`), `priis-backend-testing` |
| Backend — background job / event / notification | `priis-backend-ef-core`, `priis-backend-notifications`, `priis-backend-modern-csharp` |
| Backend — realtime | `priis-backend-signalr` |
| Backend — refactor | The endpoint or library row above, plus `priis-backend-dry` |
| Frontend — feature or page | `priis-frontend-component-patterns`, `priis-frontend-forms`, `priis-frontend-rtk-query`, `priis-frontend-routing`, `priis-frontend-testing` |

Load each skill from the repo-root `.claude/skills/` (`priis-backend-dry` is registry-only). By `core` › *Precedence* ([ADR-0005](../../../../docs/adr/0005-team-skills-vs-personal-skills-boundary.md)), the team's `priis-backend-modern-csharp` wins over the personal `modern-csharp` wherever they overlap. A change in either half or both is reviewed with `priis-review` (or `/priis-verify` for quality gates).

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
