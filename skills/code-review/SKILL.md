---
name: code-review
description: "Reviews code changes along Correctness (bugs, performance), Standards (project conventions, cross-repo contracts), and Spec (PR, ticket, acceptance criteria) axes, plus Security, Tests and Drift when the diff calls for them (it recommends the axis set per review), then a blind-spot pass on the change as a whole. Writes a verified code review artifact. Handles PR URLs, work item IDs, branch comparisons, and dual-repo counterpart PRs. Reads detached git snapshots by default."
argument-hint: "[--deep] [--axes <list>] [live] [feedback] [scope]"
---

# Code Review Skill

Use this skill whenever the user requests a code review, feedback on a pull request, a review of a branch or working changes, or a "review since X".

---

## Invariants

1. **Artifact:** every `/code-review` writes `<prefix>-code_review-<suffix>.md` in the artifact dir (`artifact-protocol`) and opens its chat response with the `artifact-protocol` › *Chat link block* (plus a link to any active `<prefix>-implementation_plan-<suffix>.md`).
2. **Read-only:** never edit code, stage commits, run migrations, or touch the main checkout (`core` › *The `/proceed` gate*, `git-worktrees` › *Snapshot Lifecycle*).
3. **Verified findings only:** every 🔴/🟡 passes Step 6 (*Verify*) before it is written.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-code_review-<suffix>.md`
- `../_modules/git-worktrees.md`: snapshot by default
- `../_modules/pr-counterpart.md`
- `../_modules/project-profile.md`: profile `code-review-<project>-profile`
- `../_modules/pr-host.md`
- `../_modules/fan-out.md`

- With a workspace `[worktree-context]` block (e.g. `/implement-feature`), *Review Context* reports the worktree's branch as the reviewed head and the user's main-checkout branch separately as "not reviewed".

---

## Modes

| Invocation | Mode | How the axes run |
| --- | --- | --- |
| `/code-review [scope]` | **Standard** (default) | One pass; the reviewer covers the selected axes (*Step 5a*) itself, or as parallel axis lanes on larger diffs (*Step 5b*) |
| `/code-review --deep [scope]` | **Deep** | Each selected axis runs in a parallel sub-agent ([deep-mode.md](references/deep-mode.md)), then aggregate and pass to an independent verifier sub-agent |
| `/code-review live [scope]` | Standard or deep, **no snapshot** | Reads the main checkout directly (same as `/no-worktrees`). Only when a snapshot is impossible (e.g. uncommitted untracked files) |
| `/code-review feedback [scope]` | Standard or deep, **full thread triage** | After Step 6 verifies findings, runs `/pr-feedback-review` and folds PR threads into the review (*Step 6b*) |

`live` and `feedback` are modifiers (`/code-review --deep feedback <pr>` is valid). Suggest `--deep` (`fan-out` › *Bare vs deep*) when the diff exceeds ~1,500 changed lines or spans two repos with contract changes.

### When _not_ to use — pick the right neighbor

| Situation | Use instead |
| --- | --- |
| Auditing an implementation plan, not code | [`/plan --review`](../plan/SKILL.md) |
| Reviewer comments, threads and votes on the PR | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md), or `/code-review feedback` |
| The PR's pipeline is red | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |
| How to try the change by hand | [`/manual-testing`](../manual-testing/SKILL.md) |
| Quality-only cleanup you intend to apply yourself | [`/refine`](../refine/SKILL.md) or [`/clean`](../clean/SKILL.md) |

---

## Project profile

Resolve `<project>-profile` and `code-review-<project>-profile` before Step 1 per `project-profile` (*Resolution order*, *Shared fields*, *Overrides*, *Upstream content*, *Pointers*). Command-specific fields:

| Field | What to resolve | Fallback when nothing documents it |
| --- | --- | --- |
| **Counterpart pathspecs** | Per repo, paths to diff on the other side of a dual-repo change | Whole counterpart diff |
| **Review base exceptions** | Release or hotfix bases a branch may target instead of the default | `pr-host` › *Branch names & Diff base* |
| **Sibling hints** | Where the nearest existing feature usually lives, by kind of change | Recent feature commit (`git log --stat`) |
| **Review checklists** | Per repo: upstream skill path, exact headings that apply, which axis each feeds, and exclusions | None: Step 3 sources only |
| **Lessons catalogs** | Per repo: upstream path of past review lessons and sections recording team decisions | None |
| **Axis and severity mapping** | How the project's finding tags/severities map onto the *Step 5* axes and 🔴/🟡/🟢 | Not needed |
| **Report additions** | Subsections added inside *Detailed Review Findings* | None |
| **Hand-offs** | Checks delegated to other skills (verify skills, manual testing) | None |

Record loaded profiles and the `origin/<default> @ <short-sha>` of every upstream checklist/catalog in *Review Context* › **Profile**.

---

## Step 1 — Determine Scope & Snapshot

Resolve the scope and materialise the pinned head in a detached snapshot worktree:

| User says | What to diff |
| --- | --- |
| `staged` / `commit` | `git diff HEAD <snap>^2` (`<snap>` from `git stash create`) |
| `unstaged` / `working` | `git diff HEAD <snap>` |
| `branch` / `pr` / (default) | All commits on the branch vs. its base (`pr-host` › *Branch names & Diff base*) |
| `since <ref>` / SHA, tag, `HEAD~5` | `git diff <ref>...HEAD` |
| Specific file(s) | Read those files from the snapshot (or `live` when never committed) |
| `frontend` / `backend` | Branch diff scoped to that directory |
| PR URL or bare PR ID | Resolve via `pr-host`, then run `pr-counterpart` › *Counterpart discovery* |
| Work item / issue ID (`#30342`) | Read the work item via `pr-host`, then find its PR or branch |

Confirm `<base>` resolves and the diff is non-empty before proceeding. Follow [Snapshot & Scope Mechanics](references/snapshot-and-scope.md) for snapshot head selection, PR/counterpart handling, and cross-repo contract reads.

---

## Step 2 — Identify the Spec Source

Check in order:
1. PR description and linked work item(s) / parent story / acceptance criteria from Step 1 — per repo.
2. User-supplied path or pasted spec text.
3. Matching spec/plan file (`docs/`, `specs/`, `<prefix>-implementation_plan-<suffix>.md`).
4. Work-item IDs in commit subjects (`#30342: ...`), fetched via `pr-host`.

If none exist, record `"Spec: none available — Spec axis limited to unannounced behaviour"` in *Review Context* and continue.

---

## Step 3 — Identify the Standards Sources

Load documented repo standards in `core` › *Precedence* order:
0. **Profile review checklists and lessons catalogs**: read from `origin/<default>` per `project-profile` › *Upstream content*.
1. **Workspace and repo rulebooks** (`CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, `CONTRIBUTING.md`).
2. **Project-scoped Reference skills** matching the touched layers (*References per layer*).
3. **Cross-repo contracts** (*Contract touchpoints*): shared enums, API snapshots/generated clients, realtime hubs, UI locale rules.
4. **General Reference skills** for languages in the diff (e.g. `modern-csharp`).
5. **Smell baseline**: read [smell-baseline.md](references/smell-baseline.md) for the 12 Fowler code smells (always subordinate to repo rules and rated 🟢 unless a concrete defect or maintenance cost is named).

---

## Step 4 — Gather Context

1. Run `git -C "$SNAP_DIR" diff --name-status <base>...HEAD` to record the file inventory and blast radius.
2. For diffs > ~200 lines, read changed files in full from the snapshot rather than relying on diff hunks alone.
3. For every deleted or moved symbol/file, search the snapshot to confirm zero dangling references.
4. **Never** run package installs, builds, linters, or test suites during a review unless explicitly asked.
5. Skip generated files (`*.gen.ts`, `*.g.cs`, migration designers, lockfiles), but verify that checked-in generated artifacts/snapshots that *should* have updated alongside source changes did.

---

## Step 5 — Pick the Axes, Then Review

### Step 5a — Recommend the axes

From the Step 4 inventory, recommend the axis set and print it in chat before reviewing: one row per axis with on/off and the diff evidence that decided it. Continue with it; `--axes <list>` (e.g. `--axes correctness,security,tests`) replaces the recommendation. Record the final set, and each skipped axis with its reason, in *Review Context* › **Axes**.

| Axis | On when |
| --- | --- |
| **Correctness** | Always |
| **Standards** | Always |
| **Spec** | Always; limited to unannounced behaviour without a Spec source (Step 2) |
| **Security** | The diff touches authentication, authorization policies or roles, access or ownership checks, protected or personal data, query filters, endpoints or routes taking input, raw SQL, HTML rendering, secrets or config |
| **Tests** | The diff changes production behaviour, or adds, removes or changes tests |
| **Drift** | The diff touches docs, skills, rulebooks, code comments or checked-in generated artifacts, or renames, moves or deletes something they reference |

### Step 5b — Review along the selected axes

Tag every finding with one selected axis and rank severity within each axis on its own merits:

- **Correctness**: logical bugs, off-by-one/boundary errors, race conditions, null/undefined dereferences, unhandled exceptions, N+1 queries, missing `async`/`await`, memory/resource leaks, re-render/memoisation bugs.
- **Standards**: documented convention breaches (cite file + rule), cross-repo contract mismatches (🔴 when runtime breaks, 🟡 otherwise), DRY/separation-of-concerns issues, readability, and [smell-baseline.md](references/smell-baseline.md) judgement calls.
- **Spec**: quoting the spec/AC line — **Missing or partial**, **Wrong**, **Scope creep / unannounced**, or **Stale description**.
- **Security**: authentication and authorization gaps, missing access or ownership checks, protected data reaching a caller who may not see it, bypassed query filters, injection (SQL, XSS, command), secrets in code or logs, unvalidated input.
- **Tests**: behaviour the diff adds or changes with no test exercising it, coverage the repo's testing rules require, failing branches, guards or rollback paths no test reaches, assertions too weak to catch the defect the test is named for, deleted tests without a replacement.
- **Drift**: docs, skills, rulebooks, code comments and checked-in generated artifacts (API snapshots, generated clients, route trees) that no longer match the code at head. The PR description stays on Spec.

An issue whose axis is off goes to its fallback: Security → Correctness; Tests → Standards (missing coverage) or Correctness (untested failing path); Drift → Standards.

**Axis lanes (Standard mode).** When the Step 4 inventory shows more than ~100 changed lines, review the selected axes as parallel lanes per `fan-out` › *Speed fan-out*, one lane per axis and at most 4: with more than 4 axes on, Security rides with Correctness and Tests and Drift ride with Standards. Each lane gets the snapshot `[worktree-context]`, the diff base, the Step 4 inventory, the Spec source (Step 2), the Standards sources (Step 3), its axis definitions above verbatim and the severity scale, and returns findings tagged with axis and severity at `path:line`. The lead merges them and runs Step 6 on every 🔴/🟡 as usual. Review inline at or below ~100 lines, or when `/code-review` itself runs inside a sub-agent. This is not `--deep`: there is no verifier sub-agent and no `deep-mode.md`.

### Severity
- **🔴 Critical / Defect**: blocking bugs, security vulnerabilities, broken runtime contracts, or wrong behavior.
- **🟡 Important / Design**: concrete architectural concerns, documented-convention breaches, DRY violations with real cost, meaningful performance issues, missing/wrong spec items. Pure style (import aliases, missing modifier, orphan doc comment) is 🟢.
- **🟢 Minor / Polish**: readability, naming, minor style, smell-baseline judgement calls.
- **💙 Praise**: clean design or thorough edge-case handling worth calling out.

---

## Step 6 — Verify Every 🔴 and 🟡

Before writing the artifact (in `deep` mode, after aggregation and the independent verifier, `deep-mode.md` steps 3–5):
1. **Re-open the cited `path:line`** in the snapshot and verify the code matches the claim.
2. **Try to refute it**: check callers, guards, validators, query filters, config, and any team decision in the profile's lessons catalog.
3. **Classify**: **Verified** (failing path traced in code), **Plausible** (needs runtime/test confirmation — state the exact command), or **Refuted** (drop, or downgrade to 🟢 if a near-miss).

### Step 6b — Fold In PR Feedback (`feedback` only)

After Step 6, when a PR is in scope:
1. Invoke [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) with the same `--deep`/`live` modifiers and pass this run's `[worktree-context]` block per repo.
2. Match each human thread to findings by root cause:
   - **Covers finding N** (thread ⏸/◐) → attach dual thread link (`pr-host` › *Fetch discussion threads*) to finding N's *Where* line; if a team decision is recorded in the thread, quote it and lower to 🟢 unless the code contradicts the decision.
   - **Thread says ✅ Fixed, but Step 6 verified the defect at head** → keep finding N and note the thread's "fixed" state is stale.
   - **Raises a defect the review missed** → run Step 6 on it; add with tag `· raised in thread #id` if verified, else mark refuted in the cross-check table.
   - **Not a code defect** → list only in `### PR Feedback Cross-Check`.

### Step 6c — Blind-Spot Pass

On every review, after Step 6 (and 6b):
1. Run [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) in chat mode against the spec + diff, passing the snapshot `[worktree-context]` and the already-verified findings.
   - **Parallel with Step 6** (when Step 5b ran as axis lanes): start it as one background `general-purpose` sub-agent on Sonnet as soon as the lanes return, passing the merged candidate findings instead of verified ones, and run Step 6 (and 6b) in the lead meanwhile. The sub-agent runs `/what-am-I-missing` inline (`fan-out` › *Speed fan-out* › *Nested calls stay inline*) and returns its blind spots only; the lead keeps the snapshot until it returns.
2. Verify its top blind spots via Step 6; add any surviving finding on its owning axis tagged `· blind-spot pass`, and record the outcome in *Review Context* › **Mode & Blind-spot pass**.

---

## Step 7 — Artifact & Output Format

1. Publish `<prefix>-code_review-<suffix>.md` in the artifact dir (`artifact-protocol`) via `artifact-protocol` › *Claim* (respecting the *Independence rule*), following [Review Artifact Template & Structure](references/review-artifact-template.md). Remove the snapshot(s) after writing.
2. In chat, emit the `artifact-protocol` › *Chat link block* for the review artifact (plus any active implementation plan), followed by:
   - Worst finding **per reviewed axis** (one line each, or `clean`),
   - Any Spec source that could not be resolved,
   - Blind-spot pass outcome (one line),
   - With `feedback`: link to the `pr_feedback_review` artifact + one-line thread disposition summary,
   - Closing gate line (`core` › *The `/proceed` gate*).

---

## Deep Mode

For `/code-review --deep`, read [deep-mode.md](references/deep-mode.md) before spawning sub-agents.

---

## Heuristics & Common Pitfalls

- **Schema, type, context, or hook changes**: grep all consumers in the snapshot to verify downstream contracts.
- **Prop mutation**: flag direct mutation of props as 🟡.
- **Cross-repo contracts**: verify shared enum values, OpenAPI snapshots + generated clients, realtime hub URLs, and UI language on both sides (*Step 1* › [snapshot-and-scope.md](references/snapshot-and-scope.md)).
- **Comments narrating history or sibling justification**: flag PR/ticket backstory ("fixed CI crash", "mirrors X") as 🟢; flag **stale/inaccurate comments** left behind after a code change as 🟡.
- **Mandatory "why this isn't a preference" beat**: every 🟡 in *In Plain Terms* must name the concrete contradiction or broken invariant, ideally citing an existing path in the same repo that already does it right.
