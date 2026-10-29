---
name: verify-assumptions
description: "Checks the load-bearing claims behind a plan, decision, ADR, artifact or answer against primary sources: the official docs for the version in use, changelogs, the library's source and the local machine. Turns each assumption into a falsifiable claim, verifies them in parallel read-only sub-agents, grades each (confirmed, contradicted, partial, undocumented) with a quote and its source, and says which decisions each verdict weakens or reopens. Use for /verify-assumptions, \"check the official docs\", \"verify your assumptions\", \"fact-check this plan\", \"is that actually documented?\". Read-only until /proceed."
---

# Skill: `/verify-assumptions` — Assumption Check Against Primary Sources

Takes what the current context *believes* about tools, libraries, platforms and the environment, and checks each belief against the source that is authoritative for it. The result says which decisions still stand on documented ground, which rest on silence, and which the docs contradict.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: chat by default. With `deep`, or when more than 10 claims are checked, writes `<prefix>-assumption_check-<suffix>.md` at the **workspace root** (suffix derived from the checked plan, decision or topic, e.g. `-skill-modules`, `-tunit-migration`)

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
| Auditing a plan's design quality, not its facts | [`/plan-review`](../plan-review/SKILL.md) |
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

Keep the list to the ~12 most load-bearing claims by default; `deep` lifts the cap. Show the list in one short message before dispatching so the user can add or strike claims, then continue without waiting.

### Step 2: Pin the version

Docs only count for the version actually in use. Resolve it before verifying: the lockfile or manifest (`package-lock.json`, `pnpm-lock.yaml`, `*.csproj`, `Directory.Packages.props`), `<tool> --version`, or the platform's API version. When the docs site is unversioned and the claim concerns recent behaviour, also check the changelog or release notes for when it changed.

### Step 3: Route each claim to its authoritative source

| Domain | Authoritative source | Leads only, never evidence |
|---|---|---|
| Claude Code, Agent SDK, Claude API | The official docs (`code.claude.com/docs`, `docs.claude.com`); in Claude Code delegate to the `claude-code-guide` agent | Blog posts, forum answers, model memory |
| Libraries and frameworks | The official docs at the pinned version, then the package's source or type definitions (`node_modules/…`, the NuGet package, the GitHub tag) | Stack Overflow, tutorials |
| Platforms (Azure DevOps, GitHub, cloud services) | Official REST and CLI reference, `--help` output | Third-party wrappers |
| The codebase | The code itself at the current head, through the code index when one exists (e.g. a `.codegraph/` directory) | Comments, READMEs that may have drifted |
| This machine | The config files and read-only commands that show the real state (settings files, `env`, `--version`) | Assumed defaults |

When the docs are silent, the source code is the next authority. Note the gap: "undocumented but the source does X" is a weaker basis than a documented guarantee.

### Step 4: Verify in parallel

- Claims answerable from local files or one command are checked **inline**.
- Group the rest by source and give each group one **background, read-only sub-agent**, all spawned in the same message. Reuse an agent that already researched the same docs this session (e.g. `SendMessage` in Claude Code) instead of starting cold.
- Each brief is self-contained: the claims verbatim and numbered, the pinned version, the sources to use, and this contract — *"Read-only. For each claim answer Confirmed / Contradicted / Partial / Undocumented with a short verbatim quote and URL#section (or path:line). Say explicitly when the docs are silent versus when they say the opposite. Cover the whole relevant page, not just its first screen. At most ~400 words."*
- Never predict a verdict while a sub-agent is still running.

### Step 5: Cross-check

- **Contradicted**: fetch the cited page yourself and confirm the quote before reporting it. A wrong "contradicted" reopens a settled decision for nothing.
- **Undocumented and load-bearing**: look for a cheap read-only way to observe the real behaviour locally (an existing config, a directory that already exercises the case). If there is none, mark it a risk and name the experiment that would settle it.
- **Docs versus this machine**: when a documented rule depends on configuration ("prompts unless an allow rule exists"), check the actual config and state which case applies here.

### Step 6: Map verdicts to decisions

For every claim that is not plainly confirmed, say what it does to the decision(s) that rested on it:

- **Holds**: the decision still stands. Say why, e.g. the plan never depended on the contradicted part, or another fact carries it.
- **Weakened**: still defensible, but the rationale or consequences need updating. Draft the exact wording change.
- **Reopen**: the decision no longer stands. Restate the question for the user with your recommendation. Do not decide it for them.

Also note anything the sources revealed that the context did not consider at all, such as an alternative only the docs mention.

---

## 3. Output Format & Deliverables

Chat (always):

```markdown
**Verified against:** <sources, with versions>

| # | Claim | Verdict | Evidence | Effect |
|---|---|---|---|---|
| A | <claim> | ✅ Confirmed / ❌ Contradicted / ◐ Partial / ❔ Undocumented | <short quote> — [page#section](url) or [file:line](path#Lline) | Holds / Weakened: … / **Reopen**: … |

**Decisions to revisit:** <reopened decisions as questions with a recommendation, or "none">
**Proposed edits (after /proceed):** <exact changes to the plan, ADR or doc, or "none">
```

With `deep` or more than 10 claims, the artifact carries the full ledger, with one section per claim (claim, version, sources consulted, verbatim quotes, verdict, effect), and the chat shows only the contradicted, undocumented-and-load-bearing and reopened rows plus the artifact link.

---

## 4. Verification & Validation

- Every verdict cites a primary source (URL#section or `path:line`) or is explicitly **Undocumented** with the sources that were searched.
- Every **Contradicted** quote was re-fetched and confirmed by the main agent, not only by a sub-agent.
- The version the docs were checked against is stated.
- `git status` in every repo is unchanged, and no plan, ADR, glossary or settings file was edited.
