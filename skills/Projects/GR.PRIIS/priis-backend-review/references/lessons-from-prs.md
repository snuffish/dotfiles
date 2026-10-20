# What our reviewers actually catch — GR.PRIIS.Backend

> Registry copy of `GR.PRIIS.Backend/.claude/skills/priis-backend-review/` @ `970b7c19` (`origin/main`, 2026-10-19). The upstream wins; `/code-review` reads the upstream directly (`code-review-priis-profile`). Re-copy when it changes.

Source: human review threads on the 50 newest active and completed PRs in GR.PRIIS.Backend as of 2026-10-17 (PR 18183 to 18721). 25 of them had human threads, 117 threads in total. Pipeline and system comments are excluded. Each entry gives the pattern, how it was detected, the fix that was accepted, and the PR it comes from (`!18659` = https://grutbildning.visualstudio.com/PRIIS/_git/GR.PRIIS.Backend/pullrequest/18659).

Rough weight of the themes, by number of threads:

| Theme | Share | Typical trigger |
|-------|-------|-----------------|
| Duplication and reuse | ~30 % | New endpoint, helper or test class next to an existing sibling |
| Domain edge paths (state, filters, audit, transactions) | ~25 % | Status transitions, bulk updates, jobs, protected data |
| Tests (coverage, add-on tests, copied helpers) | ~12 % | New endpoints, new fields on existing endpoints |
| Text drift (PR description, comments, docs, skills) | ~12 % | Second review iteration, convention changes |
| Naming and file layout | ~10 % | New abstractions, partial classes |
| Performance in loops | ~6 % | Jobs, SaveChanges hooks, backfills |
| Cross-repo contract | ~5 % | Any DTO or parameter change |

---

## 1. Duplication and reuse

**1.1 Sibling endpoint copied wholesale.** `GetOperationResponseRateStatisticsEndpoint` copied `HandleAsync`, `GetCacheKey`, the cache duration and the category-name lookup from `GetOperationReceptivityStatisticsEndpoint`, differing only in request type and key prefix. Fix: `GlobalStatisticsReports.GetOrSetReportAsync(...)` and `GetCategoryNamesAsync` beside `StatisticsPeriodResolver`; both endpoints use them. !18659
*Detect:* open the sibling; diff the two `HandleAsync` bodies.

**1.2 One business rule, three definitions.** "Inquiry expired" (`NotReplied && InquiryEndReason == DeadlineReached`) existed in three statistics queries. Fix: one static expression on the entity, used via `.Invoke`, inlined by `ExpandingQueryExpressionInterceptor`. !18659
Same pattern: the extra-service ordering `OrderBy(Name).ThenBy(Id)` in three files with a comment "same ordering as the calculator" → `MatchingSelectionFilter.OrderedExtraServiceTemplateIds`. !18707 (merged to `release/2.10.X`; the symbol reaches `main` with the next release merge, so grep `origin/release/2.10.X` when `main` does not have it yet)
Same pattern: three projection lines (`SubareaName`, `Articles`, `ArticlePricesApproximate`) copied between two endpoints, and the "approximate" predicate in four files → `BaseContract.SubareaNameExpression()`, `MatchingSelectionContractUsedArticle.IsApproximate`, `SnapshotArticlePrice.OrderedFromSnapshot`. !18183
*Detect:* grep the property combination of any new predicate across `source/`.

**1.3 Private test helpers that already exist elsewhere.** `CustomPeriod`, `Today`, `CreateCategoryAsync`, `CreateOperationWithContractAsync`, `NewSelection` copied from the sibling test class; `CreateDataAnalystUserAsync` was the third private copy. Fix: `TestDataHelpers/TestDataStatisticsHelper`, `TestDataHelpers/TestDataUserHelper`. !18659
*Detect:* grep the helper name across `tests/`.

**1.4 "Don't we already have one of these?"** `AffectedOperations` added under `API/Common/Information` with a reviewer asking whether one exists and, if not, to make it generic. !18619. A `static` used by one method inlined instead. !18539. Two record types that belong in the same file as their client interface. !18609. `s_swedishComparer` moved to a shared place should take the second copy with it. !18643

**1.5 Existing base class not used.** `CreateControlTicketEndpoint` hand-rolled save + 201 + three event publishes; reviewer: use `ExtendedCreateEndpoint` with a new `afterSave` hook on `SendCreatedAndSaveChangesAsync`. Four sibling endpoints replaced `if failure → SendErrors; Save; Send` with one `SendAndSaveChangesAsync(result, dbContext, ct)`. `Id` removed from a request body and read with `Route(RouteParameterCommentId)`. Magic string `"CategoryProtection"` replaced with `PriisDbContext.CategoryProtectionQueryFilter` in five places. !18652

**1.6 Existing exception handling not used.** Matching SQL error numbers by hand for an insert race; `UseExceptionProcessor` already turns it into `UniqueConstraintException`, and the catch must be scoped to the entity (`when (ex.Entries.Any(e => e.Entity == lastLogin))`) or it swallows other pending failures. !18681

**1.7 Sanctioned escape hatch instead of pragma.** `#pragma warning disable RS0030` in a job sets a precedent; fix: `ExecuteUnauditedUpdateAsync` beside `IAuditableQueryExtension`, which throws for `IAuditable`. The pragma lives in exactly two library methods. !18502

**1.8 Sister code still on the deprecated pattern.** After `QueueUpdate` landed, the job in the same folder still had `TransactionScope` + `SaveChanges` + audited `ExecuteUpdateAsync`. "The next person copying from this folder has two contradicting examples." Fix in the same PR. !18502

**1.9 Over-engineering is also a reuse finding.** A reflection-based `FlatColumnsFromRecord` builder with `IEnumerable` tricks and a partial class "too small to split" was replaced by two explicit column mappings guarded by tests. A one-line helper "not worth having" was inlined. !18587. A Claude-generated refactor of `ResolveTicketIdsAsync` was declined by the team as not worth it. !18643

---

## 2. Domain edge paths

**2.1 Late transitions leave stale state.** Re-pricing only positive-reply contracts meant a contract changed Yes→No after expiry kept its locked price and snapshot, which is the exact symptom of the bug the PR claimed to fix. Fix: lock exactly once, at the transition into `MatchAchieved`, after replies are final. !18707
**2.2 The API never enforced what the description said.** "Only positive replies can be selected" was true in the UI, not in `SelectContractEndpoint`. Fix: guard before the price check with a Swedish validation message. !18707
**2.3 A snapshot-or-live choice made on the wrong signal.** Declined contracts fell back to live prices after the lock because the branch keyed on `ArticlePriceSnapshot.Count > 0`. Fix: branch on inquiry closed + reply. !18707
**2.4 Backfill provenance.** A deploy-time backfill filled an extra from a value added *after* the lock and stamped it `ReconstructedVerified`. Fix: only summed articles may fall back to today's data. !18707
**2.5 Decision needed on existing data.** When a fix only covers new rows, say so and get a decision (clean up history, or record the accepted consequence on the work item). !18707

**2.6 Query filter makes a value constant.** `OpenControlTicketSummary.Status` was always `Ongoing` because of the `ControlTicket.IsOpen` filter; the property was removed. !18652
**2.7 Nested global filters.** `RegisterTicketComment`'s filter uses `RegisterTickets.Any(...)`, and EF applies `RegisterTicket`'s own filter inside it; that is why the filter must have the positive form. A test (`Comments_On_Protected_Ticket_Are_Hidden_Without_Access`) pins it. !18683

**2.8 Protected data reaches a new entity.** Register tickets on contracts, templates and subareas, their comments, assignment and the created notification all leaked to administrators without access until each path got the check. !18683, !18539, !18637. Prefer deriving access (in `UserCache` on cache miss) over a new DB column and migration. !18582

**2.9 Notification routed by current state instead of stored fact.** "Other side of the conversation" chose the recipient by who is handler *now*; after a handler change the comment went to the wrong side. Fix: route by the comment's stored `AuthorType`. !18652

**2.10 Audit stamps.** Four `Cascade*StatusEndpoints` ran raw `UPDATE … SET [Status]` without `[ChangedBy]`; history rows then named the previous editor. The analyzer cannot see raw SQL. Fix: `[ChangedBy] = {currentUser.Id}` in every SET, tests assert it on cascaded rows, rulebook updated. !18502
`ChangedBy` set by both the queue and the caller's setters gives SQL error 264 far from the call site; translated into `QueuedBulkUpdateException` with a clear message. !18502

**2.11 Transactions and the change tracker.** `BeginTransactionAsync` guard must look at both `Database.CurrentTransaction` and `Transaction.Current`; isolation must be `ReadCommitted`, not `TransactionScope`'s Serializable default. The tracker was accepted before the After phase ran, so a failed phase left `Added`/`Deleted` entries silently committed on retry; fixed by snapshot/restore. Queue dequeued before validation; fixed by dequeuing only after success. !18502

**2.12 Jobs: partial success is not failure.** An event publish that threw after the run was saved marked the run `Failed`. Fix: try/catch around the publish with `CancellationToken.None`, log, keep `Completed`; test added. !18559. All-or-nothing exact-count guards in jobs are acceptable only when the id set provably cannot shrink; the reviewer and author worked that out in the thread and left it. !18502

**2.13 Exception types.** `AggregateException` from a failed save plus a failed restore hid `UniqueConstraintException` from the handler that maps it to 409. Fix: attach the second error to `Data`, log, `throw;`. !18502

**2.14 Access rules changed by accident.** `SystemAdminAccessRules` lost an action in a feature PR; reviewer asked, it was intentional but undocumented. Ask every time. !18559

**2.15 Deterministic paging.** Add the id as the last sort key. !18559

**2.16 Validation that mirrors sort assumptions.** Natural sort padded contract numbers to 5 digits while the prefix may be 20 long. Fix: pad to the real max, add the constant, mirror the max length in the frontend validator (which was missing). !18601 / frontend !18621

**2.17 Ratelimits and loops.** "Is there no rate limit?" — it lived in the client, not the backfill; the comment was clarified. Loading operations one at a time in a backfill was changed to batch loading. !18647

**2.18 Store-generated keys.** Snapshot/restore skipped key properties on rollback; three int-identity entities (`IdentityUserClaim`, `IdentityRoleClaim`, `DataProtectionKey`) can hit it. Made explicit with a `NotSupportedException` and a test. !18502

---

## 3. Tests

**3.1 Minimum coverage missed on a batch of endpoints.** Nine control-ticket endpoints lacked 401 tests, four lacked 403; a bulk test asserted only status codes. The reviewer posted the endpoint × 401/403 table. !18652
**3.2 "Does this need its own test?"** Two reviewers asked to hang a new assertion on an existing test instead of adding a near-duplicate (`ExportDetailedMatchingTicketsEndpointTests`, `RespondToMatchingInquiryViaTokenEndpointTests`). "Keeping the number of tests down is fine in the backend too." !18615, !18643
Concrete instance without a comment: `GetSelectionProcess_WithVisitingAddressAndCoordinates_ReturnsCoordinates` and `_WithoutVisitingAddress_CoordinatesAreNull` repeat the arrangement of the two `_ReturnsCity` tests directly above them; the coordinate assertions belong in those tests. Commit `fed99fd3` (!18647).
**3.3 Copied helpers across test classes.** See 1.3. Also reflection `typeof(Operation).GetProperty(...).SetValue` replaced by `SetVisitingAddressForTest`. !18647
**3.4 The failing branch has no test.** Only the success path of audited delete + queued update was covered; the reviewer specified the test that would fail (`Deleted`/`Added` after `DbUpdateException`). !18502
**3.5 A test that pins the bug.** `declined.Price = 1234` asserted as expected output; acceptable only once the comment says it models legacy data. !18707
**3.6 Temporal scenarios under AutoRollback.** "Value added after the lock" cannot be produced inside one transaction; the NOTE in the test class was extended instead of a fake test. !18707
**3.7 Missing coverage noticed by reading, not by tooling.** Parameter changes in the timeline query had no test. !18643

---

## 4. Text that drifts

**4.1 PR description vs code.** "SelectContractEndpoint requires a positive reply" (false), "only new locks are affected" (hid an unfixed path), "regenerated" (hand-patched), test counts. Fixed descriptions each round. !18707
**4.2 Comments describing the old design.** "Live prices are only shown before the lock" became false in the same PR; "same ordering as X" stood in for a shared definition; a comment about deploying Worker without API was removed as misleading. !18707, !18643
**4.3 Docs that contradict themselves.** `docs/Tests.md` still described the removed xUnit project and a database name that no longer exists, in a PR that touched the surrounding text. !18681
**4.4 Rulebook and skill drift on convention changes.** `ef-core/SKILL.md` had no `QueueUpdate` section and still said "setting ChangedBy manually ✗ (interceptor handles this)", contradicting the new raw-SQL rule; there is no interceptor, `SaveChanges` stamps it. !18502
**4.5 Unrelated files.** ADR and `GLOSSARY.md` added in a feature PR: are they meant to stay, and do the other `.md` files and agent files link to them consistently? !18717
**4.6 Remove comments that restate code.** !18539, !18516

---

## 5. Naming and layout

- `TargetIsProtectedHousing` returned an expression but read like a bool → `...Expression`. !18683
- `ExternalSuggestionCache` was general → `DistributedResultCache`. A `Ranker` that also normalised → normalisation moved to `MapRows`. !18609
- `KnownClear` read as the verb *clear* → `ProvablyUnprotected`; `Register(...)` escape hatch → `Explicit`. !18717
- Query parameter `CategoryIds` → `Categories`, mirrored in the frontend PR. !18533
- `PriisDbContext.cs` kept as a slim root; sets, query filters, save logic and audited deletions moved to partial files grouped by responsibility, not by size. !18502
- Column named `Antal` that is always 1 or empty → removed. !18587

---

## 6. Performance in hot loops

- `ChangeTracker.Entries()` scanned once per queued update (a full `DetectChanges` each) → one sweep with `EntityType` + `Ids`. !18502
- `Priority` computed three times per row in one LINQ chain → project once into an anonymous object. !18609
- `ISavingChangesHandler` runs on every `SaveChanges` in the system; it should reuse the entries list the save already materialised. !18643
- `GlobalSearch`: a pasted GUID should short-circuit to an id lookup. !18591
- Choosing `ToHashSet()`/`Distinct()` for intent over `ToArray()` is fine; make the intent visible. !18643

---

## 7. Cross-repo contract

- `Id` in body and route: remove from body, mirror in the frontend endpoint builder. !18652 / !18653
- Query parameter rename mirrored in `swagger.json` and the frontend in the same round. !18533 / !18534
- A constant the frontend validates against (max length 20) added in the backend PR and consumed by the frontend PR, which must merge second. !18601 / !18621
- A frontend reviewer checked the backend DTOs against `swagger.json` and the e2e mocks and reported "consistent" as a line in the review. Do the same. !18703 / !18704
- Recorded team decision: frontend and backend deploy together, so a missing field in an older backend is not a finding. !18708

---

## 8. Scope and product decisions surfaced in review

- Removing archived parameters immediately broke "Anpassa och skicka förfrågan" for open tickets; the design moved to a job that removes them once no ticket uses them, with PO input in the thread. Raise it when the story's scope is smaller than the code's effect. !18619
- Protected birth data still in the supplier payload although hidden in the UI: in scope as written, worth confirming with data protection. !18703
- A follow-up story created for a larger cleanup (`pages.ts` removal) instead of stretching the PR. !18652 / frontend !18653
