---
name: implement-feature
description: "Orchestrator for implementing a feature, task or bug end-to-end in any repository or multi-repo workspace — ticket intake, research, plan, blind-spot pass, implementation, verification, self-review, shipping and walkthrough. Owns the phase order, the approval gates (plan, ship, tracker writes) and when to fan out sub-agents; resolves the project's conventions from its rulebooks, project-scoped skills and git remote (a project profile) instead of hard-coding them, and delegates patterns and commands to the investigate / plan / what-am-I-missing / code-review / spec-verification / pr-summary skills and whatever scaffold, verify and ship skills the project provides. Trigger on /implement-feature, \"implement this feature / story / ticket / issue\", \"build #1234 end to end\", or \"take this work item from plan to PR\"."
---

# Skill: `/implement-feature` — End-to-End Feature Implementation

Runs one piece of work from ticket to draft pull request, across one repository or every repository in a workspace.
This skill owns **the order of phases, the gates between them, and where sub-agents are used**. Everything else — code
patterns, test helpers, build and ship commands, tracker specifics — comes from the project itself: its rulebooks, its
project-scoped skills and, where they exist, its *profile skills* (see *Project profile*). Load those and read a sibling
implementation in the repo; never reproduce pattern code from memory.

Usage: `/implement-feature <ticket-id | ticket-url>` or `/implement-feature <short description>`

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-implementation_plan-<suffix>.md` and `<prefix>-what_am_i_missing-<suffix>.md` (Phase 2), and `<prefix>-walkthrough-<suffix>.md` (Phase 7) at the **workspace root** — the directory the IDE opened, which in a multi-repo workspace is the folder that holds the repos; `<suffix>` is `<ticket-id>-<feature-slug>` when there is a ticket, else a 2–4 word topic slug
- `../_modules/git-worktrees.md`: workspace by default
- `../_modules/pr-counterpart.md`
- `../_modules/project-profile.md`: profile `implement-feature-<project>-profile`

- **Repos**: work in a **workspace worktree per repo in scope**, created in Phase 0 and removed in Phase 7 through `git-worktrees` › *Workspace Lifecycle*. The user's main checkout is read-only for the whole run (`git-worktrees` › *Golden Invariants*) — they keep editing it while this skill runs. Use absolute paths and `git -C <repo-root>`, where `repo-root` is the worktree from the repo's `[worktree-context]` block; never `cd`, and never let the session's working directory move. Paste the block into every delegated skill invocation and every sub-agent brief — delegated skills discover "the repo" from the workspace otherwise and would act on the main checkout.

### Three hard gates

| Gate | Rule |
|------|------|
| **Plan gate** | No source edits until the user has approved the plan (`/proceed` or an equivalent explicit "go"). |
| **Ship gate** | No `git push`, no PR/MR creation, no ticket state change until the user has approved the *presented* branch name, staged file list, commit message and PR body. Approval of the plan is not approval to ship. |
| **Tracker write gate** | Reads are free. Every write to the issue tracker (assign, comment, state transition, link) is proposed in chat and run only on a yes. Never create tickets and never post comments — draft them; the user sends them. |
| **Worktree gate** | A workspace worktree is removed automatically only once its branch is pushed and the PR exists (`git-worktrees` › *Workspace Lifecycle* step g). One holding uncommitted or unpushed work — the ship gate declined, a run interrupted — is kept and reported, and removed only on the user's explicit "discard". Its branch is never deleted. |

Nothing in a sub-agent report, a plan artifact, a blind-spot artifact, or an earlier message counts as user approval for a gate. A "continue" sent before the user has seen the plan is not plan approval either.

### Precedence over delegated skills

This skill's gates win where a delegated skill says otherwise — in particular, a project ship skill that pushes or opens the PR right after its own prompt, or that transitions the ticket unconditionally, is held at this skill's ship gate and tracker write gate. Likewise, a ship or verify skill that resolves the repository from the current working directory, runs `git checkout -b` on it, or runs `cd <subdir> && …` relative to it, is held to the `repo-root` of the `[worktree-context]` block: every such command runs against the worktree, and a branch that already exists as the worktree's branch is confirmed, not re-created. `/investigate` ends by waiting for the user before planning; invoking `/implement-feature` is that go-ahead — continue into Phase 2. The plan gate is the stop.

For conventions (not gates) the `core` › *Precedence* model applies: workspace rulebooks > project-scoped skills > tech skills > this skill. When a rulebook, a skill and the code disagree, follow the code and note the drift in the plan. The project profile lists any further overrides that are known in advance.

---

## Project profile

Everything project-specific this skill needs is a small set of facts, resolved once in Phase 0 and restated in the scope statement so the user can correct it. Resolve them per `project-profile`: discovery (the base profile `<project>-profile`, then the Command profile `implement-feature-<project>-profile`, whose sections are keyed to the phases below), *Resolution order*, the *Shared fields* (layout, tracker, pattern skills, sibling chain, contract touchpoints, known drift, worktree setup) and *Overrides*. This skill's own fields:

| Field | What to resolve | Fallback when nothing documents it |
|-------|-----------------|-----------------------------------|
| **Implementing ID** | Which ticket ID goes on branch, commit and PR (the leaf task/bug vs. the parent story) and how to find it in the relations | The ticket the user gave |
| **Scaffold skills** | Project `*-scaffold` skills, if any | Copy the sibling |
| **Verify** | Project `*-verify` skills, or the exact format / lint / build / test / e2e commands and any known flake behaviour | Commands from CI YAML and the rulebook |
| **Ship** | Project `*-workflow` / `*-ship` skills: branch pattern, commit subject format, PR title, PR template, draft vs. ready, attribution trailers allowed or not, paired-PR linking | `feature/<id>-<slug>`, `#<id>: <imperative subject>`, draft PR, harness default for trailers |

When a field has no source and no safe fallback, it becomes an *Open Question* in the plan, not a guess.

---

## Sub-agents

The orchestrator (you) owns the ticket, the gates, the plan and every edit. Sub-agents gather evidence; their output is evidence, not a verdict.

**Fan out only where the work is independent and read-heavy:**

| Phase | Fan out when | How |
|-------|--------------|-----|
| 1 — Research | More than one repo changes, or one repo with ≥ 3 layers to trace | One `Explore` agent per repo (optionally one more for the cross-repo contract surface), spawned in one message |
| 4 — Verify | More than one repo changed | Not agents — start the slowest suite with `run_in_background` and run the other repo's gates meanwhile |
| 2b — Blind-spot pass | Never | Runs in the main context: it audits the plan you just wrote and the evidence behind it, and its finding edits that plan |
| 5 — Self-review | Always | `/code-review` (`deep` for multi-repo or contract changes) and `/spec-verification` own their own fan-out |

**Do not fan out** implementation (Phase 3), the ship gate, or tracker calls. Edits stay in the main context so the plan checklist, the diff and the gates have a single owner.

**Brief rules** (same shape as `code-review` *Deep Mode*):

1. Resolve everything shared **before** spawning — implementing ID, the ticket text (pasted, not a link), the `[worktree-context]` block per repo (so the repo path a sub-agent reads is the worktree, never the main checkout), the sibling feature to read, the sibling chain from the profile. Sub-agents never re-fetch tickets, call the tracker, or create, remove, lock or unlock worktrees.
2. Each prompt states: *read-only — no edits, checkouts, installs, builds, tests or posting; work only under `repo-root`, never touch `main-checkout`*; the exact paths to start from; what to return (`path:line` per claim, reported as `workspace-path` + relative path, ~500 words max).
3. On return, re-open every `path:line` the plan will rely on. A claim you did not re-check goes under *Open Questions*, not *Proposed Changes*.

Research brief template (per repo):

> Read-only. `<pasted [worktree-context] block>` — work only under `repo-root`, never touch `main-checkout`, report paths as `workspace-path` + relative path. Ticket `#<id>`: `<pasted title + acceptance criteria>`. Trace the nearest sibling feature `<name>` through every layer — `<sibling chain for this repo from the profile>`. Report: the files the change will touch with `path:line`, the pattern each one follows (and which of two competing patterns is newer), contract touchpoints (`<profile's contract list>`), and anything in the acceptance criteria the code cannot support yet. Under 500 words.

---

## Delegation map

| Need | Load |
|------|------|
| Project facts for every phase | the `<project>-profile` and `implement-feature-<project>-profile` skills (`project-profile`), else the sources in its *Resolution order* |
| Isolated worktree per repo: create, `[worktree-context]` block, hydrate, land, remove (Phase 0 and Phase 7) | `git-worktrees` › *Workspace Lifecycle*, invoked, not imitated |
| Deep research before planning | [`/investigate`](../investigate/SKILL.md) |
| Blind-spot pass on the plan (every plan, Phase 2b) | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |
| Plan artifact conventions, status, links | [`/plan`](../plan/SKILL.md) |
| Code patterns per layer | the profile's pattern skills; else the rulebook plus tech skills (for example `modern-csharp`) |
| Feature-slice generation | the profile's scaffold skills; else copy the sibling |
| Several schema migrations on one branch | `squash-ef-core-migrations` (EF Core) or the ORM's equivalent |
| Quality gates | the profile's verify skills; else the repo's documented commands |
| Self-review against code and spec | [`/code-review`](../code-review/SKILL.md), [`/spec-verification`](../spec-verification/SKILL.md) |
| Git and tracker conventions | the profile's workflow skills; else `CONTRIBUTING.md` and the PR template |
| Branch, commit, push, draft PR | the profile's ship skill (held at the ship gate); else plain `git` + `gh` / `az repos` / `glab` |
| PR body: preview at the ship gate, cross-links after the PRs exist (Phase 6a) | [`/pr-summary`](../pr-summary/SKILL.md), invoked, not imitated |
| Manual test steps | [`/manual-testing`](../manual-testing/SKILL.md) |
| CI red after the PR is open | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |

---

## Phase 0 — Intake

1. **Resolve the project profile** (see above) before touching the ticket. If profile skills exist, load the base profile and then this Command's profile now; the Command profile's *Intake* section may refine the steps below.

2. **Fetch the ticket** (read-only). Pick the CLI the tracker provides and ask for relations/links so the parent and child items come along:

   ```bash
   # Azure DevOps Boards (use the dev.azure.com/<org> form; legacy *.visualstudio.com hosts can fail auth)
   az boards work-item show --id <ID> --org https://dev.azure.com/<org> --expand relations --output json
   # GitHub Issues
   gh issue view <N> --json number,title,body,labels,assignees,milestone,comments
   # GitLab
   glab issue view <N> --output json
   ```

   With no tracker, the user's description is the spec; write it down verbatim in the scope statement so it can be corrected.

3. **Get the discussion thread.** Planning decisions — and the real remaining work on a ticket reopened after testing — often live only in comments. If the CLI returns them, read them; if it cannot (the profile says which), ask the user to paste the discussion (a screenshot is fine) and say in the scope statement whether you have it. Also note any dated "decision" comments in the code; they can disagree with the thread.

4. **Resolve the implementing ID** per the profile's rule. Default: the leaf task or bug, never the parent story; for a story with no suitable child, the story's own ID. Do not create tickets.

5. **Resolve scope.** Which repos, which feature domains, and whether the acceptance criteria imply UI, API, background, permission, data or contract changes.

6. **Offer tracker housekeeping, do not perform it.** If the ticket is unassigned or not in the "in progress" state the profile names, say so and propose the exact commands. Run them only on a yes.

7. **Write a scope statement** in chat: one paragraph naming the implementing ID, the repos touched, the domains, whether the discussion thread was read, the resolved profile fields that matter (tracker, verify, ship conventions) and anything the ticket leaves ambiguous.

8. **Create the workspace worktree(s)** per `git-worktrees` › *Workspace Lifecycle* steps a–c, one per repo in scope: base = the freshly fetched `origin/<default>` unless the ticket names another base; branch = the project's convention with the implementing ID; copy the profile's *Worktree include list*; run its *Dependency hydration*. If the branch is already checked out in the user's main checkout, *Workspace Lifecycle* step a says stop and ask — do that before Phase 1. Append the resulting `[worktree-context]` block(s) to the scope statement; every later phase, delegated skill and sub-agent brief uses them. A worktree created here and never approved past the plan gate is clean and is removed per *Workspace Lifecycle* step g when the run ends.

---

## Phase 1 — Research

Research is read-only and reads the **worktree** (`repo-root`), whose base is the latest default branch — not the main checkout, which may be on an unrelated branch with the user's own edits. If the domain is unfamiliar, there is more than one viable design, or a contract touchpoint changes, run **`/investigate <suffix>`** and build the plan on its *Plan Seed*. Otherwise do the lightweight pass here — fanned out per repo when *Sub-agents* says so.

### 1a. Load pattern skills

Load the profile's pattern skills for the layers in scope. Without a profile, load the rulebook sections for those layers and any tech skill that applies to the language.

### 1b. Read the nearest sibling feature across every layer

Follow the profile's sibling chain for each repo (for a typical API repo: endpoint → domain/service → entity + persistence mapping → tests; for a typical client: route → feature component → data layer → schema → test IDs). When two patterns compete, copy the newer one — the profile's *Known drift* names the ones to avoid; otherwise decide by `git log` date and say which you chose in the plan.

### 1c. Cross-cutting and cross-repo checks

Check each row that applies; the profile's *Contract touchpoints* make this concrete for the project.

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

Write `<prefix>-implementation_plan-<suffix>.md` at the workspace root following `/plan`. Required sections:

```markdown
# <Feature name> (#<id>)

## Context & Goal                  <!-- include the resolved project profile fields the plan relies on -->
## User Review Required            <!-- breaking changes, migrations, irreversible steps, as > [!WARNING] -->
## Open Questions                  <!-- incl. unverified sub-agent claims, unresolved profile fields, anything awaiting the discussion thread -->
## Blind-spot Pass                 <!-- added in Phase 2b: link, the #1 finding in one sentence, where each finding landed -->
## Proposed Changes
### <Repo> — [NEW|MODIFY|DELETE] <path> — what and why
### Cross-repo order               <!-- which PR first, what the second one depends on; omit for a single repo -->
## Task Checklist                  <!-- the live checklist; tick items here during Phase 3 -->
## Verification Plan               <!-- exact commands, migration check, manual steps, e2e specs to run -->

**Status:** Awaiting User Review
```

The *Task Checklist* inside the plan is the working checklist — there is no separate task file. Mark items `[/]` when started and `[x]` when done. Status values are `/plan`'s: `Draft` → `Awaiting User Review` → `Approved` → `Completed`.

### 2b. Blind-spot pass (every plan)

After drafting the plan and **before presenting it**, run [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) with the plan as its target. Use the same `<suffix>`, so it writes `<prefix>-what_am_i_missing-<suffix>.md` next to the plan. Run it yourself, in the main context: it audits your plan, and its finding edits that plan.

Point the pass where plans built from a sibling feature fail most often:

- **State that outlives the request:** persisted or restored data, resumed runs, retries, background jobs, and data created before this change (backfills, old rows, cached clients).
- **Concurrency:** two users, two tabs, two jobs, or two of the plan's own new features touching the same entity.
- **The library's real behaviour, not its docs:** when the plan leans on a framework feature (ORM behaviour, a job scheduler, a realtime hub, a client cache, a third-party SDK), read the installed source under `bin/`, `obj/`, `node_modules/`, `vendor/` or the package cache for the path the plan depends on.
- **Contract consumers the sibling never had:** a new enum member, permission, DTO field or event that other code switches on.
- **Whatever the profile lists** under its own blind-spot vectors.

Fold the findings into the plan. A finding is not done when it sits in *Open Questions*.

| Finding | Goes into |
|---------|-----------|
| #1 finding, verified (`path:line` you re-opened) | A **Proposed Changes** entry that fixes it, a **Task Checklist** item, and a **Verification Plan** test that would fail without the fix |
| #1 finding, needs a product or design decision | **User Review Required** as a `> [!WARNING]`, with your recommended option |
| Secondary finding you accept | Proposed Changes + checklist, one line each |
| Secondary finding you reject or defer | *Blind-spot Pass* section, one line each, with the reason |
| Claim you could not verify | *Open Questions* |

Then fill the plan's *Blind-spot Pass* section: the artifact link, the #1 finding in one sentence, and where each finding landed. Re-read the plan once for anything the finding contradicts (an earlier step, a test that assumed the happy path, an over-confident *User Review Required* line) and fix it.

If the finding changes the design, for example a new component, a different storage choice, or a new gate, say so explicitly when presenting. The plan stays `Awaiting User Review`. The user approves the folded plan, not the pre-pass draft.

**Skip only** for a one-file fix with no persistence, concurrency or contract surface, for example a text or style change. Note `Blind-spot pass: skipped — <reason>` in the plan.

### 2c. Present

Present the clickable links to the plan and the blind-spot artifact, the #1 finding in one sentence and what the plan now does about it, plus the open questions and decisions. **Stop here until the user approves.**

---

## Phase 3 — Implement

Order of work when more than one repo changes: **producer (API) → contract sync (regenerate or patch the client snapshot) → consumer (client)**. Keep the plan's checklist ticked as you go. No sub-agents in this phase. Every edit lands under the repo's `repo-root`; a file path that does not start with a worktree path is a defect (`git-worktrees` › *Golden Invariants*).

- Use the profile's scaffold skill for a new slice, or edit the sibling you read in Phase 1. Where the profile's *Known drift* says a scaffold template or doc is stale, follow the code it points to instead.
- Domain failures follow the project's result/exception convention; error messages follow the product locale.
- Schema changes get a reviewed migration; several migrations on one branch are squashed before shipping.
- Every new entry point gets at least the project's minimum tests (typically unauthenticated, forbidden, and one happy path).
- Generated output stays uncommitted unless the project says otherwise; committed generated facades (the profile names them) are committed in the same change.
- Permission or action additions are done on both sides in the same unit of work, including client-side menu and route gating.

---

## Phase 4 — Verify

Run the profile's verify skill for each touched repo — or the repo's documented commands — **inside the worktree** (invoke it with the `[worktree-context]` block; its commands run against `repo-root`) and report PASS/FAIL per check. When more than one repo changed, start the slowest suite with `run_in_background` and do the other gates meanwhile. Do not move to Phase 5 on a FAIL.

- **Targeted first, full suite before shipping.** Use the test runner's filter syntax the profile or the test project documents.
- **Parallel runs.** If `git -C <repo> worktree list --porcelain` shows another `claude-skill:` worktree of the same repo, run targeted suites only and say so (`git-worktrees` › *Workspace Lifecycle* step e): the profile's *Shared local services* (dev-server and API ports, the local database) are shared between worktrees, so concurrent full suites collide and flake.
- **Flakes.** A failure that moves between runs, or reproduces with the change stashed (`git -C <repo-root> stash -u`, in the worktree only), is not yours — re-run the failing group alone and record the outcome; only failures that persist alone are yours. The profile may list known-flaky groups.
- **Migration check** when the plan adds one: if the test suite builds the schema without running migrations (common with `EnsureCreated`-style setups), apply the migration to a real local database with the project's migration command and confirm it runs clean.
- **Client gates** for UI changes: import tidy-up on changed files only, lint at zero warnings, build, and the e2e suite the profile names. Check `git status` afterwards and revert any stray generated file.
- **Cross-repo contract check** when more than one repo changed: shared values match on both sides, the producer's contract tests pass, and the consumer's snapshot contains exactly the intended contract change.

---

## Phase 5 — Self-review

Before presenting the ship gate:

Invoke both skills **with the `[worktree-context]` block(s)**; without it they resolve the repo from the workspace and would grade or snapshot the user's main checkout — an empty scope at best, the user's unrelated edits at worst.

1. `/spec-verification` against the ticket (include the discussion thread if the user supplied it), reading `repo-root`. Every acceptance criterion is *implemented* or explicitly *deferred* in the plan.
2. `/code-review` on the working changes — `deep` when more than one repo or a contract changed. With the block, its `working` scope snapshots the worktree's tree (`git -C <repo-root> stash create`) and its Review Context names the worktree branch as the reviewed head. Hand it **every** repo's block in one invocation, so its counterpart lookup (`pr-counterpart` › *Counterpart discovery*) resolves to the sibling worktree and reviews both halves together. Separate per-repo runs would each miss the cross-repo contract checks.
3. **Blind-spot closure.** Re-open the plan's *Blind-spot Pass* section. For each finding the plan accepted, point to the code and the test that cover it (`path:line`), and confirm the test fails with the fix reverted when that is cheap to check. A finding with no covering test counts as 🔴. Do not re-run `/what-am-I-missing` on the diff; reviewing a diff is `/code-review`'s job. Re-run it only if implementation forced a design change the user has not seen, and present that change before shipping.

Fix 🔴 findings and re-run the affected Phase 4 checks. List 🟡 findings you chose not to fix at the ship gate, one line each.

---

## Phase 6 — Ship

Load the profile's ship and workflow skills, applying *Precedence* above, and invoke them with the `[worktree-context]` block: commit, push and PR creation all run from `repo-root` (`git-worktrees` › *Workspace Lifecycle* step f); the branch already exists as the worktree's branch, so the ship skill confirms it rather than running `checkout -b`. Stage selectively — never `git add -A`; skip a ship skill's re-run of format/build/test if Phase 4 passed on the same tree.

Conventions come from the profile, else from `CONTRIBUTING.md`, else these defaults:

- Branch: `feature/<id>-<english-kebab-slug>` (`bugfix/`, `hotfix/` by ticket type).
- Commit subject and PR title: `#<id>: <short English imperative description>`, single line.
- Attribution trailers (`Co-Authored-By`, "Generated with …"): exactly what the profile or rulebook says; a project that forbids them overrides the harness default, a project that says nothing keeps it.
- Draft PR unless the profile says otherwise. For a paired change, open the producer PR first.

### 6a. PR body — invoke `/pr-summary`

Every PR body comes from invoking [`pr-summary`](../pr-summary/SKILL.md) with the Skill tool, once per repo, **with the repo's `[worktree-context]` block** so its Step 0 and its diff run against `repo-root` and never against the main checkout. Never hand-write a body "in its style". The skill owns:

- the repo's PR template and its classification vocabulary;
- the Key-impacts grouping;
- the `---` footer, with `Resolved:` first and `This PR relates to:` last;
- the 4000-character budget;
- the temp file and the cross-link fill-in.

Run it at two points:

| When | How | Why |
|------|-----|-----|
| At the ship gate, before anything is committed | **Preview mode** (`/pr-summary <base>`), never `update` | `update` commits and pushes in its Step 0, which would get past the ship gate. Preview composes from the working-tree diff. Keep its block verbatim, with `!<other-pr-id>` placeholders for a paired change, and save it to a temp file. |
| After every paired PR exists | Replace the placeholder in the approved temp file with the other repo's real PR id. Apply it with `pr-summary` §5.2–5.3: show the current description, update from the file, then read it back to verify. | This keeps the text the user approved. Use `/pr-summary update` only if the diff changed after the gate, and present the new body before writing it. |

Create each PR from the preview's temp file, passed by path: `gh pr create --body-file`, `az repos pr create --description "$(cat …)"`, or `glab mr create --description-file`. Verification results, merge instructions and coordination prose go in the gate message and the walkthrough, never in the body.

### 6b. Ship gate

Present in chat:

- the branch name;
- the exact file list to stage;
- the commit message;
- the `/pr-summary` preview block for each repo.

Wait for approval. Then commit, push, create the draft PR(s), fill the cross-links (6a), and report the URLs. Propose the ticket's "in review" state transition separately and run it only on a yes.

If the user declines the gate, the worktree is **kept** (worktree gate): report its path, branch and what is uncommitted or unpushed, per `git-worktrees` › *Workspace Lifecycle* step g.

---

## Phase 7 — Walkthrough

Write `<prefix>-walkthrough-<suffix>.md` at the workspace root:

- Files changed per repo and why (grouped, not a raw diff).
- Verification results — the summary line of each command, the migration check, any flakes ruled out and how.
- Self-review outcome: spec-verification grades, unresolved code-review findings, and the blind-spot closure (each finding → the code and test that cover it, or why it was deferred), linking `<prefix>-what_am_i_missing-<suffix>.md`.
- Manual verification: a link to the `<prefix>-manual_test_plan-<suffix>.md` that `/manual-testing` wrote, plus its start command and recommended login inline.
- Open items for the user: tracker transitions not yet run, the second PR, drafted ticket comments, questions the plan left open. If CI goes red later → `/pr-fix-pipeline`.
- **Worktree hand-off** (`git-worktrees` › *Workspace Lifecycle* step h), per repo: which branch holds the work; that the user's checkout is unchanged and on which branch; whether the worktree was removed (branch pushed, PR open → step g landed procedure ran) or kept and why; how to see the work (`git -C <repo> checkout <branch>` after stashing their own changes, or open the kept worktree directly). Manual testing runs from the kept worktree or after that checkout — nothing of the feature is in the main checkout.

Then remove each landed worktree per *Workspace Lifecycle* step g (unlock, remove, prune) and confirm `git -C <repo> worktree list` shows only the main checkout; keep any that did not land.

In chat: link the walkthrough, give the hand-off line and list the open items. Do not re-summarize the document.

---

## Quick reference

| Topic | Use | Not |
|-------|-----|-----|
| Project facts | the `<project>-profile` and `implement-feature-<project>-profile` skills, then rulebooks, project skills, the repo | memory of "how projects like this usually work" |
| Ticket for branch/commit/PR | the implementing leaf task or bug; the story only when it has no suitable child | creating a task |
| Ticket discussion | read via CLI when it can; otherwise ask the user to paste it | assuming the description is the whole spec |
| Tracker writes | proposed in chat, run on a yes | silent assign / comment / transition |
| Sibling pattern | the newer of two competing patterns, named in the plan | whichever file was opened first |
| Contract changes | producer → snapshot/regenerate → consumer, producer PR first | editing generated client code by hand |
| Migration verified by | applying it to a real local database | the test suite when it builds the schema itself |
| Flaky failure | re-run alone; reproduce with the change stashed | re-running the whole suite until green |
| PR body | `/pr-summary` preview at the gate → temp file → cross-links via its §5.3 | a hand-written body, an inline description, `update` mode before the gate |
| Task checklist | `## Task Checklist` in the plan artifact | a separate `task.md` |
| Blind-spot pass | `/what-am-I-missing` on every plan before presenting; the #1 finding becomes a change, a checklist item and a test | a note under *Open Questions* only |
| Blind-spot closure | Phase 5: each accepted finding → covering code + test `path:line` | re-running `/what-am-I-missing` on the diff |
| Gates | plan, ship, tracker write, worktree — each needs the user's explicit yes | sub-agent output or an early "continue" |
| Where edits happen | the repo's workspace worktree (`repo-root`), created in Phase 0 via `git-worktrees` | the user's main checkout, `cd`, `EnterWorktree` |
| Telling delegated skills where the repo is | paste the `[worktree-context]` block into every invocation and brief | letting them discover the repo from cwd or the workspace |
| Worktree removal | after push + PR, without `--force`; otherwise keep and report | removing unpushed work, deleting the branch |
