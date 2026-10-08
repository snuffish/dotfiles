---
name: code-review
description: Perform a structured, high-quality review of code changes along three axes — Correctness (bugs, security, performance), Standards (does the code follow this repo's documented conventions and cross-repo contracts?) and Spec (does it implement what the PR / work item / acceptance criteria asked for?). Accepts an optional pull-request URL/ID, work-item ID, or fixed point ("since main", a SHA, a tag) — and resolves the PR from the current branch when none is given. `deep` runs the axes as parallel sub-agents. Use when the user asks for a code review, PR review, "review since X", or feedback on a branch or working changes.
---

# Code Review Skill

Use this skill whenever the user requests a code review, feedback on a pull request, a review of a branch or working changes, or a "review since X".

---

## ⛔ Mandatory Invariants

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR DEVIATION:**
>
> 1. **MANDATORY .MD ARTIFACT & SUMMARY (NO EXCUSES):** Every single `/code-review` response MUST ALWAYS write or update the complete review report as `<prefix>-code_review-<suffix>.md` **at the workspace root**, and begin the response with a clickable link to it plus clickable section anchors, built exactly as *Artifact Links* below specifies. If an active `<prefix>-implementation_plan-<suffix>.md` exists, link that too. The user frequently needs to click and open it in the IDE.
> 2. **DO NOT MODIFY CODE OR THE WORKING TREE:** Never edit code files, stage commits, run migrations, check out branches, stash, or execute any modifying command during or immediately after a `/code-review`. If the tree is not the one to review, say so and ask (see *Get the right code checked out*).
> 3. **DO NOT AUTO-PROCEED:** Never begin implementing fixes or refactorings automatically. Wait for explicit user instruction or `/proceed`.
> 4. **NO UNVERIFIED FINDINGS:** Every 🔴/🟡 must survive Step 6 (*Verify*) before it is written.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **Target Artifact**: `<prefix>-code_review-<suffix>.md` at the **workspace root** (where `<prefix>` is `<host>-<model>-`, e.g. `antigravity-gemini-3.8-flash-` or `claude-sonnet-3.7-`).
- **Anti-Overwrite Rule**: Always include the active AI model in `<prefix>` and append a descriptive kebab-case `<suffix>` (e.g. `-18176-verksamhetsobjekt`, `-category-demand-statistics`). Never write unsuffixed or un-modeled generic files, and never copy another model's review under your own prefix — a review file must be the output of the model it names.

---

## Modes

| Invocation | Mode | How the axes run |
|---|---|---|
| `/code-review [scope]` | **Standard** (default) | One pass; the reviewer covers all three axes itself |
| `/code-review deep [scope]` | **Deep** | Correctness, Standards and Spec each run in an isolated parallel sub-agent (see *Deep Mode*), then aggregate |

Suggest `deep` in the chat response (do not switch silently) when the diff exceeds ~1,500 changed lines or spans both repos with contract changes.

---

### When *not* to use — pick the right neighbor

| Situation | Use instead |
|---|---|
| Auditing an implementation plan, not code | [`/review`](../review/SKILL.md) |
| Reviewer comments, threads and votes on the PR | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| The PR's pipeline is red | [`/pr-fix-pipeline`](../pr-fix-pipeline/SKILL.md) |
| How to try the change by hand | [`/manual-testing`](../manual-testing/SKILL.md) |
| Quality-only cleanup you intend to apply yourself | [`/refine`](../refine/SKILL.md) or [`/clean`](../clean/SKILL.md) |

---

## Step 1 — Determine Scope

Before reviewing any code, establish **what** to review:

| User says | What to diff |
|---|---|
| `staged` / `commit` | `git diff --staged` |
| `unstaged` / `working` | `git diff` |
| `branch` / `pr` / (default) | All commits on the current branch vs. its base — see *Branch Discovery* |
| `since <ref>` / a SHA, tag, branch, `HEAD~5` | `git diff <ref>...HEAD` — the user-supplied fixed point is the base |
| Specific file(s) | Read those files directly |
| `frontend` / `backend` | Branch diff, scoped to that sub-directory |
| A **pull-request URL** or bare PR id | Resolve it first — see *Pull-Request References* below |
| A work item / issue id (`#30342`, `AB#30342`) | Read the work item, then find its PR or branch |

Whatever the base, confirm it resolves (`git rev-parse <base>`) and the diff is non-empty **before** going further. A bad ref or an empty diff fails here, not halfway through a review (or inside sub-agents).

### Pull-Request References

When the user passes a PR/MR URL or id, resolve it **before** diffing. The description and its acceptance criteria state what the change was *supposed* to do — the single most useful piece of context a reviewer can have, and the only way to spot "promised but not implemented". It is the primary source for the **Spec** axis.

Parse the URL into its parts. Azure DevOps:

```text
https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{prId}

e.g.  .../grutbildning/PRIIS/_git/52f22501-...-f597ebeaacf9/pullrequest/18106
      org = grutbildning   project = PRIIS   repo = <guid>   prId = 18106
```

`{repo}` is often a GUID rather than a name — pass it through unchanged, the API accepts either. Other hosts: GitHub `/{owner}/{repo}/pull/{n}`, GitLab `/{group}/{project}/-/merge_requests/{n}`, Bitbucket `/{workspace}/{repo}/pull-requests/{n}`.

Always use the `https://dev.azure.com/<org>` form for `--org`. The legacy `https://<org>.visualstudio.com` host fails with an authentication error even when `az` is signed in.

#### No URL given — resolve the PR from the branch

Do not skip the description just because the user did not paste a link. A checked-out branch almost always *has* a PR; find it.

```bash
# Azure DevOps — run inside the repo; --detect reads org/project from the git remote
az repos pr list --source-branch "$(git rev-parse --abbrev-ref HEAD)" \
  --status active --detect true \
  --query '[].{id:pullRequestId,title:title,tgt:targetRefName}' -o json

# GitHub — no argument means "the PR for the current branch"
gh pr view --json number,title,body,baseRefName
```

`--detect true` resolves org/project from either an HTTPS or an SSH `dev.azure.com` remote. Add `--status all` if the PR may already be completed or abandoned; widen to `--repository <name>` when reviewing a repo you are not standing in.

Then feed the resulting id into the fetch commands below.

**In a multi-repo workspace, do this per repo.** A feature split across repos has one PR *per repo*, each with its own description and its own work item — resolving only the one you happen to be standing in gets you half the intent:

```bash
for d in */; do
  [ -d "$d/.git" ] || continue
  b=$(git -C "$d" rev-parse --abbrev-ref HEAD)
  echo "== $d ($b)"
  (cd "$d" && az repos pr list --source-branch "$b" --status active --detect true \
     --query '[].{id:pullRequestId,title:title}' -o tsv)
done
```

Report which repos resolved to a PR and which did not — a repo still sitting on the integration branch is itself worth saying out loud.

##### Finding the counterpart PR in the other repo

The two sides usually carry **different** work item ids (e.g. backend `#30342`, frontend `#30343`), so matching on the number in the branch name will not find the sibling. Walk the work-item relations instead:

```bash
az boards work-item relation show --id <workItemId> --org https://dev.azure.com/<org> -o json
```

Look for `Parent`, `Related`, and child links; the sibling story is normally under the same parent feature. Its own branch/PR is then discoverable with the commands above.

#### Fetch the PR and its work item

Use whichever CLI the host provides. Check availability first (`command -v az gh glab`):

```bash
# Azure DevOps (az + azure-devops extension)
az repos pr show --id <prId> --org https://dev.azure.com/<org> \
  --query '{title:title,status:status,repo:repository.name,src:sourceRefName,tgt:targetRefName,desc:description}' -o json
az repos pr work-item list --id <prId> --org https://dev.azure.com/<org> -o json   # linked work items

# GitHub
gh pr view <n> --json title,body,headRefName,baseRefName,state,files

# GitLab
glab mr view <n>
```

Follow linked work items — that is usually where the acceptance criteria actually live:

```bash
az boards work-item show --id <workItemId> --org https://dev.azure.com/<org> \
  --query '{title:fields."System.Title",state:fields."System.State",desc:fields."System.Description",ac:fields."Microsoft.VSTS.Common.AcceptanceCriteria"}' -o json
```

Descriptions and AC fields are usually **HTML**. Strip the tags before quoting them. When the work item has no AC field, say so and name what you used instead (parent feature, description, linked wiki page).

**A resolved PR also settles the diff base:** its `targetRefName` *is* the base — use it directly instead of the fallback chain in *Branch Discovery* below.

#### When the fetch fails

Do not silently continue as if no reference was given, and do not guess the contents from the branch name.

- **Auth error** (`The requested resource requires user authentication`) — first check the `--org` URL is the `dev.azure.com` form. If it is, the CLI is not signed in. Give the user the one-liner and continue diff-only meanwhile, saying so:
  ```bash
  az devops login --organization https://dev.azure.com/<org>   # paste a PAT with Code: Read
  # or: export AZURE_DEVOPS_EXT_PAT=<pat>
  ```
- **CLI missing** — say which one and offer to work from the diff alone.
- **Fetch blocked entirely** — ask the user to paste the description.

An unauthenticated web fetch of a private PR URL returns a login page, not the PR. Never treat that as the description.

#### Offline fallback

When no CLI is authenticated, the branch name and commit subjects still carry the work item id — most conventions embed it (`feature/30342_persist-...`, `#30342: <subject>`):

```bash
git rev-parse --abbrev-ref HEAD
git log --oneline <base>...HEAD
```

That gives you the id to quote and to hand back to the user, but **not** the acceptance criteria. Say which one you have. Never infer what a description said from a branch slug.

#### Get the right code checked out

A PR URL usually means the user is *not* on that branch. Verify before diffing, and state the mismatch rather than reviewing the wrong tree:

```bash
git rev-parse --abbrev-ref HEAD                       # where am I?
git fetch origin <sourceRefName>                      # read-only: updates remote refs only
git diff origin/<targetRef>...origin/<sourceRef>      # review without checking out
```

Prefer reviewing the fetched remote ref directly — it needs no checkout (`git show origin/<sourceRef>:<path>` reads a whole file). If a checkout is genuinely needed, **ask first** and offer `az repos pr checkout --id <prId>` / `gh pr checkout <n>`; never check out, stash, or reset on your own.

Review the **committed PR head**. If the working tree has uncommitted changes on top, say so in the header and review them only when the user asks.

#### How much to trust the description

**The description states intent; the diff states truth.** Where they disagree the diff wins, and the disagreement is itself a **Spec** finding:

- AC promises behavior with no corresponding change in the diff → 🔴/🟡 *claimed but not implemented*.
- The diff changes user-visible behavior the description never mentions → review it anyway and flag the unannounced change (*scope creep*); that is where regressions hide.
- The description describes an earlier revision of the branch → note it as stale and follow the diff.

Never let the description's structure or omissions shape the review. It is evidence, not an outline.

---

### Branch Discovery

When the scope is a branch diff and no PR or user-supplied fixed point gave you the base, find it — **do not guess**, and **do not use `@{u}`**: on a feature branch the upstream is the branch's own remote copy, which yields an empty diff.

```bash
# 1. The remote's default branch (e.g. origin/main)
git symbolic-ref --short refs/remotes/origin/HEAD

# 2. Fall back only if origin/HEAD is unset: the integration branches that actually exist
git branch -r --list 'origin/main' 'origin/develop' 'origin/master'

# 3. Build the diff using the merge-base (three-dot syntax):
git diff <base>...HEAD --name-status
git log --oneline <base>..HEAD
```

Always use the **three-dot** form (`A...B`) so you see only the commits introduced by this branch, not divergent commits on the base. State the base you used in the artifact header.

---

## Step 2 — Identify the Spec Source

Look for what the change was supposed to do, in this order:

1. The PR description and linked work item(s) / acceptance criteria resolved in Step 1 — per repo.
2. A path or pasted text the user supplied.
3. A spec or plan file matching the branch or work item (`docs/`, `specs/`, a `<prefix>-implementation_plan-<suffix>.md` at the workspace root).
4. Work-item ids in commit subjects (`#30342: ...`), fetched as in Step 1.

If nothing is found, say so in the header ("Spec: none available — Spec axis limited to unannounced behaviour") and continue. Do not stop to ask unless the user explicitly asked for a spec review.

---

## Step 3 — Identify the Standards Sources

Do not review against conventions from memory. Load what the repo documents, following the `core` precedence (workspace rulebooks > project-scoped skills > tech skills):

1. **Rulebooks** for every repo the diff touches: the repo's `CLAUDE.md` / `GEMINI.md`, and whatever canonical rulebook it points to (e.g. `.github/copilot-instructions.md`), plus `CONTRIBUTING.md` / `CODING_STANDARDS.md` if present.
2. **Project-scoped skills** for the touched side — e.g. `backend-fastendpoints`, `backend-ef-core`, `backend-testing` for backend endpoints/queries/tests, `backend-notifications` / `backend-signalr` for jobs and realtime, `backend-dry` for duplication; `frontend-rtk-query`, `frontend-forms`, `frontend-component-patterns`, `frontend-routing` for frontend, `frontend-testing` for Playwright specs and test IDs. Load only those matching the files changed.
3. **Cross-repo contracts** from the workspace-root `CLAUDE.md` (in PRIIS: `SystemAction` integer values, the `/realtime/account` hub URL, `x-enumMetadata` / `x-roleAccessRules` OpenAPI extensions, sv-SE UI text). Use them as a checklist whenever the diff touches either side of a contract — see *Heuristics*.
4. **Tech skills** — e.g. `modern-csharp` for C# changes.

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
3. **For large diffs**: read each changed file in full with the host's file-reading tool. Do **not** rely solely on truncated diff output — you will miss essential context.
4. **Deleted / moved files**: for every deleted file, grep the codebase for remaining imports or references to ensure nothing is left dangling.
5. **Do not** run `npm ci`, `npm install`, `dotnet restore`, or any install/build commands unless the user explicitly requests it.
6. **Do not** run the linter or test suite unless the user explicitly requests it. When a finding depends on runtime behaviour you could not confirm by reading, say so and give the user the exact command to confirm it.
7. **Skip auto-generated files** (e.g., `routeTree.gen.ts`, `*.g.cs`, `*.gen.ts`, EF `*.Designer.cs` / model snapshots) — but do check that generated artifacts which *should* have changed alongside the source did (e.g. a checked-in `swagger.json` snapshot after an endpoint change).

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

1. **Re-open the cited `path:line`** in the reviewed revision and confirm the code says what the finding claims. Fix any drifted line numbers.
2. **Try to refute it:** look for the guard, caller, config, or test that would make it a non-issue (e.g. a check one layer up, a query that already filters, a validator that runs first).
3. **Classify:**
   - **Verified** — you traced the failing path in code.
   - **Plausible** — the evidence points to it but part of the path could not be confirmed by reading (runtime config, external service, behaviour needing a test run). Say what would confirm it.
   - **Refuted** — drop it. If it was a near-miss worth knowing, mention it as 🟢 at most.
4. Mark each surviving 🔴/🟡 with its verdict in the finding heading.

In deep mode, the aggregator runs this step on the sub-agents' findings — sub-agent output is evidence, not a verdict.

---

## Step 7 — Artifact Management & Planning Separation

1. **Write Review Artifact:** Always persist the full code review to `<prefix>-code_review-<suffix>.md` **at the workspace root**. The location is what makes the link clickable — see *Artifact Links* below — so do not put it anywhere else.
   - **Suffix Resolution**:
     - PR / Work Item: `[<id>-]<slug>` (e.g. `18176-verksamhetsobjekt`, `18176-backend`)
     - Branch / Working Diff: `<branch-slug>` (e.g. `new-users-audit`)
     - Topic / Specific Files: 2–4 word topic slug (e.g. `ticket-category-config`)
2. **Re-reviews:** re-running on the same PR with the same model updates that artifact in place. Read another model's review of the same PR only if the user asks for a comparison — otherwise review independently, so the two reviews stay independent evidence.
3. **Do Not Modify Code:** Reviews are strictly diagnostic and analytical. Never edit source files or execute mutations during a review. Record nothing as "fixed during review".
4. **Do Not Enter Implementation Planning Mode:** Do not generate an `<prefix>-implementation_plan-<suffix>.md` for a review; go straight to context gathering and findings generation. If an active `<prefix>-implementation_plan-<suffix>.md` already exists in the session, reference and link to it in the header alongside `<prefix>-code_review-<suffix>.md`.

---

## Step 8 — Output Format

### Artifact Links

Format all chat links and section anchors according to the **[artifacts](../artifacts/SKILL.md)** protocol (`file://` absolute for Antigravity IDE, workspace-relative for Claude Code, `#L<line>` line fragments for chat).

- **Fragment format for INTRA-DOCUMENT links inside markdown files**:
  Internal links *within* the document itself (such as the summary table, finding links, or links to plain terms) must NEVER use `#L<line>`! They are rendered by Markdown Preview and browser HTML renderers, which navigate using HTML anchor tags. Always use semantic HTML anchors `<a id="..."></a>` (e.g., `<a id="finding-1"></a>`, `<a id="finding-1-plain"></a>`, `<a id="minor-findings"></a>`) and links `[1](#finding-1)` / `[plain](#finding-1-plain)` / `[Minor Findings](#minor-findings)`.
- **File location**: Always write `<prefix>-code_review-<suffix>.md` at the **workspace root** so both hosts can access and resolve it.

Because anchors are line numbers, read them off the file **after** you have written it:

```bash
grep -n '^#\{1,3\} ' <prefix>-code_review-<suffix>.md
```

```text
3:## Review Context
18:## Summary of Changes
26:## Findings Summary
48:## Detailed Review Findings
160:## In Plain Terms
```

Then begin every `/code-review` response with the header formatted for your host:

**Under Antigravity IDE:**
```markdown
📄 **[antigravity-<model>-code_review-<suffix>.md](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md)**

Key Sections:
- 📄 [Summary of Changes](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L18): [1-sentence summary of scope & intent]
- 📄 [Findings Summary](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L26): [🔴/🟡/🟢 counts per axis]
- 📄 [Detailed Review Findings](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L48): [Primary findings and defect analysis]
- 📄 [In Plain Terms](file://<workspace-root>/antigravity-<model>-code_review-<suffix>.md#L160): [Domain-level explanations for non-technical readers]

[If an active <prefix>-implementation_plan-<suffix>.md exists]:
Active Implementation Plan:
📄 **[antigravity-<model>-implementation_plan-<suffix>.md](file://<workspace-root>/antigravity-<model>-implementation_plan-<suffix>.md)**
```

**Under Claude Code:**
```markdown
📄 **[claude-<model>-code_review-<suffix>.md](claude-<model>-code_review-<suffix>.md)**

Key Sections:
- 📄 [Summary of Changes](claude-<model>-code_review-<suffix>.md#L18): [1-sentence summary of scope & intent]
- 📄 [Findings Summary](claude-<model>-code_review-<suffix>.md#L26): [🔴/🟡/🟢 counts per axis]
- 📄 [Detailed Review Findings](claude-<model>-code_review-<suffix>.md#L48): [Primary findings and defect analysis]
- 📄 [In Plain Terms](claude-<model>-code_review-<suffix>.md#L160): [Domain-level explanations for non-technical readers]

[If an active <prefix>-implementation_plan-<suffix>.md exists]:
Active Implementation Plan:
📄 **[claude-<model>-implementation_plan-<suffix>.md](claude-<model>-implementation_plan-<suffix>.md)**
```

After the links, the chat response adds: the worst finding **per axis** (one line each, or "clean"), any Spec source that could not be resolved, and — if the diff was large — a one-line suggestion to re-run with `deep`. Nothing else; the artifact carries the rest.

If you edit the artifact after emitting the header, the line numbers have moved — re-run the `grep` and re-emit the links rather than leaving stale ones.

**In-review references to source files:**
- Under Antigravity IDE: `[Setup.cs:L264](file://<workspace-root>/GR.PRIIS.Backend/source/GR.PRIIS.Library/Setup.cs#L264)`
- Under Claude Code: `[Setup.cs:264](GR.PRIIS.Backend/source/GR.PRIIS.Library/Setup.cs#L264)`

---

### Artifact Structure

Sections in this order, and **nothing after In Plain Terms**:

1. `## Review Context` — a small table: PR(s) and work item(s) per repo, base and head reviewed, Spec source (or "none available"), Standards sources loaded, mode (standard/deep).
2. `## Summary of Changes` — 1–3 sentences on what the changes accomplish and their architectural intent.
3. `## Findings Summary` — the summary table.
4. `## Detailed Review Findings` — 🔴/🟡 findings with their fix inline, then `### 🟢 Minor Findings`, then `### 💙 Praise`.
5. `## In Plain Terms` — only when there is at least one 🔴/🟡.

### Findings Summary Table

| # | Severity | Axis | File | Issue |
|---|---|---|---|---|
| [1](#finding-1) · [plain](#finding-1-plain) | 🔴 | Correctness | `foo.ts` | Missing null check on `userId` |
| [2](#finding-2) · [plain](#finding-2-plain) | 🟡 | Spec | `bar.tsx` | AC "per kategori" not implemented |
| [3](#finding-3) · [plain](#finding-3-plain) | 🟡 | Standards | `Baz.cs` | Read query tracks entities (backend rulebook: reads use `AsNoTracking`) |
| 4–7 | 🟢 | various | various | Polish — see [Minor Findings](#minor-findings) |

**Intra-document anchor rules:**
Place explicit HTML anchor tags `<a id="..."></a>` before each section and finding so the table links work in Markdown Preview and when reading the document:
- Precede each detailed finding with `<a id="finding-N"></a>` (e.g. `<a id="finding-1"></a>\n\n### 🔴 1 — ... · Verified`)
- Precede each plain-terms explanation with `<a id="finding-N-plain"></a>` (e.g. `<a id="finding-1-plain"></a>\n\n### 1. ...`)
- Precede minor findings with `<a id="minor-findings"></a>\n\n### 🟢 Minor Findings`
- Only 🔴/🟡 rows get a `[plain](#finding-N-plain)` link — every `plain` link in the table must resolve to an anchor that exists.

### Detailed Findings

Each 🔴/🟡 finding carries, in this order:

1. **Heading** — `### <sev> N — <title> · Verified|Plausible`
2. **Where** — clickable `path:line` link(s).
3. **What and why** — the failing path or broken rule; for Standards cite the source rule, for Spec quote the spec/AC line.
4. **Fix** — a concrete code block or diff with a one-line rationale. When the fix is a decision rather than code (e.g. "choose between X and Y"), write **Decision needed:** with the options instead of a diff.

```diff
- public class UserService {
+ public sealed class UserService {
```

Keep evidence tight: quote the few relevant lines, never paste terminal or grep dumps.

**🟢 Minor Findings** — a compact list, one line each with a `path:line` link and no diff. **Cap at 8**; if there are more, list the 8 most useful and end with "+N more of the same kind: <kinds>".

**💙 Praise** — 1–3 bullets.

### In Plain Terms

After the detailed findings, add a plain-language explanation of every 🔴 and 🟡
finding. Technical readers skip it; product owners, testers, and the person who has to
decide whether this blocks a release read only it.

Write each one as four beats, in this order:

1. **What the code is trying to do** — one sentence, in domain nouns (*avtalsmall*,
   *delområde*, *handläggare*), never type names (`ContractTemplate`, `SubareaContract`).
   Keep the product's own word for a thing so the team recognises it, but gloss it in
   English the first time it appears — "*avtalsmall* (the master contract that subareas
   hang off)" — then use the term unglossed.
2. **What actually happens** — the failure as a numbered sequence of events with real
   actors, not as a conditional rule. "1. A handler pauses a contract. 2. They close the
   subarea — the guard only looks for *active* contracts, finds none, allows it. 3. …"
   Sequences are concrete; rules are not. For a Spec finding: what the user was promised
   versus what they actually get.
3. **Why it's a defect and not a matter of taste** — name the contradiction: another code
   path already does it correctly, a stated promise in the PR is broken, or the data ends
   up self-inconsistent. Without this beat the reader can dismiss the finding as opinion.
4. **Who notices and how bad** — the user-visible symptom, and why the severity is what it
   is ("nothing crashes, but records silently stay in the wrong state").

Rules:

- **No code, no type names, no method signatures, no backticks.** If a name is unavoidable,
  gloss it once in domain terms and move on.
- **A three-line ASCII hierarchy or sequence diagram is often worth more than a paragraph.**
  Use one when the finding is about how data or calls nest:
  ```text
  Avtalsmall  →  Delområden  →  Avtal
  ```
- **Don't repeat the fix.** Reference the numbered finding; the diff already lives above.
- **Skip 🟢 and 💙.** Polish and praise don't need restating.
- **Cap each at ~150 words.** If one needs more, the technical finding above it is
  underexplained — fix that instead of padding here.
- **Always write this section in simple English**, whatever language the rest of the review
  uses and whatever the product's working language is (a Swedish product still gets an
  English explanation here). Don't add a line explaining the language choice.
- **Simple means simple.** Short declarative sentences, everyday words, one idea per
  sentence. "The record stays in the wrong state" — not "the entity's status remains
  inconsistent with its parent aggregate". Split any sentence that needs a second clause to
  survive. No acronyms without expanding them, no jargon a tester wouldn't use out loud.
- If the review produced no 🔴 or 🟡 findings, omit the section entirely rather than
  writing "nothing to explain".

---

## Deep Mode

`/code-review deep` runs each axis in its own sub-agent so one axis's context cannot mask another: code that follows every standard can still implement the wrong thing, and code that does exactly what the issue asked can still break conventions.

1. **Do Steps 1–3 yourself first** — base resolved and non-empty diff confirmed, Spec source fetched, Standards sources listed. Sub-agents must not re-resolve PRs or re-fetch work items.
2. **Spawn the sub-agents in parallel** (one message, three calls). Each prompt includes the exact diff command (`git diff <base>...HEAD`), the commit list, the repo paths, and its axis brief:
   - **Correctness** — "Find bugs, edge cases, race conditions, security and performance issues in this diff. Read whole files where the diff lacks context. For each: `path:line`, the failing path as a concrete sequence, proposed severity (🔴/🟡/🟢). Under 500 words."
   - **Standards** — include the list of Standards source files from Step 3 **and the smell baseline table pasted in full** (the sub-agent has no other access to it). "Report every place the diff violates a documented standard — cite the source file and rule — and any baseline smell you spot, labelled as a judgement call. A documented repo standard overrides the baseline. Check the listed cross-repo contracts on both sides. Skip anything tooling enforces. Under 500 words."
   - **Spec** — include the fetched spec/AC text (not a link). "Report: (a) requirements missing or partial; (b) behaviour in the diff that wasn't asked for; (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each. Under 400 words." Skip this sub-agent when there is no Spec source, and say so.
   - All sub-agents are **read-only**: no edits, no checkouts, no installs, builds or tests.
3. **Aggregate** into the single artifact: de-duplicate findings raised by more than one axis (keep the axis that owns the root cause), assign final severities within each axis, then run **Step 6 — Verify** on every 🔴/🟡 yourself before writing.

---

## Heuristics & Common Pitfalls

- If the changed files include a **schema or type definition**, search for all consumers to catch downstream type-safety issues.
- If a **context or hook** is changed, verify that all components using it still receive the correct contract.
- If **prop mutation** is spotted (directly modifying a prop object), flag it as 🟡 — use a local `const` copy instead.
- If the same **type is defined in more than one file**, flag it as a DRY violation.
- **Cross-repo contracts (PRIIS):** when the diff touches one side, check the other side exists and agrees —
  - a new/changed `SystemAction` member → member with `[Display(Name = "…")]` in backend `AccessRules/Actions/SystemAction.cs`, granted in the relevant `AccessRules/Roles/<Role>AccessRules.cs` `AllowedActions`; the frontend enum is regenerated from the OpenAPI snapshot (`src/enums/systemAction.ts` is a generated facade, never hand-edited), menu item and tab `systemActions` (the full checklist lives in both `copilot-instructions.md` files);
  - an endpoint request/response change → the frontend's checked-in OpenAPI snapshot and RTK Query types match;
  - an enum gaining/losing `[EmitOpenApiMetadata]`, `[Display]`, `[DisplayContext]` → frontend facade in `src/enums/` and generated `…Names` maps;
  - the SignalR hub URL `/realtime/account` → unchanged, or changed in both repos;
  - user-facing text and validation messages → Swedish.
  A contract change with only one side in the reviewed PR(s) is a Spec or Standards finding even if the counterpart PR exists — name the counterpart and whether you reviewed it.
- If a **comment or XML `<summary>` narrates history or an incident** (PR/ticket numbers, "fixed the CI crash", "changed from X to Y", "why this fix works") or **cross-references sibling code as justification** ("mirrors X", "stricter than the Y export"), flag it as 🟢 — comments should state the code's current responsibility or a real constraint, not its backstory.
- If a change alters what code does or needs but **leaves a now-inaccurate comment/doc in place** (e.g. a documented dependency that was removed), flag the stale comment as 🟡 — a wrong doc is worse than none.
- When writing a plain-language explanation, the **"why this isn't a preference" beat is mandatory for every 🟡**. A design finding without it reads as style commentary and gets waved through. The strongest form is pointing at an existing code path in the same repo that already handles the case correctly.
