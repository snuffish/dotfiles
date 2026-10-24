---
name: manual-testing
description: "Writes a runnable manual test plan artifact (<prefix>-manual_test_plan-<suffix>.md) for the current branch, a PR or a work item — environment setup, blocking gotchas, test logins, seeded records, risk-ordered click-path scenarios with checkboxes, a regression watchlist and what cannot be tested by hand. Reads the PR description, linked work item and acceptance criteria first, finds the counterpart PR in a sibling repo, then derives every scenario from the actual diff. Trigger on /manual-testing, \"how do I try this out\", \"how do I test this branch/PR\", \"which credentials do I log in with\", \"what should I click to see this\"."
---

# Skill: `/manual-testing` — Manual Test Plan From the Diff

Answers *"how do I see this change working with my own eyes?"* for the current branch, a PR or a named feature.

The deliverable is a **test plan a human executes**, written as an artifact at the workspace root. It is not a summary of the code. Every scenario ends at something observable: a screen, a badge, a number, an email, a row in a table, an HTTP response.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-manual_test_plan-<suffix>.md` (suffix `<workItemId>-<slug>`, e.g. `-31071-unverified-addresses`; else the branch slug)
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`

> [!CAUTION]
> **ABSOLUTE RULES**
> 1. **Artifact first.** Every run writes a new artifact through *Claim* and never overwrites another session's plan. The chat reply begins with its link and section anchors (§4).
> 2. **Read-only.** Inspect with `git`, `cat`, `grep`, `ls` and read-only tracker CLIs. Never install, build, migrate, seed or start the app unless the user explicitly asks, because a half-run setup is worse than none. Never enter planning mode or produce an implementation plan.
> 3. **Never invent** a URL, port, username, password, route or record. Quote the real value with a file link. When you cannot find it, write `not found — checked <where>`.
> 4. **Never fix** a defect you find while writing the plan. It goes in the regression watchlist.
> 5. **Label destructive setup** in the same sentence that recommends it ("recreate the database — **destructive**, wipes local data"). The user decides.
> 6. **Secrets:** development-only values (seeded demo users, local container passwords, `.env.example`) may be quoted. For anything that looks production-grade, point at its location and do not print it.

---

## 1. When to Use

The argument is a **pointer to the intent**. Resolve it in Step 1 before touching the diff:

| Argument | Meaning |
|---|---|
| PR URL | That PR: description, linked work items, source branch |
| Bare number (`18106`) | A PR id in the current repo's remote |
| `#30342`, `AB#30342` | A work item / issue: read it, then find its PR or branch |
| Branch name | Diff that branch instead of `HEAD` |
| Free text (`the statistics tab`) | Narrow the plan to scenarios touching that area |
| *(none)* | Current branch plus uncommitted changes. Still resolve each repo's PR from its branch |

| Situation | Use instead |
|---|---|
| Finding bugs and convention breaches in the diff | [`/code-review`](../code-review/SKILL.md) |
| Does the code cover every line of the story? | [`/spec-verification`](../spec-verification/SKILL.md) |
| Lint, build and test gates | the project's verify skill |

---

## 2. Workflow

Each step feeds one part of the artifact:

| Step | Feeds |
|---|---|
| 1. Resolve the intent | Context, scenario wording |
| 2. Pin the scope | Context (branch and head per repo) |
| 3. Diff → observable behaviour | Scenarios |
| 4. Trace consumers | Regression watchlist |
| 5. Find how to run it | Setup |
| 6. Find logins and test data | Logins, Test data |
| 7. Setup gotchas | Before you start, scenario preconditions |

### Step 1 — Resolve the intent

Skip only when there is no argument **and** the branch name or commit subjects already state the intent.

A diff tells you what changed. The PR description and acceptance criteria tell you **what a human should be able to do afterwards**, which is exactly what a test plan asserts. They turn "click the new tab" into "the AC says the selected-count sits under Ja-svar, so verify that placement".

**Resolution is delegated** to the **`pr-host`** Module. Follow it as written: *Parse a PR or work-item URL*, *Resolve the PR from a branch*, *Fetch the PR, its work items and acceptance criteria* (with its trust rule: **the description states intent, the diff states truth**) and *When a fetch fails*.

Run it **once per repo**, even when the user pasted one PR link. Then run the counterpart lookup in `pr-counterpart` › *Counterpart discovery*:
- A **found** counterpart adds its branch to Setup and its behaviour to Scenarios.
- An **expected but missing** half goes in *Before you start*, because that half's behaviour cannot be tested yet.
- A **stacked** PR (targets another feature branch) means the local branch carries both PRs. Say which scenarios belong to which PR.

| From the PR / work item | Use it for |
|---|---|
| Title, ids, AC present or absent | Context |
| **Acceptance criteria** | One scenario per criterion, in the AC's own words |
| "How to test" / "Verification" sections | Fold in directly; the author knows the click path |
| Screenshots / mockups | Expected-result wording |
| Explicit out-of-scope notes | *Not manually testable* |
| Linked bug reports | A reproduction scenario for the original defect |

Applying the trust rule to a test plan:
- AC promises behaviour the diff does not implement: still write the scenario, with the expectation *claimed but not implemented — expect this to fail*.
- The diff changes user-visible behaviour the description never mentions: it earns a scenario, usually a high-risk one.
- The description was written against an earlier revision: follow the diff and say the description is stale.

The description is evidence, not an outline. Never let its structure or omissions shape the plan.

### Step 2 — Pin the scope

Reuse code-review Step 1's diff and base discovery, including its rule that a resolved PR's `targetRefName` *is* the base. Otherwise use the remote default branch. Never use `@{u}`: on a feature branch that is its own remote copy and yields an empty diff. Always use three-dot syntax.

```bash
git symbolic-ref --short refs/remotes/origin/HEAD   # → <base>
git diff --name-status <base>...HEAD
git diff --stat                                     # uncommitted work counts: the user tests what is on disk
git log --oneline <base>...HEAD                     # subjects usually name the work item
```

**Multi-repo workspaces:** check every repo.

```bash
for d in */; do [ -d "$d/.git" ] && echo "$d $(git -C "$d" rev-parse --abbrev-ref HEAD)"; done
```

A feature split across repos is testable only when **both** counterpart branches are checked out. State the branch each repo must be on. If one is still on the integration branch, lead with it: that is usually why a manual test "doesn't show anything". A repo with no PR is worth reporting too, because its half is either unpushed or not started.

### Step 3 — Translate the diff into observable behaviour

For each change, ask **who sees this, and where?** Discard changes with no observable consequence (refactors, renamed internals, test-only edits) and list them under *Not covered by design*, so the reader knows the plan is complete and not lazy.

| Change in the diff | What to test |
|---|---|
| New or changed endpoint, field, response shape | The screen that renders it, plus the empty/zero/null case |
| New enum member or changed enum semantics | Each member's rendered label, and what the UI shows for `null` |
| Validation added or relaxed | Submit the now-invalid input and read the message; submit the boundary value |
| Required/optional flipped on a request field | The form that omits it: does it still submit? |
| Permission / role / policy change | One role that **has** it and one that **does not** |
| Background job, cron, scheduler | When it fires, and how to stop it to observe the pre-state |
| Migration or data backfill | Pre-state and post-state on realistic data |
| Notification, email, SMS | Where the dev mail/SMS catcher is |
| New UI component | Loading, empty, error and long-content states; mobile width if the project cares |
| One-off CLI / admin run | Dry-run, a limited run, the full run, a re-run (idempotence), the failure exit code |
| **A signal that was removed** | Below. This is the highest-value case |

**Removed and repurposed signals.** A field that used to be nulled, zeroed, clamped or overwritten on some path, and no longer is, silently changes every consumer that read it as a sentinel. Hunt for these deliberately:

```bash
git diff $(git merge-base HEAD <base>)...HEAD | grep -E '^-.*(= *null|= *now|= *0|= *(true|false)|\.Clear\(\)|= *\[\]|= *undefined)'
```

For each hit, grep the whole codebase **and any sibling repo** for readers of that field, then check whether the diff updated them. Each reader it did not update is a scenario and a probable regression. Deleted comments are strong evidence: a removed `// cleared to indicate X` names the contract that just broke.

### Step 4 — Trace consumers of changed contracts

For every field, enum, route or DTO the diff touched:

```bash
grep -rn "<FieldName>" <source dirs> --include='*.<ext>'
grep -rn "<fieldName>" <sibling repo>/src
```

Sort the call sites:
- **Updated by this diff:** verify the new behaviour (Scenarios).
- **Not updated, but gated** by a status check, flag or permission: verify the gate still holds (Scenarios).
- **Not updated and ungated:** **regression watchlist**, with the file, line and what the user will see.

Also check **merge order** when the change ships as several PRs (counterpart or stacked). If one half can land before the other, write down what the user sees in between. One example is a frontend reading a field that only the base backend PR adds. That goes in the watchlist.

### Step 5 — Find how to run it

Never guess. Look in this order and stop at a working command:

1. **Project instructions:** `CLAUDE.md`, `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `docs/`, `.github/*-instructions.md`.
2. **Orchestrator:** Aspire AppHost, `docker-compose.yml`, `Procfile`, `Taskfile`, `Makefile`, `tilt`/`skaffold`. Prefer it over starting services one by one, and say what it starts. Check whether it also starts the sibling repo (for example a frontend from `../`). If it does, the user needs **one** command, not two.
3. **Scripts:** `package.json`, `*.csproj`/`*.sln` run targets, `pyproject.toml`, `justfile`.
4. **Ports and URLs:** read them from config, never from habit.
   ```bash
   grep -rn "port\|Port\|localhost:\|applicationUrl" <orchestrator/config/launchSettings>
   ```
5. **Prerequisites:** container runtime, toolchain pins (`.nvmrc`, `global.json`, Volta/`engines`), private feed auth.

Collect every URL the user needs: app, API and its docs, dashboard, mail catcher, database.

### Step 6 — Find logins and test data

```bash
grep -rni "password\|CreateAsync(user\|AddUser\|createUser" <seed/fixture dirs>       # seeded users
ls e2e/ tests/e2e/ cypress/ playwright/ 2>/dev/null                                 # e2e auth setup
grep -rn "login\|password\|storageState" **/auth.setup.* 2>/dev/null
cat .env.example .env.local 2>/dev/null                                              # env templates
grep -rn "password\|PASSWORD" docker-compose*.yml <orchestrator config> 2>/dev/null  # container passwords
```

Report:
- **Logins:** identifier, password, role, and *what each one is for*. The role column matters most, because the user needs the account that reaches the changed screen. Mark one recommended account.
- **MFA / SSO friction:** which accounts are frictionless and where codes go (mail catcher, log, fixed code). Recommend the frictionless one.
- **Seeded records:** the concrete entity (ticket, order, operation) whose state matches each scenario, with the seeder line. Read the seeded state: a record that already meets a job's trigger condition will change on its own.
- **Role mapping:** if the project documents personas, map the changed permission to one account that has it and one that does not.
- **Reset snippets:** if a scenario consumes its precondition (verifies, closes, terminates), give the read-only query to inspect state and the local command to restore it.

### Step 7 — Setup gotchas

Each item here pre-empts a "why doesn't it work?" question.

- **Migrations that fail on existing data.** Read new migrations for guard clauses (`THROW`, `RAISERROR`, thrown exceptions, precondition counts). If the old seeder's data violates them, the user must recreate the database (**destructive**). If startup gates on migrations, nothing boots. Lead with this.
- **Migrations that change existing rows' meaning**, for example a new nullable column that makes every existing row "unverified" or "unset". That pre-state is often the easiest scenario. It also disappears once a backfill runs, so order scenarios around it.
- **Seeder changes:** existing local data is stale in a way that matters.
- **Background jobs** that mutate the observed state: find the schedule and **which process hosts it**, and how to disable that process. A job that fires within a minute may also reproduce a scenario with zero manual steps.
- **Local fakes of external services** (mock clients, stub flags in `appsettings.Development.json`, MSW handlers). Read what the fake actually returns. It may make an outcome unreachable locally (a validator that never rejects), so name the outcomes that cannot be produced and how to force the others (config flag, SQL reset). Switching a fake to the real client is outward-facing: say so.
- **Tools run outside the orchestrator** (CLI, scripts) may read a different connection string, secret or environment than the orchestrated services. Check the tool's own config and override chain before giving its command.
- **Feature flags / config toggles** gating the new code.
- **Caches** (in-memory, distributed, HTTP, RTK Query/SWR tags) that hide a change until invalidated or restarted.
- **Codegen:** whether a changed API schema regenerates on dev/build or needs a command, and whether output is committed.
- **Quality gates that fail before the app starts** (zero-warning lint, typecheck in build). Name the file. It often blocks `build` but not `dev`.

---

## 3. Artifact `<prefix>-manual_test_plan-<suffix>.md`

Draft in the scratchpad, then publish with *Claim* (`publish_new_artifact`) so the owner marker is the first line. A re-run writes a new file (`…-2.md`) unless the user names an existing one to update.

````markdown
<!-- artifact-owner: <host>-<model> · session <id> · created <ISO-8601> -->
# Manual Test Plan — <title> (#<workItemId>)

| | |
|---|---|
| **Work item** | [#<id>](<url>) <title> · AC present / absent (PR descriptions used) |
| **PRs** | <repo> [!<id>](<url>) → `<target>` · <repo> [!<id>](<url>) → `<target>` (stacked on !<id>) |
| **Branches** | `<repo>`: `<branch>` @ `<sha>` · `<repo>`: `<branch>` @ `<sha>` · uncommitted changes: yes / no |
| **Counterpart** | Found / Found, excluded / Expected but missing / None |

**At a glance:** <N> scenarios (<n> 🔴) · log in as `<account>` · blocker: <one line, or "none">

> [!WARNING]
> **Before you start.** Only when a destructive or blocking prerequisite exists: what breaks, why, the exact command, and **destructive** if it destroys data.

## <a id="setup"></a>1. Setup

```bash
<minimal command sequence, each read from the repo>
```

| Service | Address | Source |
|---|---|---|
| App | http://localhost:<port> | [<config>](<path>#L<n>) |

## <a id="logins"></a>2. Logins

| | Account | Password | Role | Use for |
|---|---|---|---|---|
| ⭐ | `<id>` | `<dev password>` | <role / persona> | <which scenarios> |

## <a id="test-data"></a>3. Test data

| Record | Seeded state | Used in | Source |
|---|---|---|---|
| <name> | <state that matters> | S1, S4 | [<seeder>](<path>#L<n>) |

<inspect query and reset snippet, if a scenario consumes its precondition>

## <a id="scenarios"></a>4. Scenarios

| # | Scenario | As | Risk |
|---|---|---|---|
| [S1](#s1) | <claim> | `<account>` | 🔴 |

### <a id="s1"></a>S1 · <observable outcome, phrased as a claim>

**As** `<account>` · **Record** <seeded record> · **Risk** 🔴 <why: the Step 3/4 finding behind it>
**Given** <preconditions; omit the line if none>

1. <step: concrete route, UI labels in the app's language>
2. …

**Expect**
- [ ] <observable result>
- [ ] …

> ⚠️ **Watch for:** <the specific wrong output this change could produce; omit for a plain happy path>

## <a id="watchlist"></a>5. Regression watchlist

| Surface | Where | What you would see |
|---|---|---|
| <screen / API / merge order> | [<file>:<line>](<path>#L<line>) | <symptom> |

## <a id="not-testable"></a>6. Not manually testable

| What | Why not by hand | Safety net |
|---|---|---|
| <outcome / race / volume / third party> | <reason> | <test name, dry-run, staging — or "none"> |

## <a id="not-covered"></a>7. Not covered by design

- <refactor / test-only / internal change>: no observable effect.
````

**Layout rules**
- **Context** always appears, even for a plain current-branch run. The branch per repo answers "am I testing the right thing?".
- **Scenarios** are ordered **most-likely-to-be-broken first**, not in diff order. Each scenario is one observable claim. Six sharp scenarios beat twenty that restate the diff.
- **Risk:** 🔴 high (removed signal, ungated consumer, contract, permission, migration) · 🟠 medium (changed behaviour on an updated path) · 🟢 low (happy path, cosmetic).
- **Expect** lines are checkboxes, so the tester can tick them in the file.
- Order scenarios that **consume** a precondition (a backfill run, a status change) after the ones that need it, and say so in their *Given*.
- **Links:** code references are clickable `path#Lline` links in the host's format (`artifact-protocol` › *Link Formats*). In-document references use the HTML anchors (`#s3`, `#watchlist`).
- Quote UI labels and messages in the app's language. Write the rest in the conversation's language.
- *Before you start*, a scenario's *Given* and *Watch for*, and empty table rows are omitted when there is nothing to say. *Regression watchlist* is never omitted: write `None found — checked <what>` when that is the honest answer.

---

## 4. Chat Response

Begin with the artifact link and anchors. Read the line numbers off the written file with `grep -n '^## \|^# \|^> \[!' <file>`:

```markdown
📄 **[<prefix>-manual_test_plan-<suffix>.md](<prefix>-manual_test_plan-<suffix>.md)**

Key Sections:
- 📄 [Before you start](…#L<n>) · [Setup](…#L<n>) · [Logins](…#L<n>) · [Test data](…#L<n>)
- 📄 [Scenarios](…#L<n>): <N>, riskiest first
- 📄 [Regression watchlist](…#L<n>) · [Not manually testable](…#L<n>)
```

Then, in at most five lines of prose: the blocker (if any), the one start command, the recommended login, and the top watchlist items. Nothing else: the artifact carries the rest. If *Claim* added a counter, say so ("`…-2.md`: the base name is owned by another session").

---

## 5. Before Sending

A finished plan passes all of these:

- [ ] Every command was **read from the repo**, not recalled from habit.
- [ ] Every credential, port and route is quoted from a file linked in the artifact.
- [ ] Every scenario names a **specific seeded record**, not "a ticket".
- [ ] Scenarios are risk-ordered, and the riskiest exists *because of* Steps 3–4, not because it was the biggest hunk.
- [ ] If a PR or work item was resolved, **every acceptance criterion** is a scenario or is listed under *Not manually testable*. None is silently dropped.
- [ ] Every gap between what the description promised and what the diff delivers is stated, not smoothed over.
- [ ] Each 🔴 scenario has a *Watch for* line.
- [ ] Anchors resolve: the scenario index links match the `<a id>` tags.
- [ ] The user can run the whole plan without asking a follow-up question.

| Don't | Do |
|---|---|
| "Log in and verify the feature works." | Name the account, the route and the expected value. |
| Restate the diff as a checklist. | Test observable outcomes; list invisible changes under *Not covered by design*. |
| Assume `localhost:3000`, `admin/admin`. | Read the config and the seeder. |
| One scenario per changed file. | Group by user-visible behaviour; risk-order it. |
| Silently omit what can't be checked by hand. | List it under *Not manually testable* with its safety net. |
| Fix a bug spotted mid-plan. | Add it to the regression watchlist. |
| Take the PR description as the spec and skip the diff. | Description = intent, diff = truth; test the gap between them. |
| Ignore a PR URL, or guess its contents from the branch name. | Resolve it via code-review Step 1, or say the fetch failed and how to fix it. |
| Put the plan in chat. | Write the artifact; the chat carries the link and the five-line summary. |
