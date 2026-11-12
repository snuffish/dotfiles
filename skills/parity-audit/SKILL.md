---
name: parity-audit
description: "Audits a migration or rewrite for behavioural parity: each unit (job, handler, endpoint) on the new ref against its old version, per dimension (schedule, concurrency, retries, tx and publish order, DI scope, failures, tracing), plus cross-unit overlap and a local runtime proof, with library behaviour read from decompiled packages. Writes `<prefix>-parity_audit-<suffix>.md`. Use for /parity-audit, \"parity audit\", \"does the new X behave like the old Y?\". Not for a diff review (use /code-review) or fact-checking a plan (use /verify-assumptions)."
argument-hint: "<old-ref> <new-ref> [scope] [--no-proof]"
---

# Skill: `/parity-audit` — Old-vs-new behavioural parity audit

Compares each unit of a migrated subsystem with its pre-migration version, judges every difference as intended, regression or unclear, and proves the risky ones at runtime. Reading the libraries' code instead of their docs has reversed a main finding before; see [`references/lessons.md`](references/lessons.md).

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`; the only writes are the artifact and test data the user approves in Step 6
- `../_modules/artifact-protocol.md`: writes `<prefix>-parity_audit-<suffix>.md`
- `../_modules/project-profile.md`: loads `<project>-profile`, then `parity-audit-<project>-profile`
- `../_modules/fan-out.md`: discovery and verify lanes

On-demand references (`references/`):
- [`references/report-template.md`](references/report-template.md): the artifact's sections, at Step 7
- [`references/lessons.md`](references/lessons.md): traps that hid or faked findings in earlier audits; read before Step 2 and again before Step 6

Rules:
- **Agent budget: at most 5 sub-agents in the whole run**: up to 3 discovery lanes and up to 2 verifiers. The runtime proof stays in the main thread.
- **Independent first.** Draft every finding before reading earlier artifacts on the same PR or subsystem (`artifact-protocol` › *Independence rule*), then compare them in the report's last section.
- **No outward writes.** No code edits, PR comments, tracker changes or edits to other plans. Name a fix; don't apply it.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Review a diff for bugs and conventions | [`/code-review`](../code-review/SKILL.md) |
| Fact-check the claims in a plan, ADR or doc | [`/verify-assumptions`](../verify-assumptions/SKILL.md) |
| Check the code against acceptance criteria | [`/spec-verification`](../spec-verification/SKILL.md) |
| One unit, one question ("does job X still retry?") | Answer inline; no audit needed |

---

## 2. Core Protocol & Workflow

### Step 1: Scope

Resolve before spawning anything. Write the result to `<scratchpad>/parity-scope.md` (the lanes and verifiers read it) and restate it in the artifact header:

1. **Refs.**
   - Find the branch's PR with the base profile's *PR tooling* and record its id and target; with no PR, the target is `origin/HEAD` and the suffix drops `<pr>`.
   - `git fetch origin <target>` first, so the merge-base is not computed against a stale ref.
   - Old = the merge-base of the branch with its PR target, unless the user names one (`git merge-base origin/<target> HEAD`).
   - New = the user's new ref, else HEAD; record the short sha. With an explicit new ref, read new code with `git show <new>:<path>` as well, and find the PR from the branch that contains it (`git branch -r --contains <new>`).
   - Old code is read with `git show <old>:<path>`, never by checking out.
2. **Units.**
   - List them at both refs (`git ls-files` / `git ls-tree -r --name-only <old>`).
   - Map each new unit to its old one; renames and moves count as the same unit.
   - Say how many units exist at each ref. A unit added or dropped is a row of its own.
   - **Narrowed scope** ("only the Register jobs"): restate the paths and unit kinds it covers, using the profile's *Scope → paths* row. When two readings differ by more than one unit, ask before Step 2.
   - The cross-unit section still compares in-scope units with every unit at the ref (read-only), since an out-of-scope job can write the same tables.
3. **Shared wiring.** Registration, host setup, options and base classes that every unit inherits. Check them once in a *Shared wiring* block (S1, S2, …), so per-unit rows can cite `S3` instead of repeating it. Each S row needs anchors at both refs: wiring often moves files in a migration, and that move can be a finding.
4. **Dimensions.** Use the user's list, else these defaults: schedule + time zone; misfire / catch-up / concurrency; retries; transaction and event-publish order; DI scope and current user; failure handling; tracing; tables written and run window (for the cross-unit section, returned as a separate list, not as rows).
5. **Profile.** Load the base `<project>-profile` (report language, PR tooling), then `parity-audit-<project>-profile` when its gate matches (`project-profile` › *Discovery*): units, scope paths, lane split, local-stack recipes, proof queries.
6. **Earlier-work list.** Match file names only (`*<pr>*`, `*<work item>*`, `*<subsystem>*`, any extension), plus the profile's extra patterns. List them; do not open them yet.

### Step 2: Discovery (≤3 Explore lanes)

This Command always fans out; it has no bare mode. Discovery lanes are `Explore` agents, verifiers `general-purpose`.

- **Split.** One lane per feature area; use the profile's split when it has one. Drop the profile lanes outside the scope; with 12 units or fewer, split by unit kind (e.g. cron vs event) instead. Every lane reads the shared wiring at both refs.
- **Brief.** Include the *Brief contract* from `fan-out`, plus:
  - the refs;
  - the one-command-per-call shell rule;
  - "return rows `unit | dimension | old (path:line@old) | new (path:line@new) | delta`";
  - "also return a separate `unit | tables written | run window` list";
  - "end with a *Could not determine* list".
- **Save the rows.** Write the lanes' rows to `<scratchpad>/parity-rows.md`: the verifiers read that file, so they are not re-briefed from the conversation.

### Step 3: Settle library behaviour from code

Every *Could not determine* row that hangs on a framework (old or new) is settled from its package, not from memory or docs:

- Find the exact package version (`Directory.Packages.props`, `package.json`, lockfile).
- Decompile or read the source from the local cache (`~/.nuget/packages/<id>/<version>`, `node_modules/<pkg>`). For .NET use `ilspycmd -p -o <scratchpad>/<pkg>src <dll>`.
- Cite the decompiled `File.cs:line`. When the code and the XML docs disagree, the code wins, and say so in the row.

Verifier A does this step: list the open questions in its brief, with the package ids and versions. Decompiling writes files, so its brief makes one exception to *Make no file edits*: it may write only under `<scratchpad>/<pkg>src`. Explore lanes have no Write tool and never decompile. With no Verifier A, the lead does it.

### Step 4: Verify (≤2 general-purpose lanes)

- **Split.**
  - Verifier A: per-unit rows plus the library answers they need.
  - Verifier B: shared wiring, infrastructure, the cross-unit section, and the main-thread observations from Step 5. Spawn B after Step 5's first read, or send the observations later with `SendMessage`; with `--no-proof` it gets none.
- **Ask for:**
  - every `path:line` re-checked at both refs, with corrections;
  - a verdict per row: `intended`, `regression` (with a concrete failure scenario) or `unclear` (with the missing evidence);
  - idempotency of each unit when it runs twice;
  - unit pairs that write the same tables within ±30 min, out-of-scope units included.
- **Lead.**
  - Re-open each load-bearing citation (`fan-out` › *Aggregation*).
  - Recount every number you will print (unit counts, "N daily jobs").
  - Merge corrections into the rows.

### Step 5: Observe the runtime state early

`--no-proof` skips Steps 5 and 6: no local stack. Say so in *Runtime proof*.

- While Verifier A runs, start the local stack and read the persisted scheduler or queue state: trigger start and next-fire times, fired and execution history, node and check-in rows.
- Compare it with what the docs and the rows claim. A start time that equals the last node start, or a job with no history after a downtime window, is a finding to hand to Verifier B. Don't wait for the proof step.

### Step 6: Runtime proof (main thread)

Skipped with `--no-proof` (see Step 5). The profile has the project recipes.

1. **Second instance with its own identity.** Instance ids are often `{MachineName}-{role}`. Two processes on one host then share an id, which is a different scenario, not the production one. Run the second instance in a container with its own hostname, and the same-id case separately when it matters.
2. **Count from persisted history, per time bucket and instance**: fires per minute, rows created per source row, failures. Never count from logs alone.
3. **Check that the proof has data.**
   - A job whose source table is empty or missing proves timing only, not effect. Write it that way in the report.
   - Seeding test data is a write: show the seed, a snapshot query and the restore, and run it only after the user approves (the project's write scripts gate this).
   - Record the baseline first, and assert one-to-one (source rows = created rows = distinct keys).
4. **Clean up.**
   - Restore the seeded data and re-run the baseline query.
   - Stop and remove the extra instances.
   - Say what is still running.

### Step 7: Report

Write the artifact from [`references/report-template.md`](references/report-template.md), then:

1. Open the earlier artifacts listed in Step 1.6, `grep` them for the topics of your findings, and add *Compared with earlier work*: what they got right, what this audit contradicts (and why), and which findings are new. A decision recorded there (a product call, a resolved thread) beats your open question; say so instead of reopening it.
2. Compare each proposed fix with any plan the user names (Open Questions, a premise the findings overturn) in the cross-unit section. Don't edit the plan.
3. Record a work-state item with the artifact as `work_product`.

---

## 3. Output Format & Deliverables

- **Artifact:** `<prefix>-parity_audit-<suffix>.md` (suffix: `<pr>-<subsystem>`), structured as in [`references/report-template.md`](references/report-template.md).
- **Chat:** the verdict in a few lines: what is the same, what is better, the ranked findings with their fixes, what the proof showed and its limits, and the artifact path alone in a code block. End with one next-step line naming who applies each fix; this Command applies none, so there is nothing to `/proceed` here.

---

## 4. Verification & Validation

- Every row cites `path:line` on both refs, and every library claim cites decompiled source.
- Every number in the report was recounted in Step 4.
- The proof section states for each test what it proves and what it does not (timing vs effect, serialised vs concurrent).
- Seeded data is restored, with the baseline query re-run and its output shown.
