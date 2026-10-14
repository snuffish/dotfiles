---
name: implement-feature
description: "[Project: GR.PRIIS] Orchestrator for implementing a feature, task or bug end-to-end in the PRIIS workspace — work-item intake, research, plan, implementation, verification, self-review, shipping and walkthrough. Owns the sequence, the approval gates and when to fan out sub-agents; delegates patterns and commands to the investigate / plan / scaffold / verify / review / ship skills instead of duplicating them. Load when the user asks to implement a feature, work item or user story. Load ONLY when working in the GR repository."
---

# /implement-feature — End-to-End Feature Implementation

Runs one feature from ADO work item to draft pull request across `GR.PRIIS.Backend` and/or `GR.PRIIS.Frontend`.
This skill owns **the order of phases, the gates between them, and where sub-agents are used**. Everything else — endpoint shape,
query patterns, form wiring, test helpers, git and ADO commands — lives in the skills it delegates to.
Load those skills and read a sibling implementation in the repo; never reproduce pattern code from memory.

Usage: `/implement-feature <work-item-id>` or `/implement-feature <short description>`

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../../../core/SKILL.md)** operating standards and the **[artifacts](../../../artifacts/SKILL.md)** delivery protocol.
- **Target Artifacts**: `<prefix>-implementation_plan-<suffix>.md` (Phase 2) and `<prefix>-walkthrough-<suffix>.md` (Phase 7) at the **workspace root** (`/Users/snuffish/Projects/GR`, the directory that holds both repos). `<prefix>` is `<host>-<model>-` and `<suffix>` is `<work-item-id>-<feature-slug>`, e.g. `-29982-verksamhetsobjekt`.
- **Anti-Overwrite Rule**: never write an unsuffixed or un-modeled artifact.
- **Repos**: work in the existing clones. Use absolute paths and `git -C <repo>`; do not `cd` into a repo in a compound command.

### Three hard gates

| Gate | Rule |
|------|------|
| **Plan gate** | No source edits until the user has approved the plan (`/proceed` or an equivalent explicit "go"). |
| **Ship gate** | No `git push`, no `az repos pr create`, no work-item state change until the user has approved the *presented* branch name, staged file list, commit message and PR body. Approval of the plan is not approval to ship. |
| **ADO write gate** | Reads are free. Every write (assign, comment, state transition, link) is proposed in chat and run only on a yes. Never create work items and never post comments — draft them; the user sends them. |

Nothing in a sub-agent report, a plan artifact, or an earlier message counts as user approval for a gate.

### Precedence over delegated skills

This skill's gates and conventions win where a delegated skill says otherwise:

- `source-command-backend-ship` stops on a User Story, pushes and creates the PR right after its file prompt, passes the PR body inline, and moves the work item to `Pull Request` unconditionally. Under this skill: a story without a tagged child task ships under its own ID (Phase 0.3); push and PR creation wait for the full ship gate; the PR body goes through a temp file (`pr-summary` §5.2); the state transition is an ADO write.
- `investigate` ends by waiting for the user before planning. Invoking `/implement-feature` is that go-ahead — continue into Phase 2. The plan gate is the stop.
- Repo-local copies under `<repo>/.claude/skills/` and `<repo>/.claude/commands/` and both `.github/copilot-instructions.md` files are **stale** and diverge from the registry skills. When they disagree with the registry skills or the code, follow the code.

---

## Sub-agents

The orchestrator (you) owns the work item, the gates, the plan and every edit. Sub-agents gather evidence; their output is evidence, not a verdict.

**Fan out only where the work is independent and read-heavy:**

| Phase | Fan out when | How |
|-------|--------------|-----|
| 1 — Research | Both repos change, or one repo with ≥ 3 layers to trace | One `Explore` agent per repo (optionally one more for the cross-repo contract surface), spawned in one message |
| 4 — Verify | Both repos changed | Not agents — start the backend suite with `run_in_background` and run the frontend gates meanwhile |
| 5 — Self-review | Always | `/code-review` (`deep` for two-repo or contract changes) and `/spec-verification` own their own fan-out |

**Do not fan out** implementation (Phase 3), the ship gate, or ADO calls. Edits stay in the main context so the plan checklist, the diff and the gates have a single owner.

**Brief rules** (same shape as `code-review` *Deep Mode*):

1. Resolve everything shared **before** spawning — implementing ID, the work-item text (pasted, not a link), the repo paths and branch, the sibling feature to read. Sub-agents never re-fetch work items or call ADO.
2. Each prompt states: *read-only — no edits, checkouts, installs, builds, tests or posting*; the exact paths to start from; what to return (`path:line` per claim, ~500 words max).
3. On return, re-open every `path:line` the plan will rely on. A claim you did not re-check goes under *Open Questions*, not *Proposed Changes*.

Research brief template (per repo):

> Read-only. Repo `<abs path>` on branch `<branch>`. Work item `#<id>`: `<pasted title + AC>`. Trace the nearest sibling feature `<name>` through every layer — <backend: endpoint → library/entity method → entity + EF configuration → integration test class | frontend: route file → feature component → endpoint builder + tags → schema → e2e test IDs>. Report: the files the change will touch with `path:line`, the pattern each one follows (and which of two competing patterns is newer), contract touchpoints (`SystemAction`, enum metadata, swagger snapshot, SignalR), and anything in the AC the code cannot support yet. Under 500 words.

---

## Delegation map

| Need | Load |
|------|------|
| Deep research before planning | [`/investigate`](../../../investigate/SKILL.md) |
| Blind-spot pass on the plan | `what-am-I-missing` |
| Plan artifact conventions, status, links | [`/plan`](../../../plan/SKILL.md) |
| Backend endpoint / library / test patterns | `backend-fastendpoints`, `backend-ef-core`, `backend-testing`, `modern-csharp` |
| Backend notifications, jobs, realtime | `backend-notifications`, `backend-signalr` |
| Backend refactor / duplication | `backend-dry` |
| Backend feature-slice generation | `source-command-backend-scaffold` |
| Several migrations on one branch | `squash-ef-core-migrations` |
| Frontend component / form / data / route patterns | `frontend-component-patterns`, `frontend-forms`, `frontend-rtk-query`, `frontend-routing` |
| Frontend e2e test IDs and specs | `frontend-testing` |
| Frontend feature-slice generation | `source-command-frontend-scaffold` |
| Quality gates | `source-command-backend-verify`, `source-command-frontend-verify` |
| Self-review against code and story | `code-review`, `spec-verification` |
| Git + ADO conventions | `backend-workflow`, `frontend-workflow` |
| Branch, commit, push, draft PR | `source-command-backend-ship` (covers both repos; see *Precedence*) |
| PR body | `pr-summary` |
| Manual test steps | `manual-testing` |
| CI red after the PR is open | `pr-fix-pipeline` |

---

## Phase 0 — Intake

1. **Fetch the work item** (read-only; the org is always `https://dev.azure.com/grutbildning`, never the `visualstudio.com` host):

   ```bash
   az boards work-item show --id <ID> --org https://dev.azure.com/grutbildning --expand relations --output json
   ```

2. **Get the discussion thread from the user.** The az CLI cannot read work-item comments here (`az devops invoke … comments` fails to parse the preview API version; `az rest` returns the sign-in page). Planning decisions — and the real remaining work on a story reopened after testing — often live only there. Ask the user to paste the discussion (a screenshot is fine) and say in the scope statement whether you have it. Also note any `product decision <date>` comments in the code; they can disagree with the thread.

3. **Resolve the implementing ID.** Branch, commit and PR use the **Task or Bug** ID, never the parent story. For a User Story, look for a `Backend` / `Frontend`-tagged child task in the relations; if none exists use the story ID itself. Do not create one.

4. **Resolve scope.** Backend only, frontend only, or both; which feature domain folders; whether the acceptance criteria imply UI, API, notification, permission or data changes.

5. **Offer ADO housekeeping, do not perform it.** If `System.AssignedTo` is empty or the state is not `Active`, say so and propose the exact commands. Run them only on a yes.

6. **Write a scope statement** in chat: one paragraph naming the implementing ID, the repos touched, the domains, whether the discussion thread was read, and anything the work item leaves ambiguous.

---

## Phase 1 — Research

Research is read-only. If the domain is unfamiliar, there is more than one viable design, or a cross-repo contract (below) changes, run **`/investigate <suffix>`** and build the plan on its *Plan Seed*. Otherwise do the lightweight pass here — fanned out per repo when *Sub-agents* says so.

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
- When two patterns compete, copy the newer one. Entities: `sealed partial` with `Create(CreationData)` and a nested `AsyncMutations` class in its own partial file, as in `Operation` and `MatchingTicket`; older entities still thread `IReadOnlyPriisDbContext` through static methods — do not copy that.

### 1c. Cross-cutting and cross-repo checks

| Concern | Where it lives | Consequence |
|---------|----------------|-------------|
| New `SystemAction` | Enum: `source/GR.PRIIS.Library/Common/Users/AccessRules/Actions/SystemAction.cs` (`[Display(Name = "…")]` is the Swedish label). Grants: `AccessRules/Roles/<Role>AccessRules.cs` → `AllowedActions`. | Two-repo change — see Phase 3. |
| Entity change | Entity + `source/GR.PRIIS.Library/DataAccess/Migrations` | Migration step in the plan, plus the migration check in Phase 4 (tests do not run migrations). |
| API shape change (request/response/enum) | Frontend `source/priis-web/openapi/swagger.json` snapshot | Contract-sync step in the plan; backend PR merges first or the frontend branch carries the snapshot. |
| Enum exposed to the frontend | `[EmitOpenApiMetadata]` on the backend enum; frontend facade `src/enums/<enum>.ts` is scaffolded on first codegen | Both repos. |
| SignalR hub URL `/realtime/account` | Fixed contract | Do not change without coordinating both repos. |
| Notification / job | `backend-notifications` | TickerQ job + handler + definition. |

---

## Phase 2 — Implementation Plan

Write `<prefix>-implementation_plan-<suffix>.md` at the workspace root following `/plan`. Required sections:

```markdown
# <Feature name> (#<id>)

## Context & Goal
## User Review Required            <!-- breaking changes, migrations, irreversible steps, as > [!WARNING] -->
## Open Questions                  <!-- incl. unverified sub-agent claims and anything awaiting the ADO discussion -->
## Proposed Changes
### Backend — [NEW|MODIFY|DELETE] <path> — what and why
### Frontend — [NEW|MODIFY|DELETE] <path> — what and why
### Cross-repo order               <!-- which PR first, what the second one depends on -->
## Task Checklist                  <!-- the live checklist; tick items here during Phase 3 -->
## Verification Plan               <!-- exact commands, migration check, manual steps, e2e specs to run -->

**Status:** Awaiting User Review
```

The *Task Checklist* inside the plan is the working checklist — there is no separate task file. Mark items `[/]` when started and `[x]` when done. Status values are `/plan`'s: `Draft` → `Awaiting User Review` → `Approved` → `Completed`.

For a two-repo or contract-changing plan, run `what-am-I-missing <suffix>` before presenting and fold its finding into *Open Questions*.

Present the clickable link plus the open questions and decisions. **Stop here until the user approves.**

---

## Phase 3 — Implement

Order of work when both repos change: **backend → swagger snapshot → frontend**. Keep the plan's checklist ticked as you go. No sub-agents in this phase.

### Backend

Load `source-command-backend-scaffold` for a new slice, or edit the sibling you read in Phase 1. Facts the scaffold and older docs get wrong (verified 2026-10-14):

- Endpoint bases in `source/GR.PRIIS.API/Features/ExtendedEndpoint.cs`: `ExtendedEndpoint<TReq,TRes>`, `ExtendedEndpoint<TReq>` (no content), `ExtendedEndpointWithoutRequest[<TRes>]`, and `ExtendedCreateEndpoint<TReq,TRes,TResourceEndpoint>` for a 201 with a Location header. `Policy(...)` has single, `params`, `PolicyType` and delegatable overloads.
- Domain failures return `SystemResult.Failure(...)` / `ValidationFailures` — never throw. Error messages in Swedish.
- Raw `ExecuteUpdate[Async]` is banned (`source/BannedSymbols.txt`). Use the `ExecuteUpdateAsync(setters, currentUser, ct)` overload (stamps `ChangedBy`) or `ExecuteUnauditedUpdateAsync` for non-auditable entities.
- **New `SystemAction`** (backend half): add the member in the correct numeric range with `[Display(Name = "…")]`, then add it to every role's `AllowedActions` that needs it and only those. `SystemActionTexts.cs` only maps numeric ranges to category names.
- **Migration** (from the backend repo root; `dotnet-ef` is a local tool): `dotnet ef migrations add <Name> -p source/GR.PRIIS.Library -s source/GR.PRIIS.API`. Review the generated file. Several migrations on the branch → `squash-ef-core-migrations` before shipping.
- **Tests** go in `tests/GR.PRIIS.API.IntegrationTests` (TUnit on MTP). Minimum per endpoint: unauthenticated (`ApiWebFactory.CreateClient()`) → 401, `CreateClientAsNoAccessUserAsync(SystemAction.X)` → 403 (not `CreateClientAndLoginAsNoAccessUserAsync`, which the scaffold template still shows), and one happy path under `[Test, AutoRollback]`.

### Contract sync (only when the API surface changed)

The frontend never talks to the backend at build time; it reads the committed `source/priis-web/openapi/swagger.json`.

- Small change (a few schema properties or enum members): patch `openapi/swagger.json` by hand, then `npm run codegen`. A full `codegen:refresh` on this machine rewrites ~500 unrelated lines because the local ASP.NET runtime emits a different OpenAPI shape.
- Large change or new enum: `npm run codegen:refresh` with the API on `http://127.0.0.1:5033` (or `SWAGGER_URL`), then revert toolchain-only churn in the snapshot before committing.
- Generated output (`src/store/api/generated/*`, `e2e/generated/role-access-rules.gen.ts`, `routeTree.gen.ts`) is gitignored. Missing `src/enums/<enum>.ts` facades are scaffolded by `src/codegen/openapi-metadata/` and **must be committed** — CI fails on an uncommitted scaffold.

### Frontend

Load `source-command-frontend-scaffold` for a new slice, or edit the sibling. Facts verified 2026-10-14:

- Zod is v4, imported as `import { z } from 'zod'`; `zodResolver` from `@hookform/resolvers/zod`. Three legacy `'zod/v4'` imports remain — do not copy them.
- Endpoint builders in `src/store/api/endpoint-builders/<domain>/index.ts`, wired into `src/store/api/index.ts` (`createApi` and the hook exports). New tag types go in its `tagTypes` array; `Tags` / `tagOf` live in `src/store/api/tags.ts`. Mutations declare `invalidatesTags`.
- Use path aliases (`~/components/form`, `~/components/buttons`, `~features/…`, `~enums`) over relative `../` imports — convention, not lint-enforced.
- Route `staticData.type` is `'general' | 'resource' | 'tab'`; resource pages also set `pageCode` and `highlightedMenuLink`.
- Test IDs come from `e2e/test-ids.ts` via `$e2e/test-ids` — the only `e2e/` import ESLint allows in `src/`.
- **New `SystemAction`** (frontend half): `src/enums/systemAction.ts` needs no edit after codegen. Add the action to the menu item's `actions` in `src/components/navigation/top-menu-items.ts` if it gates a menu entry (the check is OR — a role with no other matching action still hides the item), and to `<ResourceDetails.Tab systemActions={[…]}>` if it gates a tab.
- Modals register through `features/modals/priis-modal-keys.ts` → `features/modals/components/priis-modals.tsx` → `openModal` from `modalSlice`.

---

## Phase 4 — Verify

Run the verify skill for each touched repo and report PASS/FAIL per check. When both repos changed, start the backend test run with `run_in_background` and do the frontend gates while it runs. Do not move to Phase 5 on a FAIL.

**Backend** (`source-command-backend-verify`, including its architecture-tests phase). Where it differs from older docs:

- Scope a run with `dotnet test --project tests/GR.PRIIS.API.IntegrationTests --configuration Release --treenode-filter "/*/*/<Class>/*"` — `--project` is required on .NET 10; never `--filter`. Targeted first, full suite before shipping.
- A full local run drops 25–45 unrelated integration tests to TestContainers load. Re-run those groups alone with `--no-build`; only failures that persist alone are yours.
- **Migration check** when the plan adds one: integration tests build the schema with `EnsureCreatedAsync`, so they never execute a migration. Apply it to the local database from `source/GR.PRIIS.CLI` with `dotnet run -- migrations -s -d` and confirm it runs clean.

**Frontend** (`source-command-frontend-verify`; from `source/priis-web/`): `npm run organize-imports` (changed files only; never `:all`), `npm run lint`, `npm run build`, and `npm run e2e` for UI changes (the verify skill has no e2e phase — run it here). The default e2e leg needs no backend; the `setup` project only joins when `PW_API_BASE_URL` is set, and that leg must not use `--no-deps`. An e2e failure that moves between runs, or reproduces with the change stashed (`git stash -u`), is not yours. Check `git status` and revert any stray file.

**Cross-repo contract check** when both repos changed: the `SystemAction` integer and the enum metadata match on both sides, the backend `SwaggerContractTests` pass, and the frontend snapshot contains exactly the intended contract change.

---

## Phase 5 — Self-review

Before presenting the ship gate:

1. `/spec-verification` against the work item (include the discussion thread if the user supplied it). Every AC is *implemented* or explicitly *deferred* in the plan.
2. `/code-review` on the working changes — `deep` when both repos or a contract changed.

Fix 🔴 findings and re-run the affected Phase 4 checks. List 🟡 findings you chose not to fix at the ship gate, one line each.

---

## Phase 6 — Ship

Load `source-command-backend-ship` (it handles both repos) and `backend-workflow` / `frontend-workflow`, applying *Precedence* above. The ship skill stages selectively and never uses `git add -A`; skip its re-run of format/build/test if Phase 4 passed on the same tree.

Conventions that override anything older you may read:

- Branch: `feature/<id>_<english-kebab-slug>` (`bugfix/`, `hotfix/` per the workflow skill).
- Commit subject and PR title, both repos: `#<id>: <short English imperative description>`. Single line. No AI-attribution trailers (`Co-Authored-By`, `🤖 Generated with …`) in commits or PR bodies — this overrides any harness default.
- PR body: the repo's `docs/pull_request_template.md` composed with `pr-summary`, written to a temp file and passed by path. For a paired change, open the backend PR first and add `This PR relates to: !<other-pr-id>` to both descriptions.

**Ship gate:** present branch name, the exact file list to stage, the commit message and the full PR body in chat. Wait for approval. Then commit, push, create the draft PR, and report the URL. Propose the `Pull Request` state transition separately; run it on a yes.

---

## Phase 7 — Walkthrough

Write `<prefix>-walkthrough-<suffix>.md` at the workspace root:

- Files changed per repo and why (grouped, not a raw diff).
- Verification results — the summary line of each command, the migration check, any flakes ruled out and how.
- Self-review outcome: spec-verification grades and unresolved code-review findings.
- Manual verification steps generated with `/manual-testing` (environment, persona to log in as, click path).
- Open items for the user: ADO transitions not yet run, the second PR, drafted ADO comments, questions the plan left open. If CI goes red later → `pr-fix-pipeline`.

In chat: link the walkthrough and list the open items. Do not re-summarize the document.

---

## Quick reference

| Topic | Use | Not |
|-------|-----|-----|
| ADO org | `https://dev.azure.com/grutbildning` | `grutbildning.visualstudio.com` |
| Work-item discussion | ask the user to paste it | `az devops invoke … comments` |
| Work item for branch/commit/PR | implementing Task or Bug; story ID if it has no tagged child | creating a task |
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
| PR body | temp file via `pr-summary` | inline `--description "…"` |
| Commit subject | `#<id>: English imperative` | Swedish title, trailers |
| Task checklist | `## Task Checklist` in the plan artifact | a separate `task.md` |
