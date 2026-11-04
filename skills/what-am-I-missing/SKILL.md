---
name: what-am-I-missing
description: 'Finds the single most important blind spot in an approach that is already chosen (a plan, design, fix or decision): the hidden assumption, edge case, failure mode or architectural consequence most likely to hurt, with its trigger, impact and fix. Answers in chat; `--deep`, or a call from /implement-feature, writes `<prefix>-what_am_i_missing-<suffix>.md`. Use for /what-am-I-missing, "what am I missing here?", "is there a hidden trap?", "sanity check this approach", "what could go wrong?".'
argument-hint: "[--deep] [<target>]"
---

# Skill: `/what-am-I-missing` — Blind Spot & Critical Omission Detector

Identifies the single most important blind spot, hidden invariant, or architectural risk in the user's current situation. Answers: _"What is the most important thing I'm missing here?"_ with technical depth, contextual awareness, and zero fluff.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: answers in chat by default; writes `<prefix>-what_am_i_missing-<suffix>.md` in the artifact dir (`artifact-protocol`) only under `--deep` or when called from `/implement-feature` Phase 2b (calls from `/code-review` Step 6c stay in chat mode and write no file)

On-demand references (`references/`):
- [`references/vectors.md`](references/vectors.md) — the 7 Universal Blindspot Vectors (including sibling-plan & library-source checks)
- [`references/artifact-template.md`](references/artifact-template.md) — structure for `<prefix>-what_am_i_missing-<suffix>.md` and embedded blind-spot sections

---

### When _not_ to use — pick the right neighbor

| Situation                                               | Use instead                                             |
| ------------------------------------------------------- | ------------------------------------------------------- |
| Full ground-truth research with options and a plan seed | [`/investigate`](../investigate/SKILL.md)               |
| Auditing a drafted implementation plan                  | [`/plan --review`](../plan/SKILL.md)               |
| Reviewing a diff                                        | [`/code-review`](../code-review/SKILL.md)               |
| Something is already failing                            | [`/problem`](../problem/SKILL.md)                       |
| Nothing is chosen yet; comparing approaches             | [`/suggestion`](../suggestion/SKILL.md)                 |
| Checking stated claims against official docs            | [`/verify-assumptions`](../verify-assumptions/SKILL.md) |

---

## 2. Universal Investigation Protocol

Read [`references/vectors.md`](references/vectors.md) and audit the user's current task, active file, recent diff, plan, or conversation context across all **7 Universal Blindspot Vectors** (Persistence/Outliving State, Concurrency/State Drift, Boundaries/Contracts, Security/Tenancy, Operational Realities/Performance, Testing Realities/Library Source, Leaky Abstractions/Profile Checks).

---

## 3. Output Format & Artifact Deliverable

| Invocation                                                                           | Output                                                                                                                                                                                                                    |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/what-am-I-missing [target]`, or a casual "what am I missing?"                      | **Chat only.** Compressed: the bold #1 sentence, _Trigger · Impact · Why it went unnoticed_ in three lines, up to two secondary blind spots in one line each, and the _Immediate Fix_. No file.                           |
| A call from `/code-review` _Step 6c_                                                 | **Chat mode, no file.** Return the #1 and up to two secondary blind spots _outside_ the findings the review passed in. The review verifies them and carries the result in its own artifact.                               |
| `/what-am-I-missing --deep [target]`, or a call from `/implement-feature` Phase 2b   | **Artifact.** Write `<prefix>-what_am_i_missing-<suffix>.md` in the artifact dir (`artifact-protocol`) using [`references/artifact-template.md`](references/artifact-template.md), plus the chat summary below.                           |

**Report Back in Chat** (artifact mode):
- The bold **#1 Most Important Thing You Are Missing** takeaway sentence.
- The `artifact-protocol` › _Chat link block_ linking the artifact and its `Blast Radius / Failure Scenario`, `Secondary Blind Spots & Nuances`, and `Actionable Recommendation` sections (real line numbers from `grep -n`).
- A concise overview of the core failure scenario and actionable fix.
