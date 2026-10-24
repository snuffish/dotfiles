---
name: priis-backend-review
description: "[Project: GR.PRIIS.Backend] Reviews backend changes against PRIIS architecture rules: FastEndpoints conventions, SystemResult error handling, EF Core query projection and tracking, FusionCache L2 safety, SystemAction authorization, and TUnit tests. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
argument-hint: "[PR id | PR URL | work item id | branch] [--base <ref>] [--live] [--comment]"
---

# /priis-backend-review — Backend code review

> Registry copy of `GR.PRIIS.Backend/.claude/skills/priis-backend-review/` @ `970b7c19` (`origin/main`, 2026-10-19). The upstream wins; `/code-review` reads the upstream directly (`code-review-priis-profile`). Re-copy when it changes.

A review here is a hunt for the things our own reviewers keep finding, not a generic lint pass. The catalog of what they found in the last ~50 PRs, with the fix that was accepted each time, is in [references/lessons-from-prs.md](references/lessons-from-prs.md). Read it once per review session; the passes below point into it.

**Invariants.** The review is read-only: no edits, no checkouts of the main working tree, no `git stash push`, no commits, no installs, builds or test runs (PR builds compile and run the tests, `/priis-backend-verify` covers format and the grep-able anti-patterns). The only git writes are `git fetch`, `git stash create` (one unreferenced commit object, nothing else) and `git worktree add/remove/prune` on a review worktree. Never start fixing what you found unless the user asks. Every Blocking or Should-fix finding is verified (Step 4) before it is reported. Posting to ADO needs explicit approval (Step 6).

`allowed-tools` pre-approves reads only: `git` as a whole (every read is `git -C <path> …`, so a sub-command prefix such as `git diff:*` never matches; the invariants above are what keeps it read-only), the `az` read commands (`pr show`, `pr list`, `pr work-item list`, `boards work-item show`) and the read-only ADO MCP tools (`repo_pull_request` get/list, `repo_pull_request_thread` list, `wit_work_item` get; the writes live in the separate `*_write` tools). Nothing that posts, resolves or votes is pre-approved, not even the `az devops invoke` fallback, so the permission prompt is a second gate behind Step 6.

---

## Usage

| Invocation | Reviews |
|-----------|---------|
| `/priis-backend-review` | The current branch vs `origin/main`: commits, staged, unstaged and untracked files. If the branch has a PR, its description, work item and threads are read too |
| `/priis-backend-review --base origin/release/2.10.X` | Same, against a release branch (hotfix branches) |
| `/priis-backend-review feature/31083_operation-response-rate-statistics` | A branch vs `origin/main` |
| `/priis-backend-review 18652`, `/priis-backend-review <PR URL>` | An Azure DevOps PR, its linked work item, existing threads and its counterpart PR in the frontend repo |
| `/priis-backend-review #31083` | The PR (or branch) of a work item |
| `--live` | Read the main checkout instead of a snapshot worktree. Only for what cannot be snapshotted |
| `--comment` | After the review, post the findings as PR threads **after explicit approval** |

---

## Step 1 — Resolve the target

Use `git -C <repo>` from the main checkout for everything in this step; never `cd && git`. `git fetch origin` first.

### 1a. Pin the head and the base

| Scope | Head to review | Source ref to record | Base |
|-------|----------------|----------------------|------|
| Working tree (default) | `SNAP=$(git stash create)`; its tree is the working tree. Empty output means the tree is clean: review the branch commits instead | `<local-branch> + working tree` | `--base`, else the PR's target if one exists, else `origin/main` |
| Branch | `git fetch origin <branch>` → `origin/<branch>` | `origin/<branch>` | `--base`, else the branch's PR target, else `origin/main` |
| PR id or URL | `git fetch origin <sourceRefName>` → `origin/<sourceRefName>` | `origin/<sourceRefName>` | the PR's `targetRefName` |
| Work item id | find its PR (`az repos pr list --status all --query "[?contains(title,'#31083')]"`, or the branch `feature/31083_*`) and continue as PR or branch | as above | as above |

Rules:
- A PR id or URL usually means the user is **not** on that branch. Say so and review the PR's head; never check it out in the main working tree.
- When no PR was given and the scope is a branch, look for its PR anyway: `az repos pr list --source-branch <branch> --status all --detect true -o json` (or `repo_pull_request list` with `sourceRefName`). A checked-out branch almost always has one, and its description is the best context a reviewer gets.
- Never use `@{u}` as the base; on a feature branch that is the branch's own remote copy and yields an empty diff. Confirm `git rev-parse <base>` resolves and `git diff <base>...<head> --stat` is non-empty **before** going further.
- `git stash create` does not capture untracked files. List them with `git ls-files --others --exclude-standard`, read them live, and mark every citation into them `(live, untracked)`.
- For the branch and PR scopes, record how the main checkout relates to the reviewed head (`git rev-list --left-right --count <head>...HEAD` → `same commit`, `local ahead N / behind M`, or `on <other-branch>`); the working-tree scope is `same commit + working tree` by construction. The report states it so the user knows whether what they see locally is what was reviewed.

### 1b. Read the PR, the work item and the threads

With the MCP tools, `project: "PRIIS"` and `repositoryId: "GR.PRIIS.Backend"`. They come from the `azure-devops` server (`@azure-devops/mcp`, registered per user with `claude mcp add azure-devops -- npx -y @azure-devops/mcp grutbildning`; no repo config ships it), which `priis-backend-workflow` already prefers over the `az` CLI because the CLI truncates multi-line text on Windows. Without the server, use the `az` fallback below.

1. `repo_pull_request` `get` with `includeWorkItemRefs: true` → title, description, branches, draft state.
2. `repo_pull_request_thread` `list` → existing threads. Count only human threads (skip `commentType: system`, the Azure Pipelines coverage bot and vote/policy threads). Skip anything already raised, and read the author's replies: they record decisions (for example "frontend and backend always deploy together") that rule out findings.
3. `wit_work_item` `get` with `expand: "Relations"` on the linked task or bug to find `System.Parent`, then a second `get` with `fields` on the parent story (the two parameters are mutually exclusive). Descriptions and acceptance criteria are HTML; strip the tags. When there is no acceptance-criteria field, say so and name what you used instead.

Fallback when the MCP server is down: `az repos pr show --id <id> --organization https://dev.azure.com/grutbildning -o json`, `az repos pr work-item list --id <id> ...`, `az boards work-item show --id <wi> ...`, and `az devops invoke --org https://dev.azure.com/grutbildning --area git --resource pullRequestThreads --route-parameters project=PRIIS repositoryId=GR.PRIIS.Backend pullRequestId=<id> --api-version 7.1 -o json` (output is cp1252; `az devops invoke` is not pre-approved, so this read prompts once). Always the `dev.azure.com` form; the `visualstudio.com` host fails authentication. If nothing can be fetched, ask the user to paste the description; never infer it from the branch slug.

### 1c. Counterpart PR — every time

A backend change usually has a frontend half with its own PR and its own work item under the same parent story. Look for it whether or not the description names it: `Frontend PR: !18658` / `This PR relates to: !18653` in the description, the parent story's other child tasks, a branch with the same id or slug in the frontend repo (`git -C <frontend> ls-remote --heads origin '*<id>*'`). The frontend checkout is normally next to this repo (`../GR.PRIIS.Frontend`); ask if it is not.

| Outcome | What it means for this review |
|---------|-------------------------------|
| Found | In scope: fetch its branch, diff `origin/main...origin/<fe-branch> -- source/priis-web/openapi/swagger.json source/priis-web/src/store/api source/priis-web/e2e` (pathspecs are resolved from the frontend repo root, where everything lives under `source/priis-web/`; a wrong pathspec matches nothing and `git diff` prints no error), read its threads. Pass D checks the two against each other in code, not against what the description claims |
| Found, excluded by the user ("backend only") | Name it in the report as not reviewed, and raise every contract the diff touches as a finding, because nobody checked the other side |
| Expected but missing (a DTO, enum or `SystemAction` changed and no frontend branch exists) | A Should-fix finding, Blocking if the product breaks at runtime without it |
| None | Write "single-repo change" in the report |

### 1d. Materialise the head in a review worktree

Review from a detached worktree under `.claude/worktrees/`, so the user can keep editing and line numbers stay stable. `--live` skips this and reads the main checkout; say so in the report and warn that edits during the review move the lines.

```bash
git worktree list                                              # a stale review-* from an interrupted run makes `add` fail: remove or `git worktree prune` it first
git worktree add --detach .claude/worktrees/review-<slug> <head>   # <head> = $SNAP, origin/<branch> or origin/<sourceRefName>; <slug> = PR id or branch slug
git -C .claude/worktrees/review-<slug> diff <base>...HEAD > <scratch>/review-<slug>.diff   # inside the worktree HEAD is the reviewed head; remote refs are shared
git -C .claude/worktrees/review-<slug> log --oneline <base>..HEAD   # working-tree scope: the top two entries are the synthetic "WIP on …" / "index on …" stash commits; take the commit list from <base>..<local-branch> instead
```

Then call `EnterWorktree` with `path: ".claude/worktrees/review-<slug>"` (an existing path, not `name`: `name` would branch a fresh worktree off `origin/main`). This works from the main session and, because the target is under `.claude/worktrees/` of the same repository, also from a subagent whose working directory was pinned at launch (the switch then affects only that agent). `ExitWorktree` cannot be called from a subagent, and a refused `EnterWorktree` is not an error: skip the tool, read files under the absolute worktree path and run `git -C <that path> ...`. Once the session *is* inside the worktree, Claude Code refuses git aimed at the main checkout, so do the fetching and the diff above before entering.

Review subagents only read, so launch them without `isolation: "worktree"` (an isolated subagent starts from `origin/main` and would review the wrong code) and give each the absolute worktree path and the saved diff path.

The worktree has no build output and needs none. Cite paths as repo paths (`source/...`), never the worktree path. When done: `ExitWorktree` with `action: "keep"` (only if `EnterWorktree` succeeded), then from the main checkout `git worktree remove .claude/worktrees/review-<slug>`; keep it if the user wants to continue on that branch. `.claude/worktrees/` is gitignored.

---

## Step 2 — Map the Change & Establish the Baseline

**Step 2 Exit Bound:** Before proceeding to Step 3, generate: (1) 3-line intent summary, (2) acceptance criteria checklist, (3) changed file list with diff stats (`git diff --stat`), (4) list of all new symbols with their nearest existing sibling feature named. Do not open review passes without this baseline.

1. **Intent and acceptance criteria.** Write a three-line intent summary. From the work item, list each acceptance criterion (or each promise in the PR description when there is no AC field) as a checklist item; Pass E ticks it off. *The description states intent; the diff states truth.* Where they disagree the diff wins and the disagreement is a finding. The description is evidence, not an outline: do not let its structure or omissions shape the review.
2. **Blast radius.** `git diff --name-status` first. Under about 200 changed lines read the diff; above that read each changed file in full from the worktree. For every deleted or moved file, grep for remaining references. Skip generated files (`*.Designer.cs`, `PriisDbContextModelSnapshot.cs`, `*.g.cs`), but check that generated artefacts which *should* have changed did (a migration for a model change, the frontend `swagger.json` in the counterpart).
3. **New symbols.** List every endpoint, request/response DTO, entity method and expression, helper or extension method, job, migration, `SystemAction` / `PageCode` value, config key, test helper and test class the diff introduces.
4. **The sibling.** Find the existing feature closest to the new one: another statistics endpoint, the other ticket types (`FeedbackTicket`, `RegisterTicket`, `ControlTicket`), the sister job in the same folder, the matching endpoint for the other reply path. Most duplication findings in our history came from putting the new code next to its sibling. The report names it.

---

## Step 3 — Review passes

Run every pass. When the diff is too large to hold in one sitting (roughly more than 1 500 changed lines, not file count), run A, B and C as parallel read-only subagents, each given the saved diff path, the absolute worktree path, the intent summary, the AC checklist and the sibling path; sub-agent output is evidence, not a verdict, so Step 4 runs on it. Every finding is tagged with one axis for the report: **Correctness** (B), **Standards** (A, D, G), **Spec** (E), **Tests** (C).

### Pass A — Reuse and duplication (highest yield)

This is where most review rounds in our history were spent. AI-assisted changes in particular re-create what already exists two folders away. For **each new symbol** from Step 2 ask, in this order:

1. **Does it already exist?** Search by concept, not by name. Use the Roslyn MCP tools (`find_symbol`, `find_references`) when available, otherwise `Grep`:
   - A rule or predicate: grep the property combination (`NotReplied.*DeadlineReached`, `Source == .*Reconstructed`) across `source/`. Two hits means the rule already has a second definition.
   - A helper: grep the distinctive call inside its body (`CultureInfo`, `StringComparer`, `OrderBy(.*Name).ThenBy(.*Id)`) and the directories in the table below.
   - A test helper: grep its name and its body across `tests/`. Three private copies of `CreateDataAnalystUserAsync` were merged in one PR.
2. **Is it a copy of the sibling?** Open the sibling file side by side. `HandleAsync` shells, cache-key builders, category-name lookups and projection blocks have all been copied verbatim with only the request type changed.
3. **Should the existing infrastructure have been used instead?** The second most common finding: new code that re-implements a base class, helper or convention.

| Need | Already exists | Do not accept |
|------|---------------|---------------|
| Query predicate or projection used by 2+ queries | `static Expression<...>` on the entity, used via `.Invoke(...)` and inlined by `ExpandingQueryExpressionInterceptor` — e.g. `MatchingSelectionContractUsedArticle.IsApproximate`, `BaseContract.ContractNumberExpression()`, `RegisterTicket.TargetIsProtectedHousingExpression(dbContext)` | The same lambda inline in several endpoints, or a comment saying "same ordering as X" |
| Create endpoint | `ExtendedCreateEndpoint` + `SendCreatedAndSaveChangesAsync(..., afterSave:)` | Hand-rolled save + 201 + event publish |
| Endpoint returning a `SystemResult` | `SendAndSaveChangesAsync(result, dbContext, ct)` / `SendAsync` | `if (result.IsFailure) { SendErrorsAsync…; return; } SaveChanges…; Send…` |
| Entity id in a nested route | `Route<Guid>(RouteParameterX)` constant; body carries only the payload | `Id` duplicated in the request body |
| Statistics report | `GlobalStatisticsReports.GetOrSetReportAsync` / `GetCategoryNamesAsync`, `StatisticsPeriodResolver` | Private cache key, duration and category lookup per endpoint |
| Ignoring a query filter | `PriisDbContext.CategoryProtectionQueryFilter` constant | Magic string `"CategoryProtection"` |
| Unique-index race | `catch (UniqueConstraintException ex) when (ex.Entries.Any(e => e.Entity == x))` (`UseExceptionProcessor` is on) | Matching `SqlException.Number` by hand |
| Bulk update | `ExecuteUpdateAsync(setters, currentUser)`, `dbContext.QueueUpdate(...)`, `ExecuteUnauditedUpdateAsync` | `#pragma warning disable RS0030` in feature code; `TransactionScope` around `SaveChanges` + `ExecuteUpdateAsync` |
| L2-cached external lookup | `DistributedResultCache` | A new FusionCache wrapper |
| String, date, collection, search helpers | `Library/Common/Extensions`, `Common/Collections`, `Common/Time`, `Common/TextMatching.cs`, `Common/*Constants.cs` | A private `static` copy in a feature folder |
| Test data | `tests/GR.PRIIS.API.IntegrationTests/TestDataHelpers/*` (`TestDataUserHelper`, `TestDataStatisticsHelper`, `TestDataMatchingHelper`, `RegisterTicketTestData`, `*ForTest` setters) | Reflection (`GetProperty(...).SetValue`) or private helpers that exist in another test class |

Also flag the reverse: a tiny helper, partial class or abstraction that hides more than it saves (a reflection-based column builder was replaced by two explicit mappings). "Is it worth having?" is a legitimate finding.

### Pass B — Domain correctness

Trace the paths the story did not spell out; these are the findings that reached production before. For each changed query, mutation and job:

- **Query filters.** `CategoryProtection` and `IsOpen`-style global filters apply inside nested `Any(...)` and in projections. A value the filter makes constant is dead (`Status` was always `Ongoing`). Jobs run in the Worker with protection filters off; endpoints do not. Reading ids under one filter and updating under another breaks `QueueUpdate`'s exact-count guard.
- **Protected data (Skyddat boende).** Every new list, profile, comment, assignment, notification recipient and search path must hide protected targets from users without `HasAccessToProtectedData`. A new entity reachable from an operation, contract or template needs the filter in the positive form (target exists and is not protected). Handler assignment and recipient queries need the access check too.
- **State machines.** For status transitions ask what happens on the *late* path: a reply changed after expiry, a re-lock, a cancelled selection, a retry after a failed save. Stale locked prices, prices never cleared and notifications routed by the current handler instead of the stored author all came from this.
- **Audit trail.** Raw SQL `UPDATE` on an `IAuditable` table must set `[ChangedBy]`; the analyzer only sees EF overloads. Nothing in setters may set `ChangedBy`. Data corrections use `SupportAccountId`.
- **Transactions.** Feature code uses `TransactionScope.CreatePriisDefault()` around writes only, never `Database.BeginTransactionAsync`. FusionCache L2 inside a scope needs suppression. Several `SaveChanges` with a bulk update between them is a `QueueUpdate` candidate.
- **Jobs.** A failure *after* the work is saved (event publish, notification) must not mark the run failed or rethrow the whole job. Exact-count guards make a job all-or-nothing; say so if the id set can shrink between read and write.
- **Exceptions.** Wrapping (`AggregateException`) hides the type callers match on (`UniqueConstraintException` → 409). Keep the original type.
- **Access rules.** A diff in `*AccessRules.cs` that removes an action from a role is either the story or a mistake; ask. New `SystemAction` → three sync points + frontend codegen (`/priis-backend-verify` phase 6).
- **Determinism and time.** Paged queries end with a unique tiebreaker (`.ThenBy(x => x.Id)`). Swedish sorting uses the shared comparer. Time comes from `TimeProvider`; schedules and "today" use Swedish time.
- **Performance in loops.** Loading one entity per iteration, `ChangeTracker.Entries()` per queued item, the same projection computed three times in one LINQ chain, `CultureInfo` objects created per call. Flag only on a real path (jobs over all operations, every `SaveChanges`), not a one-off CLI backfill.
- **Naming.** An `Expression` named like a `bool` (→ `...Expression`), a class named for one use when it is general (`ExternalSuggestionCache` → `DistributedResultCache`), a method doing two things, words that read as verbs (`KnownClear`). Name by behaviour; no `Service`/`Handler`/`Manager`.

### Pass C — Tests

Read every new and changed test file. The conventions are in `.claude/skills/priis-backend-testing/SKILL.md`; the review-specific checks are:

1. **Minimum coverage per endpoint.** Build the table (endpoint × 401 / 403 / happy / negative-asserts-null) for every endpoint the diff adds. Nine endpoints shipped without 401 tests in one PR. Negative tests assert `result` is null.
2. **Narrow add-on tests.** For each *new* test method, look for an existing test in the same class whose arrange is the same scenario. If one exists, the new field or branch belongs in that test, not in a copy. Signal: a new `X_WithFoo_ReturnsFoo` whose first 15 lines match `X_WithFoo_ReturnsBar`. Prefer `[Arguments(...)]` over copied methods when only inputs differ.
3. **Copied test helpers.** Private `CreateXAsync` helpers that exist in another test class → `TestDataHelpers`. Reflection into entities → a `*ForTest` method on the entity.
4. **The failing branch is tested.** A guard, catch, rollback path or the second arm of a `Lowest`/`Min` helper with no test that exercises it. Name the input no test produces.
5. **Tests that pin a bug.** A test asserting wrong behaviour as expected. Modelling legacy data is fine when the test says so.
6. **AutoRollback limits.** Temporal `AS OF` scenarios cannot be expressed inside `[AutoRollback]`; a documented NOTE is acceptable, a silent gap is not.
7. **Shared seeded data.** New tests must not mutate seeded rows or insert fixed values into unique indexes.

### Pass D — Contract and cross-repo

With the counterpart from Step 1c in scope, check both sides in code:

- New or renamed DTO members, query parameter names, nullability and `[Required]` against the frontend `swagger.json`, its types and e2e mocks (`Categories` vs `CategoryIds`, `includedInTotal` required vs optional, `Id` in body vs route).
- New enum members exposed to the frontend need `[EmitOpenApiMetadata]` + `[Display]`, and the frontend needs `npm run codegen:refresh`. `PageCode` and `SystemAction` are mirrored.
- Constants the frontend validates against (`FieldLimitConstants`, max lengths, `MaxCustomRangeDays`) are mirrored.
- Behaviour visible on the supplier side (token reply pages, inquiry profiles) is rendered by the frontend PR.
- Agreement is one line in the report ("Contract checked against !NNNN: consistent"); a mismatch is a finding. A contract change whose other side was excluded or is missing is a finding naming why it was not checked.
- Version skew between frontend and backend is **not** a finding: the team deploys both together (recorded decision).

### Pass E — Spec and text that drifts from the code

- **Acceptance criteria.** Tick the Step 2 checklist against the diff: *missing or partial* (promised, not implemented), *wrong* (implemented, but not what the AC says), *unannounced* (user-visible behaviour the story never asked for; that is where regressions hide), *stale* (the description describes an earlier revision). Quote the AC line in the finding.
- **PR description vs code.** Claims like "X requires a positive reply", "regenerated", "only new locks are affected", test counts. Two of the last ten PRs had a description that no longer held after the second iteration.
- **Comments.** A comment that describes an earlier design, narrates a ticket number or an incident instead of the rule, or cross-references sibling code as justification ("mirrors X"). A comment left inaccurate by the change is Should-fix; a history-narrating one is Minor.
- **Rulebook and skills.** When the PR changes a convention (new bulk-update API, new transaction rule, a helper that replaces a pattern), `.github/copilot-instructions.md` and the relevant `.claude/skills/*/SKILL.md` must say the new thing and stop saying the old one. Grep the docs and the sibling code for the pattern the PR deprecates.
- **Scope creep.** New files that do not belong to the story (ADRs, glossaries, unrelated refactors) → ask whether they are meant to stay and whether other docs should link to them. Larger cleanups found in review become their own story.

### Pass G — Conventions and modern idioms

The passes above are what history says we miss. This pass is the general lens, so the review also holds code that no earlier PR happened to get wrong.

1. **Load the convention skills for the areas the diff touches** and check the changed code against them, section by section: any `.cs` → `modern-csharp` (collection expressions, primary constructors, records, `sealed` by default, extension blocks, pattern matching, `required`/`init`, nullable annotations, `[GeneratedRegex]`, its Forbidden → Preferred table); queries, entities, migrations, caching, transactions → `priis-backend-ef-core`; endpoints, validators, DTOs → `priis-backend-fastendpoints`; events, jobs, notifications → `priis-backend-notifications`; hub changes → `priis-backend-signalr`. A skill section the diff violates is a finding with the skill path as the rule; a preference the skills do not state is a question at most.
2. **General quality, independent of the skills.** Read each changed file once with these in mind:
   - Entities own their invariants: mutations through named methods returning `SystemResult`, `private set`, backing-field collections; no `IReadOnlyPriisDbContext`, `UserCache` or `ICurrentUser` threaded into an entity method.
   - Expected failures return `SystemResult.Failure`, unexpected ones throw; no catch that swallows and continues; no `catch (Exception)` that turns a bug into a 400.
   - Nullable annotations tell the truth: no `!` where the value can be null, no `?` on a value that never is; `[Required]` on DTO members the API always sends (the frontend codegen marks everything required).
   - Async all the way: `CancellationToken ct` passed through, no `.Result`/`.Wait()`, no `async void`, no `Task.Run` around IO.
   - Reads project to DTOs with `.Select()`; no entity crosses the endpoint boundary; no `.ToList()` before a `.Where()`; no N+1.
   - Validation lives in the FluentValidation validator or the entity, not in `HandleAsync`; messages in Swedish.
   - Logging: structured templates with named placeholders, no interpolation, no secrets or personal data.
   - Configuration: new keys have an options class, appear in `appsettings.*.json` for every environment and in the deployment variable group if secret; secrets never in appsettings.
   - Migrations generated by `dotnet ef migrations add`; hand-written only for data backfills, idempotent, temporal tables handled, stamped with the right system account.
   - Public surface: `internal` when one caller; `[Display]` on new enum members; `[Archived]` instead of deletion.
   - Dead code: unused parameters, options and overloads introduced by the PR.
3. **Smell baseline (judgement calls).** Our reviews already use these labels, so use the same words. Each is Minor unless you can name the concrete defect or maintenance cost; a documented repo convention overrides the baseline; skip anything tooling enforces.

   | Smell | Flag when | Fix |
   |-------|-----------|-----|
   | Mysterious Name | the name does not say what it does or holds | rename; if no honest name comes, the design is murky |
   | Duplicated Code | the same logic shape in more than one hunk or file (Pass A owns this) | extract the shared shape |
   | Feature Envy | a method reaches into another object's data more than its own | move it onto the data it envies |
   | Data Clumps | the same few fields or parameters travel together | one type |
   | Primitive Obsession | a string or int stands in for a domain concept | a small type |
   | Repeated Switches | the same switch on the same type recurs | polymorphism or one shared map |
   | Shotgun Surgery | one logical change forces scattered edits | gather what changes together |
   | Divergent Change | one module edited for unrelated reasons | split by reason to change |
   | Speculative Generality | abstractions, parameters or hooks the story does not need | delete; inline until a need shows |
   | Message Chains | long `a.B().C().D()` navigation | hide the walk behind one method |
   | Middle Man | a class or function that mostly delegates | cut it, call the target |
   | Refused Bequest | a subclass ignores most of what it inherits | composition |
4. **Leave the grep-able anti-patterns to `/priis-backend-verify`** (`.Include` + `AsNoTracking`, `new List<`, `throw new` in Library features, `async void`, `.Result`, generic class suffixes, missing `ct`). Say once that `/priis-backend-verify` should be run if it clearly was not; do not list its hits as findings.

---

## Step 4 — Verify before you report

For each candidate finding:

1. **Re-open the cited `path:line`** in the worktree and confirm the code says what the finding claims. Fix drifted line numbers.
2. **Try to refute it.** Look for the guard, caller, validator, query filter or test one layer up that makes it a non-issue. If you find one, the finding is refuted: drop it, or keep it as Minor if the near-miss is worth knowing.
3. **Trace the failing path** with concrete inputs. If you can, the finding is **Verified**; if part of the path could not be confirmed by reading (runtime config, external service, a test run), it is **Plausible**, and the finding says what would confirm it.
4. **Scope.** Is it on changed lines, or does the PR claim to fix it? Pre-existing problems go under "Not raised" unless the PR makes them worse.
5. **Tooling.** Would the compiler, an analyzer, `dotnet format` or the test run catch it? Drop it.
6. **Rule.** Does the rulebook or a skill actually say so? Unwritten style is a question, not a finding.
7. **Already answered** in an existing thread or in the description? Drop it, or reply in that thread.

Drop anything under 50 % confidence.

---

## Step 5 — Report

Mirror the format our reviewers already use in ADO so findings can be pasted as threads. Severity: **Blocking** (wrong behaviour, data or access, broken contract), **Should fix** (duplication with real cost, documented-convention breach, missing coverage, AC missing or wrong, stale doc), **Minor** (naming, comments, copy, smell judgement calls). Rank within each axis on its own merits; a clean Standards result does not soften a Spec gap.

```markdown
## Review: <PR title or branch> (vs <base>)

**Skill:** repo-local `/priis-backend-review` (`.claude/skills/priis-backend-review/SKILL.md`)
**Intent:** <three lines>
**Reviewed head:** `<source-ref>` @ `<short-sha>` from <snapshot worktree (removed) | live checkout>. Local checkout: <same commit | ahead N / behind M | on <other-branch>>. Untracked, read live: <files | none>
**Counterpart:** <GR.PRIIS.Frontend !NNNN reviewed | found, not reviewed | expected but missing | single-repo change>
**Sibling compared:** `<path>`
**Existing threads:** <n human> (skipped <m> already raised)
**Sources:** <rulebook, skills loaded, work item(s), AC present or not>

### Findings
1. **<Short title>** — `source/.../File.cs:42` — Blocking · Correctness · Verified
   <What is wrong, in one or two sentences.>
   Failing path: 1) … 2) … 3) …
   Rule: <rulebook/skill section, AC line, or sibling file>
   Fix: <concrete suggestion, with a short code block when it helps; or "Decision needed:" with the options>

### Minor findings (non-blocking)
- `path:line`: … (at most 8; then "+N more of the same kind: <kinds>")

### Praise
- <one to three things done well; omit if nothing stands out>

### Tests
| Endpoint | 401 | 403 | Happy | Negative asserts null |
|---|---|---|---|---|
(New endpoints only. If none, write "No new endpoints" and list each endpoint whose response or validation changed with the test that asserts it, or "untested".)
Untested branches: … · Add-on candidates: `NewTest` duplicates the arrange of `ExistingTest` → assert the new field there.

### Acceptance criteria
- [x] <AC line> — <where>
- [ ] <AC line> — missing / wrong (see finding N)

### Contract check vs !<frontend PR>
Consistent / differences: …

### Questions for the author or PO
- …

### Not raised
- <pre-existing issue or team decision, one line each>
```

**Language:** write the report in English, the language of PR descriptions, commits and the rulebook. Switch to Swedish only when the user writes to you in Swedish or asks for it. Swedish in existing PR threads, in the work item or in the lessons file is not a reason to switch; quote Swedish UI copy, validation messages and AC lines verbatim inside the English text. Posted threads (Step 6) use the same language as the report. Keep findings to the point: title, where, why, fix; quote the few relevant lines, never dumps.

---

## Step 6 — Posting to the PR (`--comment`)

1. Write the threads to a scratch file and show them to the user.
2. **Wait for explicit approval.** Never post, resolve or vote without it.
3. **Mark every thread as AI-generated.** The first line of each posted comment is, verbatim:

   ```
   🤖 *AI review (Claude Code `/priis-backend-review`), read and approved by <the user's name> before posting.*
   ```

   Then the finding. The marker is not optional and is never shortened to a bare emoji: the reader must be able to tell at a glance which comments a person wrote and which were produced by the skill, and who vouched for them. If the user pastes findings from the report into ADO by hand, remind them once to keep the marker.
4. Post with `repo_pull_request_thread_write` `create`: `filePath` is repo-root relative with a leading slash (`/source/GR.PRIIS.API/...`), `rightFileStartLine` the line in the PR's version. One thread per finding; collect the minor findings in one thread titled "Minor findings (non-blocking)"; general findings go in a thread without `filePath`.
5. Do not change thread status, vote or reply on the user's behalf; the author resolves and the user votes.

Fallback without MCP: `az devops invoke --http-method POST --resource pullRequestThreads --route-parameters project=PRIIS repositoryId=GR.PRIIS.Backend pullRequestId=<id> --api-version 7.1 --in-file thread.json`.
