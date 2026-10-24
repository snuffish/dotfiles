---
name: priis-frontend-review
description: "[Project: GR.PRIIS.Frontend] Reviews frontend changes against PRIIS architecture rules: RTK Query caching and invalidation, TanStack Router typed routes, React component colocation, form state handling, Swedish UI display labels, and Vitest coverage. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
argument-hint: "[PR id | PR URL | work item id | branch] [--base <ref>] [--live] [--no-browser] [--comment]"
---

# /priis-frontend-review — Frontend code review

> Registry copy of `GR.PRIIS.Frontend/.claude/skills/priis-frontend-review/` @ `5726e81c` (`origin/main`, 2026-10-19). The upstream wins; `/code-review` reads the upstream directly (`code-review-priis-profile`). Re-copy when it changes.

A review here is a hunt for the things our own reviewers keep finding, not a generic lint pass. The catalog of what they found in the last ~50 PRs, with the fix that was accepted each time, is in [references/lessons-from-prs.md](references/lessons-from-prs.md). Read it once per review session; the passes below point into it.

**Invariants.** The review is read-only: no edits, no checkouts of the main working tree, no `git stash push`, no commits. The only git writes are `git fetch`, `git stash create` (one unreferenced commit object, nothing else) and `git worktree add/remove/prune` on a review worktree. No installs, builds, lint or test runs except what Pass F needs to start the app (CI runs lint and build, `/priis-frontend-verify` covers the grep-able anti-patterns). Never start fixing what you found unless the user asks. Every Blocking or Should-fix finding is verified (Step 4) before it is reported. Posting to ADO needs explicit approval (Step 6).

`allowed-tools` pre-approves reads only: `git` as a whole (every read is `git -C <path> …`, so a sub-command prefix such as `git diff:*` never matches; the invariants above are what keeps it read-only), the `az` read commands (`pr show`, `pr list`, `pr work-item list`, `boards work-item show`) and the read-only ADO MCP tools (`repo_pull_request` get/list, `repo_pull_request_thread` list, `wit_work_item` get; the writes live in the separate `*_write` tools). Nothing that posts, resolves or votes is pre-approved, not even the `az devops invoke` fallback, so the permission prompt is a second gate behind Step 6. Pass F's `npm` commands and the browser tool are not pre-approved either; they prompt.

All paths are relative to `source/priis-web/` unless noted.

---

## Usage

| Invocation | Reviews |
|-----------|---------|
| `/priis-frontend-review` | The current branch vs `origin/main`: commits, staged, unstaged and untracked files. If the branch has a PR, its description, work item and threads are read too |
| `/priis-frontend-review --base origin/release/2.10.X` | Same, against a release branch (hotfix branches) |
| `/priis-frontend-review feature/31084_operation-response-rate-statistics` | A branch vs `origin/main` |
| `/priis-frontend-review 18653`, `/priis-frontend-review <PR URL>` | An Azure DevOps PR, its linked work item, existing threads and its counterpart PR in the backend repo |
| `/priis-frontend-review #31084` | The PR (or branch) of a work item |
| `--live` | Read the main checkout instead of a snapshot worktree. Only for what cannot be snapshotted |
| `--no-browser` | Skip Pass F (clicking through the running app) |
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
| Work item id | find its PR (`az repos pr list --status all --query "[?contains(title,'#31084')]"`, or the branch `feature/31084_*`) and continue as PR or branch | as above | as above |

Rules:
- A PR id or URL usually means the user is **not** on that branch. Say so and review the PR's head; never check it out in the main working tree.
- When no PR was given and the scope is a branch, look for its PR anyway: `az repos pr list --source-branch <branch> --status all --detect true -o json` (or `repo_pull_request list` with `sourceRefName`). Its description and the story's mockups are the best context a reviewer gets.
- Never use `@{u}` as the base; on a feature branch that is the branch's own remote copy and yields an empty diff. Confirm `git rev-parse <base>` resolves and `git diff <base>...<head> --stat` is non-empty **before** going further.
- `git stash create` does not capture untracked files. List them with `git ls-files --others --exclude-standard`, read them live, and mark every citation into them `(live, untracked)`.
- For the branch and PR scopes, record how the main checkout relates to the reviewed head (`git rev-list --left-right --count <head>...HEAD` → `same commit`, `local ahead N / behind M`, or `on <other-branch>`); the working-tree scope is `same commit + working tree` by construction. The report states it so the user knows whether what they see locally is what was reviewed.

### 1b. Read the PR, the work item and the threads

With the MCP tools, `project: "PRIIS"` and `repositoryId: "GR.PRIIS.Frontend"`. They come from the `azure-devops` server (`@azure-devops/mcp`, registered per user with `claude mcp add azure-devops -- npx -y @azure-devops/mcp grutbildning`; no repo config ships it), which `priis-frontend-workflow` already prefers over the `az` CLI because the CLI truncates multi-line text on Windows. Without the server, use the `az` fallback below.

1. `repo_pull_request` `get` with `includeWorkItemRefs: true` → title, description, branches, draft state.
2. `repo_pull_request_thread` `list` → existing threads. Count only human threads (skip `commentType: system`, the Azure Pipelines bot and vote/policy threads). Skip anything already raised, and read the author's replies: they record decisions (for example "frontend and backend always deploy together") that rule out findings.
3. `wit_work_item` `get` with `expand: "Relations"` on the linked task or bug to find `System.Parent`, then a second `get` with `fields` on the parent story (the two parameters are mutually exclusive) → acceptance criteria and attached mockups. Descriptions and acceptance criteria are HTML; strip the tags. When there is no acceptance-criteria field, say so and name what you used instead.

Fallback when the MCP server is down: `az repos pr show --id <id> --organization https://dev.azure.com/grutbildning -o json`, `az repos pr work-item list --id <id> ...`, `az boards work-item show --id <wi> ...`, and `az devops invoke --org https://dev.azure.com/grutbildning --area git --resource pullRequestThreads --route-parameters project=PRIIS repositoryId=GR.PRIIS.Frontend pullRequestId=<id> --api-version 7.1 -o json` (output is cp1252; `az devops invoke` is not pre-approved, so this read prompts once). Always the `dev.azure.com` form; the `visualstudio.com` host fails authentication. If nothing can be fetched, ask the user to paste the description; never infer it from the branch slug.

### 1c. Counterpart PR — every time

A frontend change usually has a backend half with its own PR and work item under the same parent story. Look for it whether or not the description names it: `Backend PR: !18652` / `This PR relates to: !18690` in the description, the parent story's other child tasks, a branch with the same id or slug in the backend repo (`git -C <backend> ls-remote --heads origin '*<id>*'`). The backend checkout is normally next to this repo (`../GR.PRIIS.Backend`); ask if it is not.

| Outcome | What it means for this review |
|---------|-------------------------------|
| Found | In scope: fetch its branch, diff `origin/main...origin/<be-branch> -- source/GR.PRIIS.API source/GR.PRIIS.Library` for DTOs, validators, access rules and the enums behind `x-enumMetadata` (the `[EmitOpenApiMetadata]` enums live all over `GR.PRIIS.Library`: `DataAccess/Models/{Register,Matching,Notifications,Auth}`, `Common/**`, `Options`, `Feature/**`; a narrower pathspec silently drops them), read its threads. Pass D checks the two against each other in code, not against what the description claims |
| Found, excluded by the user ("frontend only") | Name it in the report as not reviewed, and raise every contract the diff touches as a finding, because nobody checked the other side |
| Expected but missing (`swagger.json` changed by hand with no backend branch behind it) | A Should-fix finding, Blocking if the product breaks at runtime without it |
| None | Write "single-repo change" in the report |

### 1d. Materialise the head in a review worktree

Review from a detached worktree under `.claude/worktrees/`, so the user can keep editing and line numbers stay stable. `--live` skips this and reads the main checkout; say so in the report and warn that edits during the review move the lines.

```bash
git worktree list                                              # a stale review-* from an interrupted run makes `add` fail: remove or `git worktree prune` it first
git worktree add --detach .claude/worktrees/review-<slug> <head>   # <head> = $SNAP, origin/<branch> or origin/<sourceRefName>; <slug> = PR id or branch slug
git -C .claude/worktrees/review-<slug> diff <base>...HEAD > <scratch>/review-<slug>.diff   # inside the worktree HEAD is the reviewed head; remote refs are shared
git -C .claude/worktrees/review-<slug> log --oneline <base>..HEAD   # working-tree scope: the top two entries are the synthetic "WIP on …" / "index on …" stash commits; take the commit list from <base>..<local-branch> instead
```

Then call `EnterWorktree` with `path: ".claude/worktrees/review-<slug>"` (an existing path, not `name`: `name` would branch a fresh worktree off `origin/main`). This works from the main session and, because the target is under `.claude/worktrees/` of the same repository, also from a subagent whose working directory was pinned at launch (the switch then affects only that agent). `ExitWorktree` cannot be called from a subagent, and a refused `EnterWorktree` is not an error: skip the tool, read files under the absolute worktree path and run commands with `git -C <that path>` or from that directory. Once the session *is* inside the worktree, Claude Code refuses git aimed at the main checkout, so do the fetching and the diff above before entering.

Review subagents only read, so launch them without `isolation: "worktree"` (an isolated subagent starts from `origin/main` and would review the wrong code) and give each the absolute worktree path and the saved diff path.

The worktree has no `node_modules`; only Pass F needs them (`npm ci` there). Cite paths as repo paths (`src/...`), never the worktree path. When done: `ExitWorktree` with `action: "keep"` (only if `EnterWorktree` succeeded), then from the main checkout `git worktree remove .claude/worktrees/review-<slug>` (`--force` if `npm ci` left files); keep it if the user wants to continue on that branch. `.claude/worktrees/` is gitignored.

---

## Step 2 — Map the Change & Establish the Baseline

**Step 2 Exit Bound:** Before proceeding to Step 3, generate: (1) 3-line intent summary, (2) acceptance criteria checklist, (3) changed file list with diff stats (`git diff --stat`), (4) list of all new symbols with their nearest existing sibling feature named. Do not open review passes without this baseline.

1. **Intent and acceptance criteria.** Write a three-line intent summary. From the work item, list each acceptance criterion (or each promise in the PR description when there is no AC field) as a checklist item; Pass E ticks it off. *The description states intent; the diff states truth.* Where they disagree the diff wins and the disagreement is a finding. The description is evidence, not an outline: do not let its structure or omissions shape the review.
2. **Blast radius.** `git diff --name-status` first. Under about 200 changed lines read the diff; above that read each changed file in full from the worktree. For every deleted or moved file, grep for remaining imports. When a type, context or hook changes, find every consumer. Skip generated files (`routeTree.gen.ts`, `*.gen.ts`, lockfiles), but check that generated artefacts which *should* have changed did (`swagger.json` after a backend DTO change, a scaffolded enum facade after a new `[EmitOpenApiMetadata]` enum).
3. **New symbols.** List every route, component, hook, endpoint builder and its tags, schema, string, enum facade, CSS module, test id, mock builder and spec the diff introduces.
4. **The sibling.** Find the existing screen or feature closest to the new one: the other statistics pages, the other ticket types (`feedback-ticket`, `register-ticket`, `control-ticket`), the other wizard that reuses the same step, the sister modal. Most duplication findings in our history came from putting the new code next to its sibling. The report names it.

---

## Step 3 — Review passes

Run every pass. When the diff is too large to hold in one sitting (roughly more than 1 500 changed lines, not file count), run A, B and C as parallel read-only subagents, each given the saved diff path, the absolute worktree path, the intent summary, the AC checklist and the sibling path; sub-agent output is evidence, not a verdict, so Step 4 runs on it. Every finding is tagged with one axis for the report: **Correctness** (B, F), **Standards** (A, D, G), **Spec** (E), **Tests** (C).

### Pass A — Reuse and duplication (highest yield)

AI-assisted changes re-create what already exists two folders away; a single PR once copied a page shell, a loading state, an error card, five CSS rules and a request type from its sibling page. For **each new symbol** from Step 2 ask, in this order:

1. **Does it already exist?** Search by concept, not by name. Use the LSP (`findReferences`, `documentSymbol`) or `Grep`:
   - A formatter or date helper belongs in `~/utility/format` or `~/utility/date`; grep those first, then grep `Intl.`, `dayjs(`, `toLocale` in the diff.
   - A constant tied to a backend enum (units, colors, labels per member) belongs in that enum's facade `src/enums/<enum>.ts`.
   - A CSS rule: grep the selector body (`@keyframes`, `min-width`, `overflow-x`) across `src/**/*.module.css`.
   - A component: list `src/components/<area>/` and read its `index.ts`.
   - A hook or action set: grep `use<Feature>Actions`, `useFormContext`, the modal key.
2. **Is it a copy of the sibling?** Open the sibling side by side. Page shells, loading skeletons, error and empty cards, request types and `toParams` helpers, color maps and context menus have all been copied with only names changed.
3. **Should the existing infrastructure have been used instead?**

| Need | Already exists | Do not accept |
|------|---------------|---------------|
| Statistics page | `StatisticsReportPage`, `StatisticsMessageCard`, `StatisticsLoadError`, `StatisticsLoadingState`, `StatisticsTableScroll`, `PeriodPicker`, shared `statistics.module.css` in `~components/statistics`; `StatisticsPeriodRequest` + `toPeriodParams` in the endpoint builder | A per-page copy of the shell, skeleton, error card or CSS |
| Handler assignment | `features/shared/components/assign-handler-form.tsx` (`filterUser`, `notice` props) | A second modal per ticket type |
| Row actions | One `use<Entity>Actions` hook that both the page menu and the list context menu render | A context menu with its own handlers |
| Dates | `~/utility/date`: `formatShortDate`, `formatLongDate`, `formatFullDate`, `formatDateTime`, `formatDateRange`, `getStockholmToday`, `SWEDISH_TIME_ZONE` | `Intl.DateTimeFormat`, bare `import dayjs from 'dayjs'`, a local `formatX` |
| Numbers and prices | `~/utility/format`: `formatNumber`, `formatPrice`, `formatPercent`, `formatShare` | A local helper named like a shared one but skipping Swedish formatting |
| Messages and callouts | `Alert` from `~/components/notification/alert` | Raw Radix `Callout` |
| Tooltips | `InfoTooltip` or the same keyboard-only `tabIndex` convention | A tooltip on a non-focusable `Text` |
| Form inputs | `Controlled.*` (clearable `RadioGroup` with `optional`, `DatePicker`, `Locality`, comboboxes); `control` via `useFormContext()` | Hand-built inputs, `control` threaded through props |
| Per-member maps | `Record<Enum, T>` so TypeScript requires every member; `…Names` from codegen, `…Labels` hand-maintained in the facade | `switch` with a default, string unions |
| Test ids | `e2e/test-ids.ts` typed objects | `'some-id'` inline in a component or spec |
| Permissions | `useSystemActions()`; `systemActions={[...]}` on tabs and menu items | A per-row flag from the backend for a global permission |

Also flag the reverse: an abstraction that hides more than it saves ("is it worth having?"), and a helper that reads one field where the field inline says the same.

### Pass B — Behaviour and state

- **RTK Query cache.** For every mutation: which tags does the data it changes carry, and does the mutation invalidate all of them? Check both directions: a new entity reading live data from an old entity, and old mutations that now affect the new entity (closing a ticket left `contracts.*` stale; operation-side mutations did not invalidate `controlTickets.*`). A query that should refresh after admin changes needs its own tag.
- **Form wiring across entry points.** A schema rule only runs where the fields it reads are populated. When a schema or step is reused by several wizards (create, edit, new iteration), check each one's defaults builder. `Controlled.DatePicker` does not clamp typed input; the schema must.
- **Zod.** Date strings are `z.iso.date(...)` (plus `z.literal('')` when a cleared picker leaves an empty string), never `z.string()`. Swedish messages from `~strings/error-messages`.
- **RHF state.** After moving an item between buckets or sections, `trigger(...)` the row so stale errors clear. Effects keyed on `submitCount` run once per submit. Two inputs bound to the same path is a finding unless intended. Remounting a focused element loses focus; keep focus or announce with `aria-live`.
- **Drag and drop.** `text/plain` data pastes into inputs on a missed drop; use a custom MIME type.
- **Payload shape.** Build request bodies field by field with `satisfies ApiXRequest`; a spread `...body` leaks new fields silently. Do not send an id in both route and body. Never mutate a prop object; copy it.
- **Access in the UI.** A link to an entity the user cannot read (Kaj → operation) renders as text; check `useSystemActions()`. Handler pickers on protected tickets list only users with protected-data access.
- **Routes.** Index routes with nothing to render use `component: () => null`. English URL paths; `staticData.title` in Swedish; system pages under `/system/...`.
- **Time.** Timestamps from the API are instants; render with `.tz(SWEDISH_TIME_ZONE)`; offset-less input is UTC (`dayjs.utc(value)`). Specs that depend on "now" pin the clock with `page.clock.setFixedTime`.
- **Hoisting and early returns.** `Intl.*` formatters and other expensive constants at module level, not in the component body. Early return when the entity is missing.

### Pass C — Tests

The conventions are in `.claude/skills/priis-frontend-testing/SKILL.md`; the review-specific checks are:

1. **Pure logic has a unit spec.** Schema parsing, codecs, state transitions, formatters → `*.unit.spec.ts` in the browserless `unit` project; the hook keeps the React wiring. A unit spec that fills in fields the real wizard never populates proves nothing about the wiring; say so.
2. **Interaction has a browser spec.** A new popover, modal, filter or toggle without a spec is a finding. Mock-first specs with `mocks.ts` builders are the norm; the spec asserts the PUT/POST body when the change is about what gets sent, and asserts that *no* request was sent on a blocked save.
3. **Regression specs for the bugs the review found.** When a finding is fixed, ask for the spec that fails without the fix.
4. **Narrow add-on specs.** A new spec whose setup repeats an existing spec's setup to assert one extra element → extend the existing spec. Table-driven `for (const { name, flags } of cases)` over copies.
5. **The failing branch is tested.** The second arm of a helper, the empty state, the disabled state. Name the input no spec produces.
6. **Test ids and fixtures.** New `data-testid` values in `e2e/test-ids.ts`; new mock options added to the existing builder; `test`/`expect` from `$e2e/fixtures`; constants imported from `./mocks`, not redeclared; `runId` suffix on data that must be unique.

### Pass D — Contract and cross-repo

With the counterpart from Step 1c in scope, check both sides in code:

- `openapi/swagger.json`: generated against the backend branch *with main merged*, or hand-patched? Either is fine when the description says which. A stale snapshot (old enum values, old parameter names) is a finding.
- Backend DTOs vs frontend types and e2e mocks: field names, `required` vs optional, enum members, query parameter names, ids in route vs body.
- New `SystemAction` or `PageCode`: `npm run codegen:refresh` was run; `top-menu-items.ts` and the relevant `ResourceDetails.Tab` carry the action; the parent menu item's `actions` union includes it.
- Constants mirrored from the backend (max lengths, `MaxCustomRangeDays`): the frontend validates the same bound.
- Supplier-side pages (token reply, inquiry profile) render any new backend field the signed-in pages render.
- Agreement is one line in the report ("Contract checked against !NNNN: consistent"); a mismatch is a finding. A contract change whose other side was excluded or is missing is a finding naming why it was not checked.
- Version skew between frontend and backend is **not** a finding: the team deploys both together (recorded decision).

### Pass E — Spec and text that drifts from the code

- **Acceptance criteria.** Tick the Step 2 checklist against the diff: *missing or partial* (promised, not implemented), *wrong* (implemented, but not what the AC or mockup says), *unannounced* (user-visible behaviour the story never asked for, including "de-clutter" choices an AI made on its own), *stale* (the description describes an earlier revision). Quote the AC line in the finding.
- **PR description vs code.** "Reuses the same copy", "regenerated", "blocked in the form": read the code behind each claim.
- **Strings and JSDoc.** A string documented as used in two places but used in one. Copy that names the wrong entity. Labels that differ for the same concept across screens.
- **Comments.** A comment that describes an earlier design, narrates a ticket number instead of the rule, or cross-references sibling code as justification. A comment left inaccurate by the change is Should-fix; a history-narrating one is Minor.
- **Rulebook and skills.** When the PR adds a shared component or changes a convention, `.github/copilot-instructions.md` and the relevant `.claude/skills/*/SKILL.md` must mention it, or the next PR copies the old pattern again.
- **Scope.** Larger cleanups discovered in review (removing `pages.ts`, a user popover card) become their own story; say so instead of stretching the PR.

### Pass F — Click through the running app (unless `--no-browser`)

About a third of the frontend review threads in the sample (~35 %, the largest theme in the lessons table) came with a screenshot of something the diff could not show, so this pass is on by default. It needs three things. Check them first; if any is missing, do not improvise a setup: write `Clicked through: skipped (<what was missing>)` in the report and move on.

1. **A browser tool.** The Playwright MCP server (`@playwright/mcp`, tools `mcp__playwright__browser_*`) or Claude in Chrome. Neither comes from repo config; it is registered per user (`claude mcp add playwright -- npx -y @playwright/mcp@latest`).
2. **The backend.** `http://localhost:5033/healthz` answers 200 (AppHost or API started from the backend repo). Nothing here starts it.
3. **Dependencies in the worktree.** `npm ci` in `<worktree>/source/priis-web` (a full install per fresh worktree; remove the worktree with `--force` afterwards).

Then start the app from `<worktree>/source/priis-web` with `VITE_PORT=5682 VITE_STRICT_PORT=true npm run dev` (PowerShell: `$env:VITE_PORT=5682; $env:VITE_STRICT_PORT='true'; npm run dev`). The explicit port keeps it off the developer's own server on 5681, and `strictPort` makes it fail instead of silently moving to the next free port (`vite.config.ts` only sets `strictPort` when `VITE_STRICT_PORT=true`). Open `http://localhost:5682`, sign in with the dev user switcher as the persona the story names, and walk the changed screens:

- Every new control in every state: empty, filled, loading, error, disabled; buttons that copy or reset; collapse/expand while a filter is active.
- The same information on neighbouring screens is presented the same way (`100 % (4 av 5)` on both statistics pages; timestamps on all events or none).
- Spacing, label placement, two-column layouts at the breakpoints, long text in textareas, PDF page breaks if a PDF is produced.
- Mobile width (375 px) and keyboard-only navigation (focus after state changes, tooltips reachable).
- Links the current persona may not follow.

Attach what you saw to the finding as a short reproduction path; a screenshot is optional. Stop the dev server before the worktree is removed.

### Pass G — Conventions and modern idioms

The passes above are what history says we miss. This pass is the general lens, so the review also holds code that no earlier PR happened to get wrong.

1. **Load the convention skills for the areas the diff touches** and check the changed code against them, section by section: any component or route → `priis-frontend-component-patterns` (path aliases and `~/utility`, Radix first, CSS Modules, file naming, modal pattern, `Controlled.*`, accessibility, Swedish text, mobile responsiveness, anti-patterns); schemas and forms → `priis-frontend-forms`; endpoint builders and hooks → `priis-frontend-rtk-query`; routes → `priis-frontend-routing`. A skill section the diff violates is a finding with the skill path as the rule; a preference the skills do not state is a question at most.
2. **General quality, independent of the skills.** Read each changed file once with these in mind:
   - Derived values are computed in render or `useMemo`, not copied into state by an effect; an effect that only sets state from props is a finding.
   - Effects have complete dependency arrays and a reason to exist (subscriptions, imperative APIs, syncing with something outside React); fetching belongs in an RTK Query hook.
   - State lives at the right level: URL search params for filters and tabs that should survive reload, the form for form values, Redux only for cross-page state; no duplicated state that can drift.
   - Lists have stable keys (ids, not indexes) when items reorder or are removed.
   - Components stay presentational where they can: data access through hooks at the route or feature boundary, props typed from the API types, no prop drilling past two levels when context or a hook fits.
   - TypeScript: narrow with type guards and discriminated unions, no `as` casts to silence the compiler, no non-null `!` on API data that can be null, `satisfies` for request bodies and config objects.
   - Loading, empty and error states exist for every new query; errors surface through the shared components (`Alert`, error boundaries), not `console.error`.
   - Accessibility beyond the skill: focus management after modals and moves, `aria-label` on icon-only buttons, labels bound to inputs, keyboard reachability of anything clickable, no interactive element nested in another.
   - Performance: no expensive object or formatter created per render, no inline function identity passed to memoised children when it matters, large lists virtualised or paginated.
   - Dates and numbers only through `~/utility/date` and `~/utility/format`; all visible text Swedish; English only in URLs and code.
   - Generated files untouched; facades scaffolded by codegen committed, not hand-edited back.
   - Dead code: unused props, options, strings and test ids introduced by the PR.
3. **Smell baseline (judgement calls).** Our reviews already use these labels, so use the same words. Each is Minor unless you can name the concrete defect or maintenance cost; a documented repo convention overrides the baseline; skip anything tooling enforces.

   | Smell | Flag when | Fix |
   |-------|-----------|-----|
   | Mysterious Name | the name does not say what it does or holds | rename; if no honest name comes, the design is murky |
   | Duplicated Code | the same logic shape in more than one hunk or file (Pass A owns this) | extract the shared shape |
   | Feature Envy | a component or hook reaches into another feature's data more than its own | move it where the data lives |
   | Data Clumps | the same few props or fields travel together | one type |
   | Primitive Obsession | a string or number stands in for a domain concept | a small type or enum facade |
   | Repeated Switches | the same switch on the same enum recurs | one shared map in the facade |
   | Shotgun Surgery | one logical change forces scattered edits (defaults, types, slice, schema) | gather what changes together |
   | Divergent Change | one module edited for unrelated reasons | split by reason to change |
   | Speculative Generality | props, options or hooks the story does not need | delete; inline until a need shows |
   | Message Chains | long `a.b?.c?.d` navigation | hide the walk behind one selector or hook |
   | Middle Man | a component, hook or helper that mostly delegates | cut it, call the target |
   | Refused Bequest | a wrapper ignores most of what it wraps | composition |
4. **Leave the grep-able anti-patterns to `/priis-frontend-verify`** (relative imports, `zod/v4`, inline styles, `@ts-ignore`, `any`, `console.log`, raw `fetch`, hardcoded English). Say once that `/priis-frontend-verify` should be run if it clearly was not; do not list its hits as findings.

---

## Step 4 — Verify before you report

For each candidate finding:

1. **Re-open the cited `path:line`** in the worktree and confirm the code says what the finding claims. Fix drifted line numbers.
2. **Try to refute it.** Look for the guard, caller, schema, selector or spec one layer up that makes it a non-issue. If you find one, the finding is refuted: drop it, or keep it as Minor if the near-miss is worth knowing.
3. **Trace the failing path** with concrete inputs. If you can, the finding is **Verified**; if part of the path could not be confirmed by reading (runtime data, backend behaviour, a browser run you did not do), it is **Plausible**, and the finding says what would confirm it.
4. **Scope.** Is it on changed lines, or does the PR claim to fix it? Pre-existing problems go under "Not raised" unless the PR makes them worse.
5. **Tooling.** Would `tsc`, ESLint, Prettier or CI catch it? Drop it.
6. **Rule.** Does the rulebook or a skill actually say so? Unwritten style is a question, not a finding.
7. **Already answered** in an existing thread or in the description? Drop it, or reply in that thread.

Drop anything under 50 % confidence.

---

## Step 5 — Report

Mirror the format our reviewers already use in ADO so findings can be pasted as threads. Severity: **Blocking** (wrong behaviour, data or access, broken contract), **Should fix** (duplication with real cost, documented-convention breach, stale cache, missing spec, AC missing or wrong, stale doc), **Minor** (naming, comments, copy, smell judgement calls). Rank within each axis on its own merits; a clean Standards result does not soften a Spec gap.

```markdown
## Review: <PR title or branch> (vs <base>)

**Skill:** repo-local `/priis-frontend-review` (`.claude/skills/priis-frontend-review/SKILL.md`)
**Intent:** <three lines>
**Reviewed head:** `<source-ref>` @ `<short-sha>` from <snapshot worktree (removed) | live checkout>. Local checkout: <same commit | ahead N / behind M | on <other-branch>>. Untracked, read live: <files | none>
**Counterpart:** <GR.PRIIS.Backend !NNNN reviewed | found, not reviewed | expected but missing | single-repo change>
**Sibling compared:** `<path>`
**Existing threads:** <n human> (skipped <m> already raised)
**Sources:** <rulebook, skills loaded, work item(s), AC and mockups present or not>

### Findings
1. **<Short title>** — `src/.../file.tsx:42` — Blocking · Correctness · Verified
   <What is wrong, in one or two sentences.>
   Failing path: 1) … 2) … 3) …
   Rule: <rulebook/skill section, AC line, or sibling file>
   Fix: <concrete suggestion, with a short code block when it helps; or "Decision needed:" with the options>

### Minor findings (non-blocking)
- `path:line`: … (at most 8; then "+N more of the same kind: <kinds>")

### Praise
- <one to three things done well; omit if nothing stands out>

### Tests
Unit specs for pure logic: … · Browser specs for new interaction: … · Untested branches: … · Add-on candidates: …
(List each component, hook or schema the PR adds or changes with the spec that covers it, or "untested".)

### Acceptance criteria
- [x] <AC line> — <where>
- [ ] <AC line> — missing / wrong (see finding N)

### Contract check vs !<backend PR>
Consistent / differences: …

### Clicked through
<screens and personas, anything odd; or "skipped (--no-browser | no browser tool | backend not on :5033 | npm ci failed)">

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
   🤖 *AI review (Claude Code `/priis-frontend-review`), read and approved by <the user's name> before posting.*
   ```

   Then the finding. The marker is not optional and is never shortened to a bare emoji: the reader must be able to tell at a glance which comments a person wrote and which were produced by the skill, and who vouched for them. If the user pastes findings from the report into ADO by hand, remind them once to keep the marker.
4. Post with `repo_pull_request_thread_write` `create`: `filePath` is repo-root relative with a leading slash (`/source/priis-web/src/...`), `rightFileStartLine` the line in the PR's version. One thread per finding; collect the minor findings in one thread titled "Minor findings (non-blocking)"; general findings go in a thread without `filePath`.
5. Do not change thread status, vote or reply on the user's behalf; the author resolves and the user votes.

Fallback without MCP: `az devops invoke --http-method POST --resource pullRequestThreads --route-parameters project=PRIIS repositoryId=GR.PRIIS.Frontend pullRequestId=<id> --api-version 7.1 --in-file thread.json`.
