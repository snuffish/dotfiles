# Skill-review report template

On-demand reference for [`SKILL.md`](../SKILL.md) step 6. Fill every section; delete none. A PR target changes the header (see *Rules*).

````markdown
<!-- artifact-owner: <host>-<model> · session <session-id> · created <ISO-8601 timestamp> -->

# Skill review: `<skill>` on `<branch>` @ `<sha>`

**Scope:** <skill files reviewed; other skills only where a fix lands in them>.
**Inputs merged:** <reviews, handoffs, threads, with finding ranges>, or "none".
**Standard:** `writing-for-agents` + `SKILL-MECHANICS.md`, plus <profile checks>.
**Method:** <what was re-read at which ref; `git show` source heads; no edits, no evals, no subagents, no drift run>.
**Change scope (<who>, <date>):** <where fixes may land>.

Status key: **confirmed** (true at HEAD) · **latent** (true at HEAD, wrong once a source PR merges) · **stale** (already fixed) · **wrong** (the finding or its proposed fix does not hold).

---

## Fixes, in the order to apply them

### <Group: Load points and mechanics (first)>

**1. <Finding title>** (<source>). <Status and the evidence, with `path:line` at the ref>. Fix: <the edit, one place>.

### <Group: Claims that are wrong or will go wrong>
### <Group: Triggers>
### <Group: Structure and accuracy, minor>
### Later
### Drop

**<n>. <Finding>** (<source>). **Wrong.** <What breaks, with the consumer's `path:line`>.

### Checked, no finding

- **<Lens>:** <what was checked and that it held>.

## Verification

1. <Command per fix class; the strict YAML parse, the drift run, the re-extract, the anchor check, the body size against the budget, a grep for text the repo forbids>.

## Decisions

| # | Question | Decision or **Rec** |
|---|---|---|

## Triage matrix

| # | Source | File | Severity | Status at HEAD | Effort | Decision |
|---|---|---|---|---|---|---|
````

Rules:

- Severity is **Should fix** or **Minor**; effort is S, M or L; decision is `now`, `later` or `drop` (`later` names its trigger).
- Source is the input's id (`input 4`, `handoff 2`), `new (<lens>)`, or `plan review` for step 5 findings.
- One matrix row per fix number, in application order; a number added late keeps its number.
- Add a **Posted to PR** line only when `/pr-post-comments` records it.
- PR target: the title reads `# Skill review: PR !<id> <title> @ <head sha>`; **Scope** lists each target with its kind and adds **Out of scope:** the changed files left to `/code-review`; one `###` group per target inside each fix group; status key reads "at the PR head".
