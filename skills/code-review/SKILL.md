---
name: code-review
description: Reviews code changes along Correctness (bugs, security, performance), Standards (project conventions, cross-repo contracts), and Spec (PR, ticket, acceptance criteria) axes. Writes a verified code review artifact. Handles PR URLs, work item IDs, branch comparisons, and dual-repo counterpart PRs. Reads detached git snapshots by default.
---

# Code Review Skill

Use this skill whenever the user requests a code review, feedback on a pull request, a review of a branch or working changes, or a "review since X".

---

## ⛔ Mandatory Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR DEVIATION:**
>
> 1. **MANDATORY .MD ARTIFACT & SUMMARY (NO EXCUSES):** Every single `/code-review` response MUST ALWAYS write or update the complete review report as `<prefix>-code_review-<suffix>.md` **at the workspace root**, and begin the response with a clickable link to it plus clickable section anchors, built exactly as *Artifact Links* below specifies. If an active `<prefix>-implementation_plan-<suffix>.md` exists, link that too. The user frequently needs to click and open it in the IDE.
> 2. **DO NOT MODIFY CODE OR THE MAIN WORKING TREE:** Never edit code files, stage commits, run migrations, check out branches, `git stash push`/`pop`, or execute any command that changes the main checkout during or immediately after a `/code-review`. The **only** git writes allowed are the ones `git-worktrees` snapshot mode performs (*Step 1b*): `git fetch`, `git stash create` (writes one unreferenced commit object, nothing else) and `git worktree add --detach` / `remove` / `prune` on a snapshot directory **outside** the repo. If the tree is not the one to review, snapshot the right ref instead of checking it out (see *Get the right code into the snapshot*). Other repos in the workspace are never switched either: their side of a contract is read from git objects at `origin/<default>` (*Counterpart PRs* › *None*).
> 3. **DO NOT AUTO-PROCEED:** Never begin implementing fixes or refactorings automatically. Wait for explicit user instruction or `/proceed`.
> 4. **NO UNVERIFIED FINDINGS:** Every 🔴/🟡 must survive Step 6 (*Verify*) before it is written.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-code_review-<suffix>.md` (suffix e.g. `-18176-contract-templates`, `-category-demand-statistics`)
- `../_modules/git-worktrees.md`: snapshot by default
- `../_modules/pr-counterpart.md`
- `../_modules/project-profile.md`: profile `code-review-<project>-profile`
- `../_modules/pr-host.md`

- Never copy another model's review under your own prefix — a review file must be the output of the model it names.
- With a workspace `[worktree-context]` block (e.g. `/implement-feature` reviewing its own workspace worktree), *Review Context* reports the worktree's branch as the reviewed head and the user's main-checkout branch separately as "not reviewed".

---

## Modes

| Invocation | Mode | How the axes run |
|---|---|---|
| `/code-review [scope]` | **Standard** (default) | One pass; the reviewer covers all three axes itself |
| `/code-review deep [scope]` | **Deep** | Correctness, Standards and Spec each run in an isolated parallel sub-agent (see *Deep Mode*), then aggregate |
| `/code-review live [scope]` | Standard or deep, **no snapshot** | Reads the main checkout directly instead of the snapshot from *Step 1b*. Only for what cannot be snapshotted — e.g. specific files that were never committed |
| `/code-review feedback [scope]` | Standard or deep, **full thread triage** | Once the review's own findings are verified, runs `/pr-feedback-review`, which writes its own artifact, and folds the PR threads into the review (see *Step 6b*) |

`live` and `feedback` are modifiers, not modes: `/code-review deep live <scope>` and `/code-review deep feedback <pr>` are valid. The token `/no-worktrees` means `live`; `/worktrees` changes nothing, because the snapshot is already the default. Suggest `deep` in the chat response (do not switch silently) when the diff exceeds ~1,500 changed lines or spans both repos with contract changes.

---

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Auditing an implementation plan, not code | [`/plan-review`](../plan-review/SKILL.md) |
| Reviewer comments, threads and votes on the PR | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md), or `/code-review feedback` for a review and a thread triage in one run |
| The PR's pipeline is red | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |
| How to try the change by hand | [`/manual-testing`](../manual-testing/SKILL.md) |
| Quality-only cleanup you intend to apply yourself | [`/refine`](../refine/SKILL.md) or [`/clean`](../clean/SKILL.md) |

---

## Project profile

A project can tune the review through profile skills, resolved per `project-profile` before Step 1: the base profile `<project>-profile`, then the Command profile `code-review-<project>-profile`, with its *Resolution order*, *Shared fields*, *Overrides*, *Upstream content* and *Pointers*. A profile adds project facts and checklists; it never relaxes this skill's invariants (read-only, snapshot, no installs or test runs, verified findings, threads only with `feedback`). Without a profile, every field takes its fallback and the review runs exactly as written below. This skill's own fields:

| Field | What to resolve | Fallback when nothing documents it |
|---|---|---|
| **PR tooling** | The MCP server or CLI for PRs, threads and work items, and its fallback | The `az` / `gh` / `glab` commands in Step 1 |
| **Counterpart pathspecs** | Per repo, the paths to diff on the other side of a dual-repo change | The whole counterpart diff |
| **Review base exceptions** | Release or hotfix bases a branch may target instead of the default | *Branch Discovery* |
| **Sibling hints** | Where the nearest existing feature usually lives, by kind of change | A recent feature's commit (`git log --stat`) |
| **Review checklists** | Per repo: the upstream skill path, the exact headings that apply, which axis each feeds, and what is excluded | None: Step 3's sources only |
| **Lessons catalogs** | Per repo: the upstream path of a catalog of past review findings, and which sections record decisions that rule a finding out | None |
| **Axis and severity mapping** | How the project's own finding tags and severities map onto Correctness / Standards / Spec and 🔴/🟡/🟢 | Not needed |
| **Report additions** | Subsections the project adds inside *Detailed Review Findings* | None |
| **Hand-offs** | What the project checks with other skills instead (verify skills, manual testing) | None |

Name the profiles loaded, and the upstream sha of every checklist and catalog, in the Review Context **Profile** row. A pointed-to heading that cannot be found is reported in the same row.

---

## Step 1 — Determine Scope

Before reviewing any code, resolve the project profile (*Project profile*), then establish **what** to review:

| User says | What to diff |
|---|---|
| `staged` / `commit` | `git diff HEAD <snap>^2` — `<snap>` is the stash commit from *Step 1b*; its second parent is the index |
| `unstaged` / `working` | `git diff HEAD <snap>` — the stash commit's tree is the working tree |
| `branch` / `pr` / (default) | All commits on the current branch vs. its base — see *Branch Discovery* |
| `since <ref>` / a SHA, tag, branch, `HEAD~5` | `git diff <ref>...HEAD` — the user-supplied fixed point is the base |
| Specific file(s) | Read those files from the snapshot — or `live` when they were never committed (*Step 1b-f*) |
| `frontend` / `backend` | Branch diff, scoped to that sub-directory |
| A **pull-request URL** or bare PR id | Resolve it first (see *Pull-Request References* below), then its counterpart in the other repo (*Counterpart PRs*) |
| A work item / issue id (`#30342`, `AB#30342`) | Read the work item, then find its PR or branch |

Whatever the base, confirm it resolves (`git rev-parse <base>`) and the diff is non-empty **before** going further. A bad ref or an empty diff fails here, not halfway through a review (or inside sub-agents).

### Step 1b — Review Snapshot

The review never reads the main checkout. It pins a head per repo in scope, materialises that head in a **detached `git worktree` outside the repo**, and reads everything from there. The user may keep editing the main checkout the whole time; nothing in the review may depend on it. `/code-review live …` skips this step and reads the main checkout as-is.

The lifecycle — create, read, map paths back, remove, fallback — is **`git-worktrees` › *Snapshot Lifecycle* (snapshot mode)** with `<skill>=code-review`; follow it rather than this page for the mechanics. (It also explains why the host's own worktree tooling is not used: it acts on the launch repository and moves the session's working directory, which the artifact links depend on.) What stays review-specific is below: which head each scope pins, the source-ref rule, the main-checkout relation, and untracked files.

**a. Resolve the head per repo in scope**

Resolve the review scope, pinned snapshot head, and diff base:
- For snapshot worktree lifecycle, PR resolution, counterpart PRs across repos, and branch discovery commands, consult [Snapshot & Scope Mechanics](references/snapshot-and-scope.md).
- Follow `git-worktrees` for snapshot isolation and `pr-counterpart` for counterpart discovery.

---

## Step 2 — Identify the Spec Source

Look for what the change was supposed to do, in this order:

1. The PR description and linked work item(s) / acceptance criteria resolved in Step 1 — per repo.
2. A path or pasted text the user supplied.
3. A spec or plan file matching the branch or work item (`docs/`, `specs/`, a `<prefix>-implementation_plan-<suffix>.md` at the workspace root).
4. Work-item ids in commit subjects (`#30342: ...`), fetched as in Step 1.

The same sources feed the artifact's *Feature in Brief*. When the linked item is a bare task, read its parent story for the *why*.

If nothing is found, say so in the header ("Spec: none available — Spec axis limited to unannounced behaviour") and continue. Do not stop to ask unless the user explicitly asked for a spec review.

---

## Step 3 — Identify the Standards Sources

Do not review against conventions from memory. Load what the repo documents, following the `core` precedence (workspace rulebooks > project-scoped skills > tech skills):

0. **The profile's review checklists and lessons catalogs**, when a profile names them: read each from its upstream per `project-profile` › *Upstream content* (never from the snapshot or a registry copy), keep only the headings the profile says apply, and file each under the axis the profile maps it to. Record each as `<repo> origin/<default> @ <short-sha>`.
1. **Rulebooks** for every repo the diff touches: the repo's `CLAUDE.md` / `GEMINI.md`, and whatever canonical rulebook it points to (e.g. `.github/copilot-instructions.md`), plus `CONTRIBUTING.md` / `CODING_STANDARDS.md` if present.
2. **Project-scoped skills** for the touched side — the `[Project: …]`-gated skills the registry provides for this workspace (the workspace rulebook or `.agents/skills.json` lists them, typically one per layer: endpoints, data access, forms, routing, testing, …). Load only those matching the files changed.
3. **Cross-repo contracts** from the workspace-root rulebook — whatever couples the repos: enums shared by integer value, fixed realtime or endpoint URLs, generated clients and checked-in API snapshots, the product's UI language. Use them as a checklist whenever the diff touches either side of a contract — see *Heuristics*.
4. **Tech skills** — language- or framework-level skills for the languages in the diff (e.g. a C# idioms skill for C# changes).

Record the sources you loaded in the artifact header, so a finding's "the rule says" can be traced.

On top of whatever the repo documents, the Standards axis carries the **smell baseline**: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), rated 🟢 unless it causes a concrete defect or maintenance cost you can name. Skip anything tooling already enforces (formatters, linters, analyzers).

| Smell | What it is | Fix |
|---|---|---|
| Mysterious Name | Name doesn't reveal what it does or holds | Rename; if no honest name comes, the design is murky |
| Duplicated Code | Same logic shape in more than one hunk or file | Extract the shared shape, call it from both |
| Feature Envy | Method reaches into another object's data more than its own | Move it onto the data it envies |
| Data Clumps | Same few fields/params keep travelling together | Bundle them into one type |
| Primitive Obsession | Primitive/string standing in for a domain concept | Give the concept its own small type |
| Repeated Switches | Same `switch`/`if`-cascade on the same type recurs | Polymorphism, or one shared map |
| Shotgun Surgery | One logical change forces scattered edits | Gather what changes together |
| Divergent Change | One module edited for several unrelated reasons | Split so each changes for one reason |
| Speculative Generality | Abstraction/params/hooks the spec doesn't need | Delete; inline until a real need shows |
| Message Chains | Long `a.b().c().d()` navigation | Hide the walk behind one method |
| Middle Man | Class/function that mostly delegates onward | Cut it, call the real target |
| Refused Bequest | Subclass ignores most of what it inherits | Drop inheritance, use composition |

---

## Step 4 — Gather Context

1. **List changed files** first (`--name-status`) to understand the blast radius before reading code.
2. **For small diffs** (< ~200 lines): read the raw diff directly.
3. **For large diffs**: read each changed file in full, from the snapshot, with the host's file-reading tool. Do **not** rely solely on truncated diff output — you will miss essential context.
4. **Deleted / moved files**: for every deleted file, grep the snapshot for remaining imports or references to ensure nothing is left dangling.
5. **Do not** run package-manager installs or builds (`npm ci`, `dotnet restore`, `pip install`, `cargo build`, …) unless the user explicitly requests it. The snapshot has no dependencies installed and never needs them.
6. **Do not** run the linter or test suite unless the user explicitly requests it. When a finding depends on runtime behaviour you could not confirm by reading, say so and give the user the exact command to confirm it.
7. **Skip auto-generated files** (e.g. `*.gen.ts`, `*.g.cs`, ORM migration designers / model snapshots, lockfiles) — but do check that generated artifacts which *should* have changed alongside the source did (e.g. a checked-in OpenAPI snapshot after an endpoint change).

---

## Step 5 — Review Along Three Axes

Every finding belongs to exactly one axis. Tag it in the summary table.

### Correctness (key review dimensions)

- **Correctness & Edge Cases**: Logical bugs, off-by-one errors, boundary conditions, race conditions, null/undefined references, unhandled exceptions, missing error handling or logging.
- **Performance & Resource Management**: N+1 query patterns, missing `async/await`, excessive re-renders, missing memoisation on stable references, memory leaks, undisposed resources.
- **Security**: SQL injection, XSS, missing authorization checks, exposed secrets, insecure input validation.

### Standards

- **Documented conventions** from the Step 3 sources. Cite the source (file + rule) for every violation; a documented-standard breach can be a hard finding.
- **Cross-repo contracts** — a broken contract is 🔴 when it breaks the product at runtime, 🟡 otherwise.
- **Design & Maintainability (DRY)**: Duplicated code or types, improper separation of concerns, unnecessary prop drilling.
- **Readability**: Names, comments explaining *why* not *what*, consistent formatting.
- **Smell baseline** — judgement calls, labelled as such.

### Spec

Using the Step 2 source, quoting the spec/AC line for each finding:

- **Missing or partial** — requirements the spec asked for that the diff does not (fully) implement.
- **Wrong** — requirements that look implemented but where the implementation does not do what the spec says.
- **Scope creep / unannounced** — behaviour in the diff that the spec never asked for.
- **Stale description** — the PR text describes an earlier revision.

### Severity

- **🔴 Critical / Defect** — Blocking bugs, security vulnerabilities, broken contracts, or logic errors that produce incorrect behavior.
- **🟡 Important / Design** — Concrete architectural concerns, documented-convention breaches, DRY violations with real cost, meaningful performance issues, missing/wrong spec items. **Not** for pure style: import aliases, a missing modifier, an orphaned doc comment are 🟢.
- **🟢 Minor / Polish** — Readability, naming, minor style suggestions, smell-baseline judgement calls.
- **💙 Praise** — Exceptionally clean code, clever solutions, or solid architectural choices worth highlighting.

Rank severity **within** each axis on its own merits — a spotless Standards result does not soften a Spec gap, and vice versa. The chat response reports the worst finding per axis rather than one overall winner.

---

## Step 6 — Verify Every 🔴 and 🟡

Before writing the artifact, re-check each 🔴/🟡 against the code — not against your notes:

1. **Re-open the cited `path:line`** in the snapshot and confirm the code says what the finding claims. Fix any drifted line numbers.
2. **Try to refute it:** look for the guard, caller, config, or test that would make it a non-issue (e.g. a check one layer up, a query that already filters, a validator that runs first). A finding that a profile's lessons catalog records as a team decision is refuted unless the code contradicts the decision.
3. **Classify:**
   - **Verified** — you traced the failing path in code.
   - **Plausible** — the evidence points to it but part of the path could not be confirmed by reading (runtime config, external service, behaviour needing a test run). Say what would confirm it.
   - **Refuted** — drop it. If it was a near-miss worth knowing, mention it as 🟢 at most.
4. Mark each surviving 🔴/🟡 with its verdict in the finding heading.

In deep mode, the aggregator runs this step on the sub-agents' findings — sub-agent output is evidence, not a verdict.

---

## Step 6b — Fold In PR Feedback (`feedback` only)

Runs only with the `feedback` modifier, and only **after** Step 6. The findings are already formed and verified before any thread is read, so the review stays independent evidence. The threads can change how a finding is linked or settled. They cannot change what the review went looking for.

1. **Needs a PR.** When the scope resolved to no PR (`working`, `staged`, `since <ref>`, specific files), skip this step. Say so in *Review Context* and in chat.
2. **Run `/pr-feedback-review`** for every PR in scope, including a counterpart that joined the scope. Pass the same `deep` / `live` modifiers. Hand it this run's snapshot as a `[worktree-context]` block per repo, so it reads the same pinned head and creates no snapshot of its own (`git-worktrees` › *The `[worktree-context]` Block — Active Repo Root Contract*). It writes its own `<prefix>-pr_feedback_review-<suffix>.md` under `artifact-protocol` › *Ownership* and *Claim*. Use its triage matrix as the input for the rest of this step. If it cannot fetch the threads (auth, CLI missing), continue without them and say so. Never guess what a thread said.
3. **Match each thread to a finding by root cause**, not by file and line alone. Each thread ends up as exactly one of:
   - **Covers finding N**, and the thread is ⏸ / ◐ at head → keep the finding, and add the thread to its *Where* line with the dual link (`artifact-protocol` › *PR Discussion Thread Links*). That lets `/pr-post-comments` reply in that thread instead of opening a duplicate.
   - **Covers finding N, and a recorded decision exists** in the thread ("intentional", "follow-up story #123") → quote the decision in the finding. Keep the severity only if the code contradicts the decision or the decision leaves a defect in place. Otherwise lower it to 🟢 with "decided in thread #id".
   - **Covers finding N, and the thread marks it ✅ Fixed**, but Step 6 still verified the defect at head → the finding stands, and it says the thread's "fixed" is wrong at head.
   - **Raises a defect the review missed** → run Step 6 on it as if the review had found it. Add it when it survives, tagged *raised in thread #id*, on the axis that owns it. Otherwise mark it refuted, with the evidence.
   - **Not a code defect** (a question, a convention preference already answered, ✅ fixed with nothing left at head) → it appears only in the cross-check table below.
4. **A thread never overrides Step 6.** A reviewer who says "this is fine" does not remove a verified finding. A reviewer who says "this is broken" adds nothing until Step 6 verifies it.

---

## Step 7 — Artifact Management & Planning Separation

1. **Write Review Artifact:** Always persist the full code review to `<prefix>-code_review-<suffix>.md` **at the workspace root**. The location is what makes the link clickable — see *Artifact Links* below — so do not put it anywhere else.
   - **Suffix Resolution**:
     - PR / Work Item: `[<id>-]<slug>` (e.g. `18176-contract-templates`, `18176-backend`)
     - Branch / Working Diff: `<branch-slug>` (e.g. `new-users-audit`)
     - Topic / Specific Files: 2–4 word topic slug (e.g. `ticket-category-config`)
2. **Re-reviews:** a re-run in the session that wrote the artifact updates it in place. A re-run in any other session writes a new file (`artifact-protocol` › *Claim* adds `-2`, `-3`, …) unless the user names the existing file and asks for it to be updated (`artifact-protocol` › *Ownership*). Read another model's review of the same PR only if the user asks for a comparison — otherwise review independently, so the two reviews stay independent evidence.
3. **Do Not Modify Code:** Reviews are strictly diagnostic and analytical. Never edit source files or execute mutations during a review. Record nothing as "fixed during review".
4. **Do Not Enter Implementation Planning Mode:** Do not generate an `<prefix>-implementation_plan-<suffix>.md` for a review; go straight to context gathering and findings generation. If an active `<prefix>-implementation_plan-<suffix>.md` already exists in the session, reference and link to it in the header alongside `<prefix>-code_review-<suffix>.md`.

---

## Step 8 — Output Format

### Artifact Links

Format all chat links and section anchors according to the **`artifact-protocol`** protocol (`file://` absolute for Antigravity IDE, workspace-relative in the Claude Code IDE extension, an `antigravity-ide://` editor URL in the Claude Code terminal CLI).

- **Fragment format for INTRA-DOCUMENT links inside markdown files**:
  Internal links *within* the document itself (such as the summary table, finding links, or links to plain terms) must NEVER use `#L<line>`! They are rendered by Markdown Preview and browser HTML renderers, which navigate using HTML anchor tags. Always use semantic HTML anchors `<a id="..."></a>` (e.g., `<a id="finding-1"></a>`, `<a id="finding-1-plain"></a>`, `<a id="minor-findings"></a>`) and links `[1](#finding-1)` / `[plain](#finding-1-plain)` / `[Minor Findings](#minor-findings)`.
- **File location**: Always write `<prefix>-code_review-<suffix>.md` at the **workspace root** so both hosts can access and resolve it.

Because anchors are line numbers, read them off the file **after** you have written it:

```bash
grep -n '^#\{1,3\} ' <prefix>-code_review-<suffix>.md
```

```text
3:## Review Context
18:## Feature in Brief
24:## Summary of Changes
30:## Findings Summary
52:## Detailed Review Findings
164:## In Plain Terms
```

Then begin every `/code-review` response with the header formatted for your host:

**Under Antigravity IDE:**
```markdown
📄 **[antigravity-<model>-code_review-<suffix>.md](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md)**

Key Sections:
- 📄 [Feature in Brief](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L18): [1–2 sentences: who it is for, and what it should achieve]
- 📄 [Summary of Changes](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L24): [1-sentence summary of scope & intent]
- 📄 [Findings Summary](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L30): [🔴/🟡/🟢 counts per axis]
- 📄 [Detailed Review Findings](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L52): [Primary findings and defect analysis]
- 📄 [In Plain Terms](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L164): [Domain-level explanations for non-technical readers]

[If an active <prefix>-implementation_plan-<suffix>.md exists]:
Active Implementation Plan:
📄 **[antigravity-<model>-implementation_plan-<suffix>.md](file://<workspace-root>/antigravity-<model>-implementation_plan-<suffix>.md)**
```

**Under Claude Code:**
```markdown
📄 **[claude-<model>-code_review-<suffix>.md](claude-<model>-code_review-<suffix>.md)**

Key Sections:
- 📄 [Feature in Brief](claude-<model>-code_review-<suffix>.md#L18): [1–2 sentences: who it is for, and what it should achieve]
- 📄 [Summary of Changes](claude-<model>-code_review-<suffix>.md#L24): [1-sentence summary of scope & intent]
- 📄 [Findings Summary](claude-<model>-code_review-<suffix>.md#L30): [🔴/🟡/🟢 counts per axis]
- 📄 [Detailed Review Findings](claude-<model>-code_review-<suffix>.md#L52): [Primary findings and defect analysis]
- 📄 [In Plain Terms](claude-<model>-code_review-<suffix>.md#L164): [Domain-level explanations for non-technical readers]

[If an active <prefix>-implementation_plan-<suffix>.md exists]:
Active Implementation Plan:
📄 **[claude-<model>-implementation_plan-<suffix>.md](claude-<model>-implementation_plan-<suffix>.md)**
```

After the links, the chat response adds: the worst finding **per axis** (one line each, or "clean"), any Spec source that could not be resolved, with `feedback` a link to the `pr_feedback_review` artifact plus one line on the threads (attached / added as findings / refuted / skipped and why), and — if the diff was large — a one-line suggestion to re-run with `deep`. Nothing else; the artifact carries the rest.

If you edit the artifact after emitting the header, the line numbers have moved — re-run the `grep` and re-emit the links rather than leaving stale ones.

**In-review references to source files:**
- Under Antigravity IDE: `[Setup.cs:L264](file://<workspace-root>/api/src/Setup.cs#L264)`
- Under Claude Code: `[Setup.cs:264](api/src/Setup.cs#L264)`
- Paths are always the main-checkout workspace path, never the snapshot directory (*Step 1b-d*). Line numbers refer to the snapshot head recorded in Review Context.

---

### Artifact Structure & Formatting

The review writes `<prefix>-code_review-<suffix>.md` at the workspace root.
Follow [Review Artifact Template & Structure](references/review-artifact-template.md) for the complete section order, summary tables, intra-document anchor conventions (`<a id="finding-N"></a>`), and the *In Plain Terms* format.

---

## Deep Mode

`/code-review deep` runs each axis in its own sub-agent so one axis's context cannot mask another: code that follows every standard can still implement the wrong thing, and code that does exactly what the issue asked can still break conventions.

1. **Do Steps 1–3 yourself first** — base resolved and non-empty diff confirmed, snapshot(s) created (*Step 1b*), Spec source fetched, Standards sources listed. Sub-agents must not re-resolve PRs, re-fetch work items, or create, remove, lock or unlock worktrees (`git-worktrees` invariant 5).
2. **Spawn the sub-agents in parallel** (one message, three calls). Each prompt includes the exact diff command prefixed with the snapshot (`git -C <snapshot> diff <base>...HEAD`), the commit list, the snapshot's **`[worktree-context]` block per repo** (`repo-root` = the snapshot path, **never the main checkout**; `workspace-path` = what every cited path maps back to; `source-ref` = where the head came from), and its axis brief:
   - **Correctness** — "Find bugs, edge cases, race conditions, security and performance issues in this diff. Read whole files where the diff lacks context. For each: `path:line`, the failing path as a concrete sequence, proposed severity (🔴/🟡/🟢). Under 500 words."
   - **Standards** — include the list of Standards source files from Step 3 **and the smell baseline table pasted in full** (the sub-agent has no other access to it). "Report every place the diff violates a documented standard — cite the source file and rule — and any baseline smell you spot, labelled as a judgement call. A documented repo standard overrides the baseline. Check the listed cross-repo contracts on both sides. Skip anything tooling enforces. Under 500 words."
   - **Spec** — include the fetched spec/AC text (not a link). "Report: (a) requirements missing or partial; (b) behaviour in the diff that wasn't asked for; (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each. Under 400 words." Skip this sub-agent when there is no Spec source, and say so.
   - With a profile, the aggregator reads the review checklists and lessons catalogs once (Step 3, source 0) and **pastes** the sections mapped to each axis into that axis's brief. A sub-agent never follows a pointer or reads upstream content itself.
   - All sub-agents are **read-only**: no edits, no checkouts, no worktree commands, no installs, builds or tests. They read only under `repo-root` and report `path:line` already mapped to `workspace-path`.
3. **Aggregate** into the single artifact: de-duplicate findings raised by more than one axis (keep the axis that owns the root cause), assign final severities within each axis, re-check that no citation points into a snapshot directory, then run **Step 6 — Verify** on every 🔴/🟡 yourself before writing. With `feedback`, run *Step 6b* after that, still yourself; the axis sub-agents never see the threads. Write *Feature in Brief* yourself from the Step 2 spec source; no sub-agent writes it. Remove the snapshot(s) afterwards (*Step 1b-e*), after `/pr-feedback-review` has finished with them.

---

## Heuristics & Common Pitfalls

- If the changed files include a **schema or type definition**, search for all consumers to catch downstream type-safety issues.
- If a **context or hook** is changed, verify that all components using it still receive the correct contract.
- If **prop mutation** is spotted (directly modifying a prop object), flag it as 🟡 — use a local `const` copy instead.
- If the same **type is defined in more than one file**, flag it as a DRY violation.
- **Cross-repo contracts:** when the diff touches one side of a contract the workspace rulebook documents, check the other side exists and agrees — typical shapes:
  - a value shared by number or name across repos (an enum, a permission, a status code) → defined on the producing side and reflected on the consuming side, through the consumer's generated facade where one exists (generated files are regenerated, never hand-edited);
  - an API request/response change → the consumer's checked-in API snapshot and generated client types match;
  - a fixed URL or channel name (realtime hub, webhook, queue) → unchanged, or changed in every repo that uses it;
  - user-facing text → in the product's working language, as the rulebook states it.
  When the counterpart PR is in scope (*Counterpart PRs*), check both sides in code; agreement is a ✅ note, a mismatch is the finding. A contract change whose other side was not reviewed (excluded by the user, or expected but missing) is a Spec or Standards finding: name the counterpart and why it was not checked.
- If a citation's line does **not** match what the user sees in the IDE, the user has edited the main checkout since the snapshot was taken — point them at the head in Review Context rather than re-reviewing the live tree.
- If a **comment or XML `<summary>` narrates history or an incident** (PR/ticket numbers, "fixed the CI crash", "changed from X to Y", "why this fix works") or **cross-references sibling code as justification** ("mirrors X", "stricter than the Y export"), flag it as 🟢 — comments should state the code's current responsibility or a real constraint, not its backstory.
- If a change alters what code does or needs but **leaves a now-inaccurate comment/doc in place** (e.g. a documented dependency that was removed), flag the stale comment as 🟡 — a wrong doc is worse than none.
- When writing a plain-language explanation, the **"why this isn't a preference" beat is mandatory for every 🟡**. A design finding without it reads as style commentary and gets waved through. The strongest form is pointing at an existing code path in the same repo that already handles the case correctly.
