# PR Feedback Review Artifact Template

On-demand reference for [SKILL.md](../SKILL.md) › *Step 6 — Artifact Management & Output Format*.

```markdown
# PR Feedback Review: <PR Title>

> **PR:** [<Title>](<url>) (`<source>` → `<target>`)  
> **Counterpart:** [<repo> !<id>](<url>) @ `<short-sha>` — triaged / found, not triaged / expected but missing / single-repo change (`pr-counterpart` › *Classification*)  
> **Head reviewed:** `origin/<source>` @ `<short-sha>` (iteration <n>)  
> **Read from:** snapshot of `origin/<source>` @ `<short-sha>` (removed) / (kept at <path>) / live checkout of `<branch>`  
> **Local checkout:** on `<branch>` — same commit / local ahead <n> / behind <n> / PR branch not checked out  
> **Mode:** standard / deep  
> **Profile:** `<project>-profile` / none (*Project profile*)  
> **Status:** Active / Needs Attention — <votes>, <n> threads active, <n> resolved  
> **UI answers:** merged <date> — <a> accepted, <n> to rewrite from notes, <o> own, <s> skipped  <!-- optional, `--ui` merge only -->  
> **Reviewers:**  
> - **<Reviewer Name>:** `<Vote / Status>`

---

## Executive Summary & Triage Matrix

| Thread | PR | File | Reviewer | Vote | Category | State at head | Recommendation |
|---|---|---|---|---|---|---|---|
| [#106735](#thread-106735) ([devops](https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<prId>?discussionId=106735)) | Backend !18707 | PriisDbContext.cs | Nebojsa | 0 | 💡 Proposal: optimization | ⏸ Not addressed | Refactor cascade loop to Queue worklist |
| [#106740](#thread-106740) ([devops](…)) | Frontend !18708 | Foo.tsx | Daniel | −5 | ⛔ Blocking: bug | ✅ Fixed (`abc1234`) | Reply, resolve |

*State at head* is one of ✅ Fixed (commit) · ◐ Partial · ⏸ Not addressed · ↩ Superseded · ⚪ n/a, plus 🕓 Fixed, not pushed (`<sha>`) for a fix that exists only locally (e.g. under `/proceed`). ✅ means the fix is at the PR head. With a single PR in scope, drop the *PR* column.

---

## Detailed Thread Analysis & Actionable Solutions

### <a id="thread-<ThreadId>"></a>Thread [#<ThreadId>](https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<prId>?discussionId=<ThreadId>): <File / Topic Summary>
- **Author:** <Name> (<Timestamp>)
- **Status:** Active / Resolved (<date>, reply <comment id>) / Closed
- **UI decision:** accepted / adjusted from notes / own reply / skipped (<date>), with the user's adjust notes quoted under it  <!-- optional, `--ui` merge only -->
- **Location:** `[<file>:<line>]`
- **Selected code** (`<file>:<start>-<end>` @ `<short-sha>`, iteration <n>; omit for general threads):
  ```<lang>
  <the lines the reviewer selected, from selected-code.md>
  ```
- **Reviewer Comment:**
  > <Quote of reviewer's comment>

#### Technical Analysis
- **Core Concern:** <What the reviewer is pointing out>
- **State at head (iteration <n>):** <Addressed / partial / not — commit and `path:line` at head; the test that pins it>
- **Architectural Assessment:** <Is the reviewer right? Is the proposed fix right? How this fits the codebase, conventions, constraints>
- **Tradeoffs & Risks:** <Pros/cons of changing vs keeping as-is, downstream impact>

#### Concrete Code Solution
```diff
- old code
+ new code
```

#### Ready-to-Send Reply (in the PR's language)
> <Draft reply ready to copy-paste directly into the PR thread>

A reply skipped in `--ui` has the heading `#### Reply (skipped in --ui — not posted)`, and one waiting for a rewrite from notes `#### Reply (rewrite from --ui notes — not posted yet)`; `/pr-post-comments` only posts *Ready-to-Send Reply* blocks, so it is not posted. An own reply loses its `Voice pass: done` mark.

---

## Action Checklist & Next Steps
- [ ] Task 1
- [ ] Task 2
```
