---
name: manual-testing
description: 'Writes a runnable manual test plan artifact (<prefix>-manual_test_plan-<suffix>.md) for the current branch, a PR or a work item — environment setup, blocking gotchas, test logins, seeded records, risk-ordered click-path scenarios with checkboxes, a regression watchlist and what cannot be tested by hand. Reads the PR description, linked work item and acceptance criteria first, finds the counterpart PR, then derives every scenario from the actual diff. `--seed-data` also creates the local records the scenarios need. Trigger on /manual-testing, "how do I try this out", "how do I test this branch/PR", "which credentials do I log in with", "what should I click to see this".'
argument-hint: "[PR url | PR id | #work-item | branch | area] [--seed-data]"
---

# Skill: `/manual-testing` — Manual Test Plan From the Diff

Answers *"how do I see this change working with my own eyes?"* by writing a human-executable test plan (`<prefix>-manual_test_plan-<suffix>.md`) in the artifact dir (`artifact-protocol`) where every scenario ends at an observable outcome (screen, badge, number, email, DB row, HTTP response).

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`; `--seed-data` opens Step 8's local data writes only
- `../_modules/artifact-protocol.md`: writes `<prefix>-manual_test_plan-<suffix>.md`
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`

**Rules**
1. **Artifact first**: publish via `artifact-protocol` › *Claim* and open chat with the `artifact-protocol` › *Chat link block*. Never produce an implementation plan.
2. **Read-only by default**: never install, build, migrate, start services, or modify code. `--seed-data` authorizes only Step 8's additive local-DB test records ([seed-data.md](references/seed-data.md)).
3. **Never invent** URLs, ports, credentials, routes, or records — quote real values with file links, or write `not found — checked <where>`. Quote dev-only credentials; never print production-grade secrets.
4. **Never fix** defects spotted while writing the plan; put them in the *Regression watchlist*.
5. **Label destructive setup** (`recreate the database — **destructive**, wipes local data`) in the same sentence that recommends it.

---

## 1. When to Use

| Argument / Flag | Meaning |
| --- | --- |
| PR URL / bare PR ID / `#work-item` | Resolve intent from that PR or work item (`pr-host`), plus its counterpart (`pr-counterpart`) |
| Branch name / free-text area / *(none)* | Diff that branch (or `HEAD` + uncommitted work), still resolving each repo's open PR from its branch |
| `--seed-data` | Run Step 8 ([seed-data.md](references/seed-data.md)) to create local test records and write scenarios around their real IDs |

| Situation | Use instead |
| --- | --- |
| Finding bugs and convention breaches in the diff | [`/code-review`](../code-review/SKILL.md) |
| Requirement-by-requirement traceability ledger | [`/spec-verification`](../spec-verification/SKILL.md) |

---

## 2. Workflow

### Step 1 — Resolve the intent

Resolve the PR, linked work items, and acceptance criteria per `pr-host` (*Parse a PR or work-item URL*, *Resolve the PR from a branch*, *Fetch the PR, its work items and acceptance criteria*, *When a fetch fails*) and `pr-counterpart` › *Counterpart discovery*:
- **Found counterpart**: include its branch in *Setup* and its behaviour in *Scenarios*.
- **Expected but missing counterpart**: flag in *Before you start*.
- **Trust rule**: AC promised but absent in diff → write scenario with expectation *claimed but not implemented — expect this to fail*; unannounced user-visible behaviour in diff → high-risk (`🔥`) scenario.

### Step 2 — Pin the scope

Resolve the diff base per `pr-host` › *Branch names & Diff base* (PR target `origin/$TGT` or `origin/HEAD`, never `@{u}`, three-dot `git diff <base>...HEAD`, plus `git diff --stat` for uncommitted local edits since the user tests what is on disk). In a multi-repo workspace (`pr-host` › *Resolve the PR from a branch*), report the checked-out branch per repo and warn if a sibling repo is still sitting on the default branch.

### Step 3 — Translate the diff into observable behaviour

Map each code change to who sees it and where (discard internal refactors/test-only edits into *Not covered by design*):
- **Endpoints, fields, enums**: screen rendering + empty/zero/null state + each enum label.
- **Validation & required/optional flips**: invalid input error message, boundary value, omitted optional field.
- **Permissions / roles**: one account that has the permission and one that does not.
- **Background jobs, migrations, notifications, UI states, CLI runs**: pre/post state, dev mail/SMS catcher, loading/empty/error states, idempotence.
- **Removed or repurposed signals (highest risk)**: search for removed null/zero/clear assignments:
  ```bash
  git diff $(git merge-base HEAD <base>)...HEAD | grep -E '^-.*(= *null|= *now|= *0|= *(true|false)|\.Clear\(\)|= *\[\]|= *undefined)'
  ```
  Grep all readers of those fields across the repo and sibling repos; any reader not updated in the diff becomes a `🔥` scenario and watchlist entry.

### Step 4 — Trace consumers of changed contracts

Grep all call sites of every touched field, enum, route, or DTO across repos:
- **Updated by diff** or **gated** → verify in *Scenarios*.
- **Not updated and ungated** (or cross-PR merge-order gap) → add to *Regression watchlist* with `path:line` and user-visible symptom.

### Step 5 — Find how to run it

Read the start command, orchestrator (Aspire AppHost, `docker-compose.yml`, `Makefile`, `package.json`), ports, and URLs from the repo's rulebooks and config files (`launchSettings.json`, `.env.example`, orchestrator config).

### Step 6 — Find logins and test data

Locate seeded users, dev passwords, MFA/SSO bypasses, and seeded entities from seeders, E2E auth setups (`auth.setup.*`), and `.env.example`. Provide read-only inspect queries and reset snippets for scenarios that consume their precondition.

### Step 7 — Setup gotchas

Check for: migrations that throw on existing seeded data (requiring a **destructive** DB recreate), nullable column additions that alter existing rows' meaning before backfill, background jobs that mutate state on a timer, local fakes/stubs that make certain outcomes unreachable locally, feature flags, caches, codegen steps, and build-blocking lint/typecheck gates.

### Step 8 — Seed the data (`--seed-data` only)

When `--seed-data` is passed, follow [seed-data.md](references/seed-data.md) to verify local-only targeting, create or reuse the required test records, read them back, and record their real IDs and undo commands.

---

## 3. Artifact & Chat Output

1. Publish `<prefix>-manual_test_plan-<suffix>.md` in the artifact dir (`artifact-protocol`) via `artifact-protocol` › *Claim*, following the structure and layout rules in [test-plan-template.md](references/test-plan-template.md).
2. In chat, emit the `artifact-protocol` › *Chat link block*, followed by a short summary: any blocker, the single start command, the recommended login, top watchlist items (and seeded record counts when `--seed-data` ran).

---

## 4. Verification & Validation

- Every command, port, route, credential, and seeded record is quoted from a linked repo file (never guessed).
- Scenarios are risk-ordered (`🔥` → `⚠️` → `🔹`), every AC is covered or in *Not manually testable*, and every `🔥` scenario has a *Watch for* line.
- With `--seed-data`: only a local DB was touched, every seeded record was read back, and undo commands are recorded.

| Don't | Do |
| --- | --- |
| Restate the diff as a checklist or assume `localhost:3000` / `admin`. | Test observable outcomes using real routes, ports, and accounts linked from repo files. |
| Fix a bug spotted mid-plan or silently skip untestable items. | Put bugs in *Regression watchlist* and untestable items in *Not manually testable* with their safety net. |
| Reseed or mutate existing records unasked under `--seed-data`. | Follow [seed-data.md](references/seed-data.md): create additive records via guarded tooling and ask before modifying existing data. |
