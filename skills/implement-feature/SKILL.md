---
name: implement-feature
description: "Orchestrates end-to-end feature implementation, bug fixes, and user stories. Coordinates ticket intake, codebase research, implementation planning, execution in isolated worktrees, verification testing, self-review, and PR preparation according to repository-specific profiles and rulebooks."
argument-hint: "[--direct | /no-framing] [<ticket | description>]"
---

# Skill: `/implement-feature` — End-to-End Feature Implementation

Runs one piece of work from ticket to draft pull request, across one repository or every repository in a workspace.
This skill owns **the order of phases, the gates between them, and where sub-agents are used**. Everything else — code
patterns, test helpers, build and ship commands, tracker specifics — comes from the project itself: its rulebooks, its
project-scoped skills and, where they exist, its *profile skills* (see *Project profile*). Load those and read a sibling
implementation in the repo; never reproduce pattern code from memory.

Usage: `/implement-feature <ticket-id | ticket-url>` or `/implement-feature <short description>` (options: `--direct` / `/no-framing` to bypass the framing gate)

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-implementation_plan-<suffix>.md` and `<prefix>-what_am_i_missing-<suffix>.md` (Phase 2), and `<prefix>-walkthrough-<suffix>.md` (Phase 7) in the artifact dir (`artifact-protocol`) (`<suffix>` is `<ticket-id>-<feature-slug>` when there is a ticket, else a 2–4 word topic slug)
- `../_modules/git-worktrees.md`: workspace by default (creates/reuses a workspace worktree per repo in Phase 0 and removes landed ones in Phase 7 per *Workspace Lifecycle*; paste `[worktree-context]` into every delegated skill and sub-agent brief; `/no-wt` opts out)
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`: ticket and PR intake (`<org-url>`, work items, acceptance criteria)
- `../_modules/project-profile.md`: profile `implement-feature-<project>-profile`
- `../_modules/fan-out.md` (Phase 1 research fan-out)
- `../_modules/outward-writes.md`: *Voice pass* on drafted tracker comments

On-demand references (`references/`):
- [`references/framing.md`](references/framing.md) — Phase 0 step 9 request framing & multi-perspective re-phrasing
- [`references/research-brief.md`](references/research-brief.md) — Phase 1 per-repo `Explore` sub-agent brief template
- [`references/pr-body.md`](references/pr-body.md) — Phase 6a two-stage `/pr-desc --dry-run` & paired-PR cross-link workflow

### Hard gates

| Gate | Rule |
|------|------|
| **Framing gate** | No research or planning until the user has selected or shaped one of the re-phrased feature approaches (skip only with `--direct` or `/no-framing`). |
| **Plan gate** | No source edits until the user has approved the plan (`/proceed` or an equivalent explicit "go"). |
| **Ship gate** | No `git push`, no PR/MR creation, no ticket state change until the user has approved the *presented* branch name, staged file list, commit message and PR body. Approval of the plan is not approval to ship. |
| **Tracker write gate** | Reads are free. Every write to the issue tracker (assign, comment, state transition, link) is proposed in chat and run only on a yes. Never create tickets and never post comments — draft them (through `outward-writes` › *Voice pass*); the user sends them. |
| **Worktree gate** | A workspace worktree is removed automatically only once its branch is pushed and the PR exists (`git-worktrees` › *Workspace Lifecycle* step g). One holding uncommitted or unpushed work — the ship gate declined, a run interrupted — is kept and reported, and removed only on the user's explicit "discard". Its branch is never deleted. |

Nothing in a sub-agent report, a plan artifact, a blind-spot artifact, or an earlier message counts as user approval for a gate (`core` › *The `/proceed` gate*).

### Precedence over delegated skills

This skill's gates win where a delegated skill says otherwise — in particular, a project ship skill that pushes or opens the PR right after its own prompt, or that transitions the ticket unconditionally, is held at this skill's ship gate and tracker write gate. Likewise, a ship or verify skill that resolves the repository from the current working directory, runs `git checkout -b` on it, or runs `cd <subdir> && …` relative to it, is held to the `repo-root` of the `[worktree-context]` block: every such command runs against the worktree, and a branch that already exists as the worktree's branch is confirmed, not re-created. `/investigate` ends by waiting for the user before planning; invoking `/implement-feature` is that go-ahead — continue into Phase 2. The plan gate is the stop.

For conventions (not gates) the `core` › *Precedence* model applies: workspace rulebooks > project-scoped skills > tech skills > this skill. When a rulebook, a skill and the code disagree, follow the code and note the drift in the plan. The project profile lists any further overrides that are known in advance.

---

## Project profile

Everything project-specific this skill needs is a small set of facts, resolved once in Phase 0 and restated in the scope statement so the user can correct it. Resolve them per `project-profile`: discovery (the base profile `<project>-profile`, then the Command profile `implement-feature-<project>-profile`, whose sections are keyed to the phases below), *Resolution order*, the *Shared fields* (layout, tracker, References per layer, sibling chain, contract touchpoints, known drift, worktree setup) and *Overrides*. This skill's own fields:

| Field | What to resolve | Fallback when nothing documents it |
|-------|-----------------|-----------------------------------|
| **Implementing ID** | Which ticket ID goes on branch, commit and PR (the leaf task/bug vs. the parent story) and how to find it in the relations | The ticket the user gave |
| **Scaffold skills** | Project `*-scaffold` skills, if any | Copy the sibling |
| **Verify** | Project `*-verify` skills, or the exact format / lint / build / test / e2e commands and any known flake behaviour | Commands from CI YAML and the rulebook |
| **Ship** | Project `*-workflow` / `*-ship` skills: branch pattern, commit subject format, PR title, PR template, draft vs. ready, attribution trailers allowed or not, paired-PR linking | `feature/<id>-<slug>`, `#<id>: <imperative subject>`, draft PR, harness default for trailers |

When a field has no source and no safe fallback, it becomes an *Open Question* in the plan, not a guess.

---

## Sub-agents

The orchestrator (you) owns the ticket, the gates, the plan and every edit. Sub-agents gather evidence (`fan-out`).

| Phase | Fan out when | How |
|-------|--------------|-----|
| 1 — Research | More than one repo changes, or one repo with ≥ 3 layers to trace | One `Explore` agent per repo (optionally one more for the cross-repo contract surface), spawned in one message using [`references/research-brief.md`](references/research-brief.md) |
| 4 — Verify | More than one repo changed | Not agents — start the slowest suite with `run_in_background` and run the other repo's gates meanwhile |
| 2b — Blind-spot pass | Never | Runs in the main context: it audits the plan you just wrote and the evidence behind it, and its finding edits that plan |
| 5 — Self-review | Always | `/code-review` (`deep` for multi-repo or contract changes) and `/spec-verification` own their own fan-out |

**Do not fan out** implementation (Phase 3), the ship gate, or tracker calls. Follow `fan-out` for pre-spawn resolution (implementing ID, pasted ticket text, `[worktree-context]` per repo, sibling feature and chain), read-only brief contract, and re-opening every cited `path:line` on return (unverified claims go under *Open Questions*, not *Proposed Changes*).

---

## Delegation map

| Need | Load |
|------|------|
| Project facts for every phase | the `<project>-profile` and `implement-feature-<project>-profile` skills (`project-profile`), else the sources in its *Resolution order* |
| Isolated worktree per repo: create, `[worktree-context]` block, hydrate, land, remove (Phase 0 and Phase 7) | `git-worktrees` › *Workspace Lifecycle*, invoked, not imitated |
| Deep research before planning | [`/investigate`](../investigate/SKILL.md) |
| Blind-spot pass on the plan (every plan, Phase 2b) | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |
| Plan artifact conventions, status, links | [`/plan`](../plan/SKILL.md) |
| Code patterns per layer | the profile's *References per layer*; else the rulebook plus tech skills (for example `modern-csharp`) |
| Feature-slice generation | the profile's scaffold skills; else copy the sibling |
| Several schema migrations on one branch | `squash-ef-core-migrations` (EF Core) or the ORM's equivalent |
| Quality gates | the profile's verify skills; else the repo's documented commands |
| Self-review against code and spec | [`/code-review`](../code-review/SKILL.md), [`/spec-verification`](../spec-verification/SKILL.md) |
| Git and tracker conventions | the profile's workflow skills; else `CONTRIBUTING.md` and the PR template |
| Branch, commit, push, draft PR | the profile's ship skill (held at the ship gate); else plain `git` + `gh` / `az repos` / `glab` |
| PR body: preview at the ship gate, cross-links after the PRs exist (Phase 6a) | [`/pr-desc`](../pr-desc/SKILL.md), invoked, not imitated |
| Manual test steps | [`/manual-testing`](../manual-testing/SKILL.md) |
| CI red after the PR is open | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |

---

## Phase 0 — Intake

1. **Resolve the project profile** (see above) before touching the ticket. Load the base profile and then `implement-feature-<project>-profile`; the Command profile's *Intake* section may refine the steps below.
2. **Fetch the ticket** (read-only) with relations/links per `pr-host` › *Fetch the PR, its work items and acceptance criteria* (`az boards work-item show --id <ID> --org <org-url> --expand relations`, `gh issue view`, or `glab issue view`). With no tracker, the user's description is the spec; quote it verbatim in the scope statement.
3. **Get the discussion thread.** Planning decisions and reopened-ticket scope often live in comments. If the CLI returns them, read them; if it cannot, try the tracker MCP (Azure DevOps: `wit_work_item` `action: list_comments`); if neither can (the profile says which), ask the user to paste the discussion and state in the scope statement whether you have it. Also note dated "decision" comments in code.
4. **Resolve the implementing ID** per the profile's rule (default: leaf task or bug, never parent story unless it has no suitable child). Do not create tickets.
5. **Resolve scope:** which repos, which feature domains, and whether the acceptance criteria imply UI, API, background, permission, data or contract changes.
6. **Offer tracker housekeeping, do not perform it.** If the ticket is unassigned or not in the "in progress" state the profile names, propose the exact commands and run them only on a yes.
7. **Write a scope statement** in chat: one paragraph naming the implementing ID, the repos touched, the domains, whether the discussion thread was read, the resolved profile fields that matter (tracker, verify, ship conventions) and anything the ticket leaves ambiguous.
8. **Create the workspace worktree(s)** (skip under `/no-wt`) per `git-worktrees` › *Workspace Lifecycle* steps a–c, one per repo in scope (base = freshly fetched `origin/<default>`; branch = project convention with implementing ID; copy *Worktree include list*; run *Dependency hydration*). Append the resulting `[worktree-context]` block(s) to the scope statement.
9. **Request Framing & Multi-Perspective Re-phrasing (Framing Gate)**: read [`references/framing.md`](references/framing.md), present 3–4 contrasting perspectives from its menu, and **stop** until the user picks or blends a framing (skip only with `--direct` or `/no-framing`).

---

## Phase 1 — Research

Research is read-only and reads the **worktree** (`repo-root`). If the domain is unfamiliar, there is more than one viable design, or a contract touchpoint changes, run **`/investigate <suffix>`** and build the plan on its *Plan Seed*. Otherwise do the lightweight pass here — fanned out per repo when *Sub-agents* says so ([`references/research-brief.md`](references/research-brief.md)).

### 1a. Load pattern skills

Load the profile's *References per layer* for the layers in scope (or rulebook sections + tech skills when no profile matches).

### 1b. Read the nearest sibling feature across every layer

Follow the profile's sibling chain for each repo. When two patterns compete, copy the newer one — the profile's *Known drift* names the ones to avoid; otherwise decide by `git log` date and say which you chose in the plan.

### 1c. Cross-cutting and cross-repo checks

Check each row that applies against the profile's *Contract touchpoints*:

| Concern | Typical consequence |
|---------|---------------------|
| New permission / action / role grant | Shared by value with the client — a multi-repo change; menu and route gating on the client side |
| Entity or schema change | Migration step in the plan plus a migration check in Phase 4 (test suites often build the schema without running migrations) |
| API shape change (request, response, enum) | Regenerate or hand-patch the client's API snapshot; producer PR merges first or the consumer branch carries the snapshot |
| Shared enum or vocabulary | Both repos, plus any generated facades that must be committed |
| Fixed names (hub URLs, queue names, event types, routes) | Do not change without coordinating every consumer |
| Background job / event / notification | Job + handler + definition, and the idempotency story |
| Locale / i18n | UI text and validation messages in the product language; URL paths and code in English unless the rulebook says otherwise |

---

## Phase 2 — Implementation Plan

Write `<prefix>-implementation_plan-<suffix>.md` in the artifact dir (`artifact-protocol`) following [`/plan`](../plan/SKILL.md) › *§1 The Plan Contract* (created via *Claim*, using `/plan`'s 7-section skeleton, *Status values*, and *Style*), adding:
- `## User Review Required` (after `## 1. Context & Goal`): breaking changes, migrations, irreversible steps as `> [!WARNING]`.
- `### Cross-repo order` (inside `## 3. Proposed Changes`, when >1 repo): which PR merges first and what the second depends on.
- `## Blind-spot Pass` (after `## 5. Risks`): populated in Phase 2b with the artifact link, the #1 finding in one sentence, and where each finding landed.

The *Task Checklist* inside the plan is the working checklist (`[ ]` → `[/]` → `[x]`); there is no separate task file.

### 2b. Blind-spot pass (every plan)

After drafting the plan and **before presenting it**, run [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) in the main context with the plan as its target and the same `<suffix>` (writing `<prefix>-what_am_i_missing-<suffix>.md`), auditing against [`../what-am-I-missing/references/vectors.md`](../what-am-I-missing/references/vectors.md) (including outliving state, concurrency, library source code under `bin/`/`obj/`/`node_modules/`/`vendor/`, new contract consumers, and profile blind-spot checks).

Fold the findings into the plan before presenting:

| Finding | Goes into |
|---------|-----------|
| #1 finding, verified (`path:line` you re-opened) | A **Proposed Changes** entry that fixes it, a **Task Checklist** item, and a **Verification Plan** test that would fail without the fix |
| #1 finding, needs a product or design decision | **User Review Required** as a `> [!WARNING]`, with your recommended option |
| Secondary finding you accept | Proposed Changes + checklist, one line each |
| Secondary finding you reject or defer | *Blind-spot Pass* section, one line each, with the reason |
| Claim you could not verify | *Open Questions* |

Fill the plan's *Blind-spot Pass* section, re-read the plan once for contradictions, and keep `Status: Awaiting User Review`. **Skip only** for a one-file fix with no persistence, concurrency or contract surface (`Blind-spot pass: skipped — <reason>`).

### 2c. Present

Present the clickable links (`artifact-protocol` › _Chat link block_) to the plan and the blind-spot artifact, the #1 finding in one sentence and what the plan now does about it, plus the open questions and decisions. **Stop here until the user approves.**

---

## Phase 3 — Implement

Order of work when more than one repo changes: **producer (API) → contract sync (regenerate or patch the client snapshot) → consumer (client)**. Keep the plan's checklist ticked as you go. No sub-agents in this phase. Every edit lands under the repo's `repo-root` (`git-worktrees` › *Golden Invariants*).

- Use the profile's scaffold skill for a new slice, or edit the sibling you read in Phase 1 (following *Known drift* where documented).
- Domain failures follow the project's result/exception convention; error messages follow the product locale.
- Schema changes get a reviewed migration; several migrations on one branch are squashed before shipping.
- Every new entry point gets at least the project's minimum tests (typically unauthenticated, forbidden, and one happy path).
- Generated output stays uncommitted unless the project says otherwise; committed generated facades are committed in the same change.
- Permission or action additions are done on both sides in the same unit of work, including client-side menu and route gating.

---

## Phase 4 — Verify

Run the profile's verify skill for each touched repo — or the repo's documented commands — **inside the worktree** (invoke it with `[worktree-context]`; commands run against `repo-root`) and report PASS/FAIL per check. Do not move to Phase 5 on a FAIL.

- **Targeted first, full suite before shipping.**
- **Parallel runs:** if `git -C <repo> worktree list --porcelain` shows another `claude-skill:` worktree of the same repo, run targeted suites only and say so (`git-worktrees` › *Workspace Lifecycle* step e).
- **Flakes:** a failure that moves between runs, or reproduces with the change stashed (`git -C <repo-root> stash -u`, in the worktree only), is re-run alone and recorded; only failures that persist alone are yours.
- **Migration check:** if the test suite builds the schema without running migrations, apply the migration to a real local database with the project's migration command.
- **Client gates** for UI changes: import tidy-up on changed files only, lint at zero warnings, build, and the e2e suite the profile names; revert any stray generated file.
- **Cross-repo contract check** when >1 repo changed: shared values match on both sides, producer contract tests pass, and consumer snapshot contains only the intended contract change.

---

## Phase 5 — Self-review

Invoke every skill below **with the `[worktree-context]` block(s)**:

1. `/spec-verification` against the ticket (and discussion thread if supplied), reading `repo-root`. Every acceptance criterion is *implemented* or explicitly *deferred* in the plan.
2. `/code-review` on the working changes (`deep` when >1 repo or a contract changed). Hand it **every** repo's block in one invocation so `pr-counterpart` › *Counterpart discovery* reviews both halves together.
3. **Blind-spot closure.** Re-open the plan's *Blind-spot Pass* section. For each accepted finding, cite the covering code and test (`path:line`) and confirm the test fails with the fix reverted when cheap to check. A finding with no covering test counts as 🔴. Fix 🔴 findings and re-run affected Phase 4 checks; list unfixed 🟡 findings at the ship gate.
4. **Manual test plan.** Once 🔴 findings are fixed, invoke `/manual-testing` with `[worktree-context]` (skip only for changes with no runtime surface, and note why in the walkthrough).

---

## Phase 6 — Ship

Load the profile's ship and workflow skills (applying *Precedence over delegated skills*) and invoke them with `[worktree-context]`: commit, push and PR creation run from `repo-root` (`git-worktrees` › *Workspace Lifecycle* step f). Stage selectively — never `git add -A`. Follow the profile's conventions (or `CONTRIBUTING.md` / defaults in *Project profile*) for branch name, commit subject, PR title, attribution trailers, and draft PR order (producer PR first).

### 6a. PR body — invoke `/pr-desc --dry-run`

Read [`references/pr-body.md`](references/pr-body.md) and invoke [`/pr-desc --dry-run`](../pr-desc/SKILL.md) before the ship gate (saving to a temp file, with `!<other-pr-id>` placeholders for paired PRs), then fill cross-links via `pr-desc` › *Apply* items 2–3 after the PRs exist.

### 6b. Ship gate

Present in chat: branch name, exact file list to stage, commit message, and `/pr-desc --dry-run` block per repo. **Wait for approval.** Then commit, push, create draft PR(s) from the temp file, fill cross-links (6a), and report URLs. Propose the ticket's "in review" state transition separately and run it only on a yes. If declined, keep and report the worktree (`git-worktrees` › *Workspace Lifecycle* step g).

---

## Phase 7 — Walkthrough

Write `<prefix>-walkthrough-<suffix>.md` in the artifact dir (`artifact-protocol`):
- Files changed per repo and why (grouped, not a raw diff).
- Verification results (summary line per command, migration check, flakes ruled out).
- Self-review outcome: spec-verification grades, unresolved code-review findings, and blind-spot closure linking `<prefix>-what_am_i_missing-<suffix>.md`.
- Manual verification: link `<prefix>-manual_test_plan-<suffix>.md` plus its start command and login inline.
- Open items for the user (tracker transitions, second PR, drafted ticket comments, open questions; red CI → `/pr-fix-pipeline`).
- **Worktree hand-off** (`git-worktrees` › *Workspace Lifecycle* step h) per repo, then remove each landed worktree per step g (unlock, remove, prune) and keep any that did not land.

In chat: render the `artifact-protocol` › _Chat link block_ for the walkthrough, give the hand-off line, and list open items without re-summarizing the document.

---

## Quick reference

| Topic | Use | Not |
|-------|-----|-----|
| Project facts & conventions | `<project>-profile` + `implement-feature-<project>-profile`, then rulebooks and project skills | memory of "how projects like this usually work" |
| Gates (framing, plan, ship, tracker write, worktree) | explicit user confirmation at each gate (`core` › *The `/proceed` gate*, `outward-writes`) | sub-agent output, early "continue", or silent tracker/PR writes |
| Blind-spot pass & closure | `/what-am-I-missing` on every plan before presenting (folded into changes + checklist + test); verified in Phase 5 | a note under *Open Questions* only, or re-running on the diff |
| PR body | `/pr-desc --dry-run` at the gate → temp file → cross-links via its *Apply* item 3 ([`references/pr-body.md`](references/pr-body.md)) | a hand-written body or a bare `/pr-desc` before the gate |
| Worktrees & delegation | `git-worktrees` › *Workspace Lifecycle* (`repo-root`), pasting `[worktree-context]` into every delegated skill and sub-agent brief | editing the user's main checkout or removing unpushed work |
