---
name: code-review-priis-profile
description: "[Project: GR.PRIIS] Command profile adapting /code-review to PRIIS conventions: maps backend/frontend review checklists to review axes, applies lessons-from-prs rules, counterpart pathspecs, hotfix branch rules, and verification handoffs. Load with code-review when reviewing PRs in the GR workspace. Load ONLY when working on GR.PRIIS or in the GR repository."
user-invocable: false
---

# `code-review-priis-profile` — PRIIS project profile for `/code-review`

Reference data for the general `code-review` skill (`/code-review`). It does not own steps, gates, the snapshot or the report structure — those are `/code-review`'s. Each section below is keyed to the `/code-review` step it feeds and answers one of its _Project profile_ fields. Facts marked _verified <date>_ were checked on that date; when the upstream has moved on, follow it and update the date here.

The shared PRIIS fields — Layout, Tracker, PR tooling (MCP server, `az` fallbacks, repository ids), Pattern skills per layer, Sibling chain, Contract touchpoints, Report language, Known drift — are in the `priis-profile` skill › _Profile fields_. Load it first; nothing here restates them.

The review checklists belong to the PRIIS team. They live in `GR.PRIIS` under `.claude/skills/priis-<side>-review/` and change through team PRs. The registry keeps no copies (`priis-profile` › _Known drift_).

---

## Profile fields

| Field                         | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Shared fields**             | See the `priis-profile` skill › _Profile fields_.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **PR tooling**                | `priis-profile` › _PR tooling_.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **Counterpart pathspecs**     | n/a — monorepo; both halves are in the one diff (`priis-profile` › _Layout_).                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **Review base exceptions**    | Hotfix branches target `origin/release/<major>.<minor>.X` (e.g. `origin/release/2.10.X`), not `origin/main`. Use the PR's `targetRefName`; for a branch without a PR, ask when its name starts with `hotfix/`.                                                                                                                                                                                                                                                                                                                        |
| **Sibling hints**             | Backend: another statistics endpoint, the other ticket types (`FeedbackTicket`, `RegisterTicket`, `ControlTicket`), the sister job in the same folder, the matching endpoint for the other reply path. Frontend: the other statistics pages, the other ticket types (`feedback-ticket`, `register-ticket`, `control-ticket`), the other wizard that reuses the same step, the sister modal. Most duplication findings in the team's history came from putting new code next to its sibling; name the sibling in _Summary of Changes_. |
| **Review checklists**         | See _Step 3 — Review checklists_.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **Lessons catalogs**          | See _Step 3 — Lessons catalogs_.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Axis and severity mapping** | See _Step 5 — Axes and severity_.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **Report additions**          | `### Test Coverage`, then `### Acceptance Criteria` — see _Step 8 — Report_.                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **Hand-offs**                 | See _Hand-offs_.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |

### Precedence overrides for the team's review skills

The checklists come from Commands with their own procedure. Under `/code-review`, its steps win wherever the two disagree:

| #   | The review skill says                                                                                  | Under `/code-review`                                                                                                                                                                         |
| --- | ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C1  | Snapshot in `.claude/worktrees/review-<slug>` and `EnterWorktree`                                      | `/code-review` Step 1b (`git-worktrees` snapshot mode). Ignore the review skills' Step 1d                                                                                                    |
| C2  | Pass F: `npm ci`, a dev server on :5682 and clicking through                                           | Not run. See _Hand-offs_                                                                                                                                                                     |
| C3  | Four tags: Correctness, Standards, Spec, Tests                                                         | Three axes. See _Step 5_                                                                                                                                                                     |
| C4  | Read PR threads up front to skip already-raised items                                                  | Threads only with `feedback`, after Step 6. The lessons' recorded decisions still apply in Step 6                                                                                            |
| C5  | Blocking / Should fix / Minor, ADO-pasteable report, `--comment` posting                               | `/code-review`'s artifact and severities. Posting is `/pr-post-comments`                                                                                                                     |
| C6  | Counterpart None → "single-repo change" only                                                           | `/code-review` also switches the other repo to its default branch (`pr-counterpart`)                                                                                                         |
| C7  | Load `priis-backend-modern-csharp`; test conventions in `.claude/skills/priis-<side>-testing/SKILL.md` | Load the repo skills `priis-backend-testing`, `priis-frontend-testing` (the upstream, `priis-profile` › _Known drift_) and the registry `modern-csharp` (`priis-profile` › _Pattern skills_) |

Ignore the review skills' Steps 1, 2, 4, 5 and 6, their _Usage_ and _Invariants_, every "run every pass" and sub-agent instruction, and their `allowed-tools`. `/code-review` owns all of that.

---

## Step 3 — Review checklists

Read per `project-profile` › _Upstream content_, from `GR.PRIIS` (the side(s) the diff touches):

```bash
git -C <repo> show origin/main:.claude/skills/priis-backend-review/SKILL.md      # GR.PRIIS, backend/
git -C <repo> show origin/main:.claude/skills/priis-frontend-review/SKILL.md     # GR.PRIIS, frontend/
```

Keep only these sections (headings exact, _verified 2026-10-20_ on `origin/main` @ `970b7c19` backend, `5726e81c` frontend), and file each under its axis:

| Heading                                                | Backend | Frontend | Axis        | Notes                                                                                                                                                                               |
| ------------------------------------------------------ | :-----: | :------: | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `### Pass A — Reuse and duplication (highest yield)`   |   ✅    |    ✅    | Standards   | Its _Need / Already exists / Do not accept_ table is the core. Check "already exists" against the review's **base**, not `origin/main`: some symbols exist only on a release branch |
| `### Pass B — Domain correctness`                      |   ✅    |          | Correctness | Query filters, protected data, state machines, audit trail, transactions, jobs                                                                                                      |
| `### Pass B — Behaviour and state`                     |         |    ✅    | Correctness | RTK Query tags, form wiring across entry points, Zod, RHF, payload shape, access in the UI                                                                                          |
| `### Pass C — Tests`                                   |   ✅    |    ✅    | Standards   | An untested failing branch is Correctness instead (_Step 5_)                                                                                                                        |
| `### Pass D — Contract and cross-repo`                 |   ✅    |    ✅    | Standards   | Against the counterpart in code, per `/code-review` _Heuristics_                                                                                                                    |
| `### Pass E — Spec and text that drifts from the code` |   ✅    |    ✅    | Spec        |                                                                                                                                                                                     |
| `### Pass G — Conventions and modern idioms`           |   ✅    |    ✅    | Standards   | Items 1–3 only. Item 1's skill list is replaced by `priis-profile` › _Pattern skills_ (C7). Item 4 is a hand-off                                                                    |

Excluded: ``### Pass F — Click through the running app (unless `--no-browser`)`` (frontend, C2).

## Step 3 — Lessons catalogs

```bash
git -C <repo> show origin/main:.claude/skills/priis-<side>-review/references/lessons-from-prs.md
```

Read once per review. Every entry is a pattern, how it was detected, the accepted fix and the PR it came from. Use the entries as Standards and Correctness evidence ("Rule:" lessons `<n.n>`, `!<pr>`). These sections record decisions and feed Step 6's refute check:

- Backend: `## 8. Scope and product decisions surfaced in review`
- Frontend: `## 7. Decisions recorded in threads (do not re-raise)`

Also a decision, from `priis-profile`: version skew between frontend and backend is not a finding (they deploy together).

## Step 3 — Standards sources

Besides the above: the rulebooks per half (`backend/CLAUDE.md`, `frontend/CLAUDE.md` → `.github/copilot-instructions.md`), `backend/.github/copilot-instructions.md` › _Cross-half contracts_, and the pattern skills for the areas the diff touches (`priis-profile` › _Pattern skills_). The repo-root `.claude/skills/` are the upstream (`priis-profile` › _Known drift_); cite them, plus the registry `modern-csharp`.

---

## Step 5 — Axes and severity

| Review-skill tag                                                                                                                                                  | `/code-review` axis |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| Correctness (Pass B)                                                                                                                                              | Correctness         |
| Standards (Passes A, D, G)                                                                                                                                        | Standards           |
| Spec (Pass E)                                                                                                                                                     | Spec                |
| Tests (Pass C), missing coverage a testing skill or Pass C requires (401 / 403 / happy path per endpoint, a spec for new interaction, a unit spec for pure logic) | Standards           |
| Tests (Pass C), a failing branch, guard or rollback path no test exercises                                                                                        | Correctness         |

| Review-skill severity | `/code-review` severity |
| --------------------- | ----------------------- |
| Blocking              | 🔴                      |
| Should fix            | 🟡                      |
| Minor                 | 🟢                      |

The review skills' _Smell baseline_ is the same Fowler table as `/code-review` Step 3; use `/code-review`'s.

---

## Step 8 — Report

Language: `priis-profile` › _Report language_ (English; Swedish UI copy and AC lines quoted verbatim). _In Plain Terms_ stays simple English as `/code-review` says.

Report additions, inside `## Detailed Review Findings` after `### 🟢 Minor Findings`:

- `### Test Coverage`:
  - Backend: a table of every endpoint the diff adds, × 401 / 403 / happy / negative-asserts-null. With no new endpoints, list each endpoint whose response or validation changed with the test that asserts it, or "untested".
  - Frontend: one line each for unit specs for pure logic, browser specs for new interaction, untested branches, and add-on candidates.
  - Each gap that is a finding links to it.
- `### Acceptance Criteria` — the checklist from the Spec source: `- [x] <AC line> — <where>` / `- [ ] <AC line> — missing / wrong (see finding N)`. When the work item has no AC field, say what was used instead.

---

## Hand-offs

- **Grep-able anti-patterns** belong to `priis-backend-verify` / `priis-frontend-verify` (`.Include` + `AsNoTracking`, `new List<`, `.Result`, relative imports, `zod/v4`, `any`, `console.log`, …). Say once in the chat response that the verify skill should be run if it clearly was not; do not list its hits as findings.
- **Clicking through the running app** is out of `/code-review` (C2). For UI changes, suggest `/manual-testing` for a runnable click path, or running the team's `priis-frontend-review` itself, whose Pass F covers it. The team's lessons put about a third of frontend review threads here, so say it in the chat response for every frontend diff that changes a screen.
- **PR threads**: when the PR has human threads, suggest the `feedback` modifier (C4).
- **Posting** findings to the PR: `/pr-post-comments`.

---

## Quick reference

| Topic                | Use                                                                  | Not                                                     |
| -------------------- | -------------------------------------------------------------------- | ------------------------------------------------------- |
| Review checklists    | `git show origin/main:.claude/skills/priis-<side>-review/SKILL.md`   | the registry copy, the reviewed head, the main checkout |
| Lessons              | `git show origin/main:…/references/lessons-from-prs.md`              | memory of past reviews                                  |
| Snapshot             | `/code-review` Step 1b                                               | `.claude/worktrees/review-<slug>` + `EnterWorktree`     |
| Click-through        | `/manual-testing`, or `priis-frontend-review` Pass F                 | `npm ci` + dev server inside `/code-review`             |
| Tests tag            | Standards (missing coverage) / Correctness (untested failing branch) | a fourth axis                                           |
| Severity             | 🔴 / 🟡 / 🟢                                                         | Blocking / Should fix / Minor                           |
| C# conventions       | `modern-csharp`                                                      | `priis-backend-modern-csharp`                           |
| Hotfix base          | the PR's `targetRefName` (`origin/release/<x>.X`)                    | `origin/main`                                           |
| Already-exists check | grep the review's base                                               | `origin/main` only                                      |
