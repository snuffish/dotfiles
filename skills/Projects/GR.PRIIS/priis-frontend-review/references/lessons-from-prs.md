# What our reviewers actually catch — GR.PRIIS.Frontend

Source: human review threads on the 52 newest active and completed PRs in GR.PRIIS.Frontend as of 2026-10-17 (PR 18184 to 18719). 21 of them had human threads, 91 threads in total. Pipeline and system comments are excluded. Each entry gives the pattern, how it was detected, the fix that was accepted, and the PR (`!18658` = https://grutbildning.visualstudio.com/PRIIS/_git/GR.PRIIS.Frontend/pullrequest/18658).

Rough weight of the themes, by number of threads:

| Theme | Share | Typical trigger |
|-------|-------|-----------------|
| UI found by clicking through (layout, copy, states, consistency) | ~35 % | Any new screen; almost always with a screenshot |
| Duplication and reuse | ~20 % | New page or modal next to a sibling |
| Behaviour: forms, RHF, RTK cache, drag/drop, focus | ~18 % | Wizards, boards, mutations |
| Tests | ~9 % | New interaction without a spec; flaky clock |
| Contract and swagger drift | ~8 % | DTO changes, stale snapshot |
| Text drift and comments | ~6 % | Strings' JSDoc, PR description |
| Accessibility | ~4 % | Tooltips, focus, keyboard-only mode |

---

## 1. Duplication and reuse

**1.1 Sibling page copied wholesale.** The response-rate statistics page copied from the receptivity page: the page shell (`useEffect` for layout mode + `StatisticsPageHeader` + refresh button + badges), the error card, the loading skeleton, `.page`/`.refreshButton`/`.statsGrid`/`@keyframes refresh-spin`/`.tableScroll`/`.emptyCard`, and the request type + params. Seven threads. Fix: `StatisticsReportPage`, `StatisticsMessageCard`, `StatisticsLoadError`, `StatisticsLoadingState`, `StatisticsTableScroll`, shared `statistics.module.css`, `StatisticsPeriodRequest` + `toPeriodParams`; all three statistics pages moved onto them. !18658
*Detect:* open the sibling page and its `.module.css`; diff.

**1.2 Shared component existed on another branch.** A register-ticket assign-handler modal was written while a shared `AssignHandlerForm` was landing in the control-ticket branch. Fix: merge main, use the shared form with generic `filterUser` and `notice` props; the feedback-ticket modal followed. !18684

**1.3 Duplicate action handlers.** The control-ticket list's context menu re-implemented the actions of `useControlTicketActions`. Fix: the hook takes a `Pick` of the list row and `canPerform`; the list renders the same actions. !18653

**1.4 Constants in several places.** Decision colors existed in the panel badge, the card buttons and the board CSS → one const. !18630. `statisticsBucketGranularity` units defined in a route file → the enum facade. !18579. A date helper in `article-schema.ts` → `utility/date`. !18515. A `Record<Enum, Color>` makes TypeScript require every member. !18560

**1.5 Existing component not used.** `ParameterSelectionTables` reused in wizard step 5 instead of a new table. !18602. Radix `Card` instead of a hand-styled box. !18515. `Controlled.RadioGroup` with `optional` instead of a radio that cannot be cleared (twice in one PR). !18653. `AssessmentTextArea` extracted and `control` taken from `useFormContext()`. !18653

**1.6 Name clash with a shared helper.** A local `formatPrice` that skipped Swedish formatting shadowed `~/utility/format`'s `formatPrice` → renamed `priceLabel`. A `countsTowardTotal` helper that read one field → inline. !18708

**1.7 Hoisted constants.** `new Intl.ListFormat(...)` inside the component body → module-level const. !18592

---

## 2. Behaviour

**2.1 RTK Query cache invalidation.** Closing a control ticket with an applied status left `operations.contractsTab`, `contracts.list` and `contracts.details` stale; `changeOperationStatus`, `cascadeOperationStatus` and `changeContractStatus` did not invalidate `controlTickets.*` although the profile and list show live operation data. Fix: add the tags both ways. !18653. The persona list needed its own tag so admin edits refresh it. !18691
*Detect:* for each new query, list the mutations elsewhere that change the data it shows.

**2.2 Schema rule never runs in the other wizard.** The born-by-placement check read hidden fields filled only by the create step and the edit modal; the new-iteration wizard built defaults in `derive-step-defaults.ts` and never set them, so a typed date passed and surfaced as a generic API error. The unit spec filled the fields itself and could not see it. Fix: seed the fields in every defaults builder. !18704

**2.3 Zod for dates.** `z.string()` on a date → `z.iso.date({ error })`, unioned with `z.literal('')` for a cleared picker, mapped to null on submit; unit spec covers invalid calendar date, free text, empty and null. !18653

**2.4 RHF after moving items.** Only `isEditing` and `decision` were re-validated after a card moved buckets, so stale `appliedValue`/`decisionComment` errors stayed → `trigger('rows.N')`. An effect on `submitCount` re-ran on every keystroke and yanked the selection → run once per submit via a ref. Two inputs bound to the same `decisionComment` path carried a rejection reason into an approval comment. !18630

**2.5 Drag and drop.** `text/plain` drag data pasted a GUID into the detail panel's input on a missed drop and `useFollowEdits` treated it as an edit → custom MIME type and `preventDefault` on the board root. !18630

**2.6 Focus and announcements.** A card that changes parent remounts; the focused button vanishes and keyboard users start over → focus the moved card and add an `aria-live` region. !18630. A tooltip on non-focusable `Text` is unreachable for keyboard-only users → follow the `InfoTooltip` convention (`tabIndex={0}` when keyboard-only mode is on). !18534

**2.7 Payload shape.** Destructuring `operationId` out and spreading the rest into the body is not type-safe → build the body field by field with `satisfies ApiCloseControlTicketRequest`. !18653. `id` sent in both URL and body → body carries only `comment`. !18653 / backend !18652

**2.8 Access in the UI.** The statistics table linked to operations that Kaj (DataAnalyst) cannot open → render as text unless `useSystemActions()` has `ReadOperation`; a per-row flag from the backend would have broken the global cache. !18658. Protected tickets list only handlers with protected-data access. !18684, !18638

**2.9 Time.** `formatDateTime` must parse offset-less input as UTC (`dayjs.utc(value)`). !18653. A spec that rendered "due" chips depended on the wall clock → `page.clock.setFixedTime` in `beforeEach`. !18238

**2.10 Routes.** Index route with a placeholder component → `component: () => null`. !18653. A system page under the wrong route → `/system/notification-definitions`. !18238

**2.11 Hard limits.** A page-size "that will never be reached" is still theoretically reachable; acceptable when the UI says "Visar 200 av N" rather than truncating silently. !18560. A guard the backend never triggers (`truncated` with no rows) kept deliberately because the invariant is not in the OpenAPI schema. !18610

**2.12 Early return and small cleanups.** `if (!ticket) return …` instead of nesting; `readOnly` on a locked RHF input. !18653, !18606

---

## 3. UI found by clicking through

Most of these arrived as a screenshot plus one sentence. None of them is visible in the diff.

- Collapse button stopped working while a search filter was active; expanded state should survive clearing the search. !18658
- Present the same number the same way on sibling screens: `100 % (4 av 5)` on the statistics page as on the operation's tab; merge the separate count column. !18658
- Label "Lägg till notering" until a note exists, then "Redigera notering". !18653
- A link inside a modal navigated the route behind the modal and left the modal stuck → `target="_blank"` for now, popover card as its own story. !18653
- An optional textarea in a row of optional fields was mistaken for one of them → own card with `gray-2` background. !18653
- Default tab spacer doubled the top margin → remove `mt='6'`. !18653
- Two-column layout for the facts section; a grid fix committed by the reviewer and left for the author to accept. !18653
- Auto-copying "Bedömning" into "Avslutstext" could leak an internal assessment to the supplier → explicit "Kopiera från …" buttons, disabled while the source is empty; label position fixed after a second screenshot. !18653
- Statistics differed from the operation page by one ongoing inquiry → intentional, explained in a tooltip; the reviewer withdrew after reading it. Explain definitions in the UI. !18658
- Timeline: first selection is created as `New`, not `Pending`, so an event was missing; time + person shown on some events and not others (an AI "de-clutter" choice nobody asked for); a comment shown before the ticket was created; spacing; two-column mode too tight; duplicate "Ja" after price lock; chosen operation on the ticket line; PDF page break splitting a header from its content; which comment was acknowledged. !18644
- Reset button for map zoom/position; distinct icons for list vs map. !18648
- Chart month labels need the year when the span exceeds 12 months; a misleading error for spans over 1095 days fixed in the shared `PeriodPicker` with a spec at the boundary. !18579
- Date-picker calendar covering the input; "Ändra objekt" styled as an edit button; draft banner replaced by a tooltip. !18625, !18584, !18540
- Copy: "ärendenummer" when only matchningsärenden are searchable; be specific about which entities global search covers. !18592
- Whole price label clickable, not only the info icon; a heading must not sit inside a button. !18184

---

## 4. Tests

- No spec for a new popover → four cases added (open, badges, reconstructed note, empty states). !18184
- Bulk reject never tested; add regression specs for the two bugs found in review; assert that no PUT happened on a blocked save; `capture.lastDecisions()` pattern. !18630
- Specs pin the clock; import shared constants from `./mocks`; `test`/`expect` from `$e2e/fixtures` (a lint rule from main would otherwise fail CI). !18238
- Table-driven cases (`for (const { name, flags, status } of cases)`) for locked / inactive / deactivated personas instead of three copies. !18691
- Mock builders gain options (`isProtectedHousing`, `unassigned`, `localitiesTruncated`) rather than a second builder. !18684, !18610
- A unit spec that fills in the fields the real wizard never populates cannot catch a wiring gap; say so in the review. !18704

---

## 5. Contract and swagger

- `swagger.json` generated against an older backend (old `categoryIds`) → regenerate against the backend branch with main merged. !18592, !18658
- Hand-patched snapshot is acceptable when the description says so; "regenerated" when it was patched is a finding. !18708
- `required` vs optional: the codegen forces every property required, so the TS type cannot tell you what an older backend sends. The team's recorded decision: frontend and backend deploy together, so no fallback needed. !18708
- Reviewer line "Contract checked against backend !18703: consistent" listing the DTOs, `swagger.json` and e2e mocks. Do the same. !18704
- A backend max-length constant the frontend never validated → mirrored validator. !18621
- `pages.ts` duplicated the backend `PageCode` enum with six codes the backend lacked and one collision → own story, then removed. !18653 → !18695

---

## 6. Text drift and comments

- Strings' JSDoc said `extrasNote` was shown under the inquiry side card; it was not. The PR description said the card "reuses the same copy". Fix the code to match the documented intent. !18708
- A test id hardcoded in the component and twice in the spec although the PR had just centralised the strings for the same reason → `priceBreakdownTestIds` in `e2e/test-ids.ts`. !18708
- Badge header hardcoded `ArticleTemplateType.ExtraService` while rows were chosen by `includedInTotal` → group by type. !18708
- Age labels inconsistent across ticket details, review steps and side card; callout shown after the inquiry ended; a unit spec's doc block cites the ticket instead of the rule. !18704
- A comment on a `Map` that describes usage rather than content → rewrite. !18644
- Demo-content handling removed once the backend always serves demo data. !18556

---

## 7. Decisions recorded in threads (do not re-raise)

- Frontend and backend deploy together; version skew is not a finding. !18708
- Month labels on charts: year always shown (`Okt 25`) after discussion. !18579
- Teal is the house color for "info-ish" callouts in templates; blue not required. !18515
- Ticket references in comments: style, left as is when consistent with the backend PR. !18708
- Larger UX ideas (user popover card, TanStack markdown) become their own stories. !18653, !18651
