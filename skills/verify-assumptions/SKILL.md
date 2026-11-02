---
name: verify-assumptions
description: "Checks the load-bearing claims behind a plan, decision, ADR, artifact or answer against primary sources: the official docs for the version in use, changelogs, the library's source and the local machine. Turns each assumption into a falsifiable claim, verifies them in parallel read-only sub-agents, grades each (confirmed, contradicted, partial, undocumented) with a quote and its source, and says which decisions each verdict weakens or reopens. Use for /verify-assumptions, \"check the official docs\", \"verify your assumptions\", \"fact-check this plan\", \"is that actually documented?\". Read-only until /proceed."
argument-hint: "[deep] [<path> | <claims>]"
---

# Skill: `/verify-assumptions` — Assumption Check Against Primary Sources

Takes what the current context *believes* about tools, libraries, platforms and the environment, and checks each belief against the source that is authoritative for it. The result says which decisions still stand on documented ground, which rest on silence, and which the docs contradict.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: chat by default. With `deep`, or when more than 10 claims are checked, writes `<prefix>-assumption_check-<suffix>.md` at the **workspace root** (suffix derived from the checked plan, decision or topic, e.g. `-skill-modules`, `-tunit-migration`)
- `../_modules/fan-out.md`

- **Read-only until `/proceed`, for you and every sub-agent.** No edits to code, plans, ADRs, glossaries, settings or trackers. A contradicted claim produces a *proposed* edit, never an applied one. Reading files, read-only CLI calls (`--version`, `config get`, `git log`), code-index queries and web fetches are fine.
- **Facts are verified, decisions are not.** Preferences, trade-off choices and naming are the user's; they are never "contradicted by the docs". Only claims about how something *behaves* are in scope.

---

## 1. When to Use

| Argument | Scope |
|---|---|
| *(none)* | The current conversation: the latest plan, decision summary or answer, plus the facts it was built on |
| `<path>` | That artifact, plan, ADR or document |
| `<pasted claims>` | Exactly those claims |
| `deep` | Any of the above, with one sub-agent per source domain and an artifact |

### When *not* to use

| Situation | Use instead |
|---|---|
| Establishing ground truth before there is a design | [`/investigate`](../investigate/SKILL.md) |
| Finding the assumption nobody has stated yet | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |
| Auditing a plan's design quality, not its facts | [`/plan --review`](../plan/SKILL.md) |
| Checking an implementation against its ticket | [`/spec-verification`](../spec-verification/SKILL.md) |
| One quick factual question mid-task | Built-in `/btw` (answers from context, no tools) |

---

## 2. Core Protocol & Workflow

### Step 1: Extract the claims

Read the target and list every assumption it relies on as an **atomic, falsifiable claim** about behaviour: "a skill directory without `SKILL.md` is ignored by the loader", not "the module design is sound".

For each claim record:
- **Domain**: which product or system it is about (Claude Code, a library, Azure DevOps, the codebase, this machine).
- **Load-bearing**: the decision(s) that depend on it. A claim nothing depends on is dropped.
- **Already evidenced?**: if this session already read a primary source that settles it, cite that and do not re-verify.

Keep the list to at most **10 load-bearing claims** by default (`deep` or `>10 claims` writes the artifact); show the list in one short message before dispatching so the user can add or strike claims, then continue without waiting.

### Step 2: Pin the version

Docs only count for the version actually in use. Resolve it before verifying: the lockfile or manifest (`package-lock.json`, `pnpm-lock.yaml`, `*.csproj`, `Directory.Packages.props`), `<tool> --version`, or the platform's API version. When the docs site is unversioned and the claim concerns recent behaviour, also check the changelog or release notes for when it changed.

### Step 3: Route each claim to its authoritative source

Read [`references/source-routing.md`](references/source-routing.md) and record each claim's authoritative source from it before verifying anything.

### Step 4: Verify in parallel

- Claims answerable from local files or one command are checked **inline**.
- Group the rest by source and spawn one **read-only sub-agent per group** (`fan-out`), reusing an existing agent on the same docs when available. Pass the numbered claims verbatim, the pinned version, the domain's `references/source-routing.md` rows plus its *Version match* rule, and require `Confirmed / Contradicted / Partial / Undocumented` with a verbatim quote and `URL#section` or `path:line` (distinguishing silent docs from opposite statements, covering the whole relevant page).

### Step 5: Cross-check

- **Contradicted**: fetch the cited page yourself and confirm the quote before reporting it (`fan-out` › *Aggregation*). A wrong "contradicted" reopens a settled decision for nothing.
- **Undocumented and load-bearing**: look for a cheap read-only way to observe the real behaviour locally. If there is none, mark it a risk and name the experiment that would settle it.
- **Docs versus the pinned version**: apply `references/source-routing.md` › *Version match* to every cited page.
- **Docs versus this machine**: when a documented rule depends on configuration, check the actual config and state which case applies here.

### Step 6: Map verdicts to decisions

For every claim that is not plainly confirmed, say what it does to the decision(s) that rested on it:
- **Holds**: the decision still stands (say why).
- **Weakened**: still defensible, but the rationale or consequences need updating (draft the exact wording change).
- **Reopen**: the decision no longer stands (restate the question for the user with your recommendation).

---

## 3. Output Format & Deliverables

Read [`references/report-template.md`](references/report-template.md): the chat table always, plus the artifact with `deep` or more than 10 claims.

---

## 4. Verification & Validation

- Every verdict cites a primary source (`URL#section` or `path:line`) or is explicitly **Undocumented** with the searched sources; every **Contradicted** quote was re-fetched and confirmed by the main agent.
- The pinned version is stated, and `git status` in every repo plus all plans/ADRs/docs are unchanged.
