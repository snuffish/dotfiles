---
name: manual-testing
description: Triggered by /manual-testing or requests like "how do I try this out", "how do I test this branch/PR", "which credentials do I log in with". Derives a runnable manual test plan from the actual diff — environment setup, gotchas, test users, click paths, and a regression watchlist.
---

# Skill: `/manual-testing` — Manual Test Plan From the Diff

Produces the answer to *"how do I see this change working with my own eyes?"* — for the current branch, PR, or a named feature.

The output is a **test plan a human executes**, not a summary of the code. Every scenario must end at something observable: a screen, a badge, a number, an email, a row in a table, an HTTP response.

> **Never** enter planning mode and never produce an implementation plan. This skill reports; it does not change code.
>
> **Never** fix defects you find while writing the plan. Note them in the regression watchlist and move on — the user asked how to test, not for a patch.

---

## 1. Triggering

Invoke this skill when the user:

- Runs `/manual-testing`.
- Asks how to try out, run, demo, verify, or manually test the current branch / PR / feature.
- Asks which credentials, logins, seeded users, ports, or URLs to use.
- Asks "what should I click to see this?" or "how do I reproduce this?".

---

## 2. Guardrails

| Rule | Why |
|---|---|
| **Do not run** installs, builds, migrations, seeders, or the app itself unless the user explicitly asks. | The user is about to do this themselves; a half-run setup is worse than none. Read-only inspection only (`git`, `cat`, `grep`, `ls`). |
| **Flag destructive setup steps as destructive** and let the user decide. | "Recreate the database" wipes their local state. Say so in the same sentence you recommend it. |
| **Never invent** a URL, port, username, or password. | An invented credential costs the user ten minutes of doubt. If you cannot find it, say `not found — check <where you looked>`. |
| **Quote real values** found in the repo, with a file link. | Lets the user verify and lets them find the next one themselves. |
| Secrets that are clearly **development-only** (seeded demo users, local container passwords, `.env.example` values) are fine to quote. **Real** secrets are not — if a value looks production-grade, point at its location instead of printing it. | |

---

## 3. Phase 1 — Determine scope

Reuse the diff-gathering and branch-base discovery from [code-review](../code-review/SKILL.md) §1 rather than reinventing it: find the upstream tracking ref, fall back to `git merge-base` against the integration branch, and always use three-dot syntax.

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u}
git diff --name-status $(git merge-base HEAD <base>)...HEAD
git diff --stat                      # uncommitted work counts too — the user is testing their working tree
git log --oneline <base>...HEAD      # commit subjects usually name the work item / intent
```

Include **uncommitted changes**. The user is testing what is on disk, not what is pushed.

### Multi-repo workspaces

If the workspace root holds several repos (each with its own `.git`), check every one:

```bash
for d in */; do [ -d "$d/.git" ] && echo "$d $(git -C "$d" rev-parse --abbrev-ref HEAD)"; done
```

A feature split across repos is only testable when **both** counterpart branches are checked out. State explicitly which branch each repo must be on, and if one is still on the integration branch, say so up front — that is usually the whole reason a manual test "doesn't show anything".

---

## 4. Phase 2 — Translate the diff into observable behavior

For each change, ask: **who sees this, and where?** Discard anything with no observable consequence (pure refactors, renamed internals, test-only changes) — but say you discarded them, so the user knows the plan is complete rather than lazy.

| Change in the diff | What to actually test |
|---|---|
| New/changed endpoint, field, or response shape | The screen that renders it; also the empty/zero/null case |
| New enum member or changed enum semantics | Each member's rendered label, plus the value the UI shows when the field is `null` |
| Validation rule added or relaxed | Submit the now-invalid input and read the message; submit the boundary value |
| Required/optional flipped on a request field | The form that omits it — does it still submit? |
| Permission / role / policy change | Log in as a role that **has** it and one that **does not** |
| Background job, cron, scheduler | How long until it fires, and how to stop it firing so you can observe the pre-state |
| Migration or data backfill | Run it on realistic data; verify the pre-state and post-state |
| Notification, email, SMS | Where the dev mail/SMS catcher UI is |
| New UI component | Loading, empty, error, and long-content states; mobile width if the project cares |
| **A signal that was removed** | See below — this is the highest-value case |

### Removed and repurposed signals

The most valuable scenarios come from behavior the diff **stopped** producing. A field that used to be nulled, zeroed, clamped, or overwritten on some path — and no longer is — will silently change every consumer that read that value as a sentinel.

Hunt for these deliberately:

```bash
# In the diff, look for deletions that assigned a sentinel
git diff $(git merge-base HEAD <base>)...HEAD | grep -E '^-.*(= *null|= *now|= *0|= *(true|false)|\.Clear\(\)|= *\[\]|= *undefined)'
```

For each hit, grep the whole codebase — **and any sibling repo** — for readers of that field, then check whether the diff also updated them. Every reader the diff did *not* touch is a test scenario and a probable regression.

Deleted comments are strong evidence here: a removed line like `// cleared to indicate X` names the contract that was just broken.

---

## 5. Phase 3 — Trace consumers of changed contracts

For every field, enum, route, or DTO the diff touched:

```bash
grep -rn "<FieldName>" <source dirs> --include='*.<ext>'      # per language
grep -rn "<fieldName>" <sibling repo>/src                     # cross-repo consumers
```

Sort the call sites into:

- **Updated by this diff** → verify the new behavior.
- **Not updated, but gated by something else** (a status check, a feature flag, a permission) → verify the gate still holds.
- **Not updated and ungated** → **regression watchlist**. Name the file, the line, and what the user will see.

This phase is what turns a generic "click around the feature" list into a plan that finds real bugs.

---

## 6. Phase 4 — Discover how to run it

Never guess. Look, in this order, and stop when you have a working command:

1. **Project instructions** — `CLAUDE.md`, `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `docs/`, and any `.github/*-instructions.md`. A "Commands" or "Getting started" section usually has the whole answer.
2. **Orchestrator** — a single entry point that starts everything: an Aspire AppHost, `docker-compose.yml`, `Procfile`, `Taskfile`, `Makefile`, `tilt`/`skaffold` config. Prefer it over starting services one by one, and say what it starts.
3. **Scripts** — `package.json` scripts, `*.csproj`/`*.sln` run targets, `pyproject.toml`, `justfile`.
4. **Ports and URLs** — read them from config rather than assuming defaults. Grep the orchestrator and launch profiles:
   ```bash
   grep -rn "port\|Port\|localhost:\|applicationUrl" <orchestrator/config/launchSettings>
   ```
5. **Prerequisites** — container runtime, language/toolchain version pins (`.nvmrc`, `global.json`, Volta/`engines`), and whether a private package feed needs auth.

Produce a table of every URL the user will need — app, API/API docs, admin/dashboard, mail catcher, DB.

### Does the orchestrator already cover the sibling repo?

Some orchestrators start a frontend from a sibling directory. If so, both branches run together and the user needs **one** command, not two. Check before telling them to run two dev servers.

---

## 7. Phase 5 — Discover credentials and test data

Search, in this order:

```bash
# Seeded / fixture users, in seeders, migrations, and fixtures
grep -rni "password\|CreateAsync(user\|AddUser\|createUser" <seed/fixture dirs>

# E2E auth setup usually names the canonical test account
ls e2e/ tests/e2e/ cypress/ playwright/ 2>/dev/null
grep -rn "login\|password\|storageState" **/auth.setup.* 2>/dev/null

# Local env templates and container passwords
cat .env.example .env.local 2>/dev/null
grep -rn "password\|PASSWORD" docker-compose*.yml <apphost config> 2>/dev/null
```

Then report:

- A **table** of logins: identifier, password, role, and *what each one is for*. The role column is what makes it useful — the user needs the account that can reach the changed screen.
- **Second-factor / SSO friction.** If some accounts have MFA enabled and others do not, say which ones are frictionless and where the code is delivered (dev mail catcher, log output, fixed test code). Recommend the frictionless account.
- **Which seeded records to use.** Do not stop at "log in" — name the concrete demo entity (ticket, order, customer, operation) whose state matches the scenario, and cite the seeder line. Read the seeded state: a record that already satisfies a job's trigger condition will change on its own.
- **Authorization mapping.** If the project documents personas/roles, map the changed permission to the account that has it and one that does not.

---

## 8. Phase 6 — Setup gotchas

Check these before writing the plan; each one is a "why doesn't it work" support question you can pre-empt.

- **Migrations that can fail on existing local data.** Read any new migration for guard clauses that abort (`THROW`, `RAISERROR`, a thrown exception, a precondition count). Determine whether data produced by the *old* seeder satisfies them. If not, the user must recreate their database — and if the app's startup gates on migrations completing, nothing will boot. Lead with this.
- **Seeders that changed.** If the diff touched the seeder, existing local data is stale in a way that matters.
- **Background jobs.** If a cron/scheduled job mutates the state you want to observe, find its schedule and **which process hosts it**, then tell the user how to disable that process so they can see the pre-state. Also note the reverse: a job that fires within a minute may reproduce a scenario with zero manual steps.
- **Feature flags / config toggles** that gate the new code.
- **Caches** (in-memory, distributed, HTTP, RTK Query/SWR tags) that hide a change until invalidated or restarted.
- **Codegen.** If an API schema file changed, note whether the client regenerates on dev/build automatically or needs an explicit command, and whether generated output is committed or ignored.
- **Quality gates that will fail before the app starts** — a lint rule with zero-warning tolerance, a typecheck in the build. If the branch currently trips one, say so and name the file, since it will block `build` but often *not* `dev`.

---

## 9. Output format

Lead with the blocking gotcha if there is one. Otherwise lead with the setup command.

### ⚠️ Before you start
Only if a destructive or blocking prerequisite exists. State what breaks, why, and the exact command — labelled destructive if it destroys data.

### Setup
The minimal command sequence, with the URL/port table.

### Logins
The credentials table, with the recommended account marked.

### What to test
Numbered scenarios, ordered **most-likely-to-be-broken first**, not in diff order. Each one:

> **N. <observable outcome, phrased as a claim>**
> **Preconditions** — role, seeded record, flag/job state. Omit the line if there are none.
> **Steps** — numbered clicks/requests, concrete route paths, real record names.
> **Expected** — what a correct build shows.
> **⚠️ Watch for** — the specific wrong output this change could produce. Omit if the scenario is a plain happy path.

Keep it to the scenarios that earn their place. Six sharp scenarios beat twenty that restate the diff.

### Regression watchlist
Surfaces that read data whose meaning changed but were **not** updated by the diff. File link, line, and what the user will see. This is the section that finds bugs — do not drop it, and say "none found" if that is the honest answer.

### Not manually testable
Be explicit about what this plan cannot cover and why — migration behavior that needs a production-shaped backup, race conditions, timing windows, load-dependent paths, third-party integrations without a sandbox. Name the safety net that does cover it (integration test, dry-run script, staging) or flag that there is none.

---

## 10. Quality bar

A finished plan passes all of these:

- Every command was **read from the repo**, not recalled from habit.
- Every credential, port, and route is quoted from a file the user can open.
- Every scenario names a **specific seeded record**, not "a ticket".
- Scenarios are ordered by risk, and the riskiest one exists *because* of Phase 2/3 analysis — not because it was the biggest hunk.
- The user can execute the whole thing without asking a follow-up question.

### Anti-patterns

| Don't | Do |
|---|---|
| "Log in and verify the feature works." | Name the account, the route, and the expected value. |
| Restating the diff as a checklist. | Test observable outcomes; skip invisible refactors (and say you skipped them). |
| Assuming `localhost:3000`, `admin/admin`. | Read the config and the seeder. |
| Listing every changed file as a scenario. | Group by user-visible behavior; risk-order it. |
| Silently omitting what can't be checked by hand. | Put it under *Not manually testable*. |
| Fixing a bug you spotted mid-plan. | Add it to the regression watchlist. |
