---
name: spec-verification
description: "Verifies implementation completeness against functional specifications, user story acceptance criteria, or PR descriptions. Produces a traceability matrix mapping each requirement to line-level code evidence, grading status (implemented, partial, missing, deviated)."
argument-hint: "[--deep] [<spec-source>]"
---

# Skill: `/spec-verification` — Requirement-by-Requirement Traceability

Walks every line of a specification against the implementation to produce a requirement-by-requirement traceability matrix (`<prefix>-spec_verification-<suffix>.md`) with line-level evidence, unannounced behaviour (*Beyond the spec*), and open product decisions.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-spec_verification-<suffix>.md` (suffix `<workItemId>-<slug>`)
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`
- `../_modules/fan-out.md`

> [!CAUTION]
> 1. **Mandatory artifact & summary**: publish via `artifact-protocol` › *Claim* and open chat with the `artifact-protocol` › *Chat link block*.
> 2. **Read-only**: never edit code, check out, stash, pull, install, build, or run tests (`core` › *The `/proceed` gate*). When the remote PR head is ahead of the local tree, read via `git show "origin/<branch>:<path>"`.
> 3. **No grade without evidence**: every `✅`/`◐`/`❌`/`⚠` row cites a `path:line` re-opened at the reviewed head.

---

## 1. When to Use

| Situation | Use instead |
|---|---|
| Finding bugs and convention breaches in the diff | [`/code-review`](../code-review/SKILL.md) (its Spec axis samples; this skill walks every line) |
| Triaging reviewer threads on the PR | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| Auditing a plan before it is built | [`/plan --review`](../plan/SKILL.md) |
| How to try the change by hand | [`/manual-testing`](../manual-testing/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1: Resolve the spec source

Accept in order: (1) work-item URL/ID, (2) PR URL/ID or branch → linked work item(s) and **parent story**, (3) spec/plan file or pasted text.
Fetch the full item, relations, discussion comments, and referenced wiki pages per `pr-host` › *Fetch the PR, its work items and acceptance criteria*:
- Record `System.Rev` and `System.ChangedDate` in *Context* to detect post-branch spec drift.
- Follow `Hierarchy-Reverse` (parent), `Hierarchy-Forward` (children), `Related`, and `Dependency-Forward` (successor) relations to distinguish **deferred** (`↗ #id`) from **missing** (`❌`).
- If discussion comments or a linked wiki page (`az devops wiki page show --wiki <name> --path "<path>" --include-content`) cannot be read, state that in *Context* › **Not available**.
- Treat PR descriptions as author intent, not the spec: where PR text and story disagree, grade against the story and record the disagreement (`⚠` or `❔`).

### Step 2: Pin the implementation

```bash
git -C <repo> fetch -q origin
git -C <repo> rev-parse --short HEAD origin/<branch>
git -C <repo> status --short | wc -l
```

- Verify against the remote PR head (reading `"origin/<branch>:<path>"` when local is behind).
- **Counterpart PRs**: run `pr-counterpart` › *Counterpart discovery* (and `pr-host` › *Resolve the PR from a branch* across repos). A requirement spanning two repos is never `✅` from one half alone; an *expected but missing* half grades its requirements `❌` or `↗ #id`.

### Step 3: Decompose the spec into atomic lines

Turn prose into one row per checkable claim, numbered by section (`A1…`, `B1…`, `C1…`):
- **A. Behaviour**: lifecycle, permissions/roles, notifications, time windows, guards, list columns, search/filter rules, persona visibility.
- **B/C. Fields**: one row per field — label, required/optional, control type, **every option value**, **every max length**, defaults, derivation.
- **Deferred markers**: lines tagged *"later"* / *"nice to have"* or owned by a linked child/successor → keep as `↗ #id`.
- **Self-contradictions**: when two spec sentences conflict, create a `❔` row quoting both and stating what the code does.

### Step 4: Grade every line against the code

Check **every layer that enforces the claim** at the reviewed head:

| Claim type | Where to look |
|---|---|
| Option list / label | Backend enum `[Display(Name)]`; frontend enum facade / `…Names` map; UI control |
| Max length / required | Backend field-limit constants + validator + EF config; frontend `zod`/`yup` schema + generated constants; DB column |
| Date rule | Backend domain rule + time zone; frontend `minDate` + schema; edit behavior on stored past dates |
| Permission / visibility | Role grants, endpoint policies, row predicates, restricted DTO fields |
| List column / filter / search | Endpoint projection, filter builder, request DTO; frontend columns and filter bar |
| Lifecycle / notifications / UI rules | Aggregate methods + sibling endpoints bypassing the aggregate; notification builder; hide-when-empty helpers |

| Grade | Meaning |
|---|---|
| `✅` | Implemented as written (quote matching literal value/label) |
| `◐` | Partial — state which part is present and which is missing (e.g. wider audience than specified) |
| `❌` | Missing in both repos and not owned by a linked item |
| `↗ #id` | Deferred to a linked child/successor/related item or marked optional in the spec |
| `⚠` | Deviates from wording (e.g. required on close instead of save to allow save-and-return); state if deliberate |
| `❔` | Product decision needed — spec is ambiguous or contradictory |

### Step 5: Beyond the spec & Step 6: Decisions needed

- **D. Beyond the spec**: list unannounced behaviour in the diff (guards, cascades, uniqueness rules, side effects) with `path:line` and whether the PR description mentions it.
- **Decisions needed**: collect every `❔`, choice-dependent `◐`, and potentially intentional `❌` with 2–3 concrete options and their cost.

### Step 7: Cross-reference, do not duplicate

- Follow the `artifact-protocol` › *Claim* › *Independence rule* (do not read other models' reviews unless asked). If a `<prefix>-code_review-<suffix>.md` from your own model exists, link its `#finding-N` anchors (`→ [finding 9](<prefix>-code_review-<suffix>.md#finding-9)`) and verify anchor numbers after any review refresh.
- If PR threads exist (`pr-host` › *Fetch discussion threads*), tag covered rows with the thread ID.

### Deep mode (`/spec-verification --deep`)

For long specs (> ~40 lines) or dual-repo features, fan out Steps 3–5 across parallel read-only sub-agents per spec section (`fan-out` › *Brief contract*), then re-open every cited `path:line` yourself (`fan-out` › *Aggregation*).

---

## 3. Output Format & Deliverables

1. Publish `<prefix>-spec_verification-<suffix>.md` in the artifact dir (`artifact-protocol`) via `artifact-protocol` › *Claim*, following [artifact-template.md](references/artifact-template.md).
2. In chat, emit the `artifact-protocol` › *Chat link block*, followed by the one-sentence verdict and grade counts, the `❌`/`◐`/`❔` items, the `↗` deferred summary, any unreadable spec sources, and the closing gate line (`core` › *The `/proceed` gate*).

---

## 4. Verification & Validation

1. **Recount totals** from the table via script so the summary line matches the rows.
2. **Re-open every cited `path:line`** at the pinned head.
3. **Every `❌` names what was searched**; every `↗` names its `#id`; every `❔` quotes both readings.
4. **Refresh runs** keep row numbering (`A1…`) stable and re-grade only rows whose files or spec lines changed.
