---
name: spec-verification
description: "Verifies implementation completeness against functional specifications, user story acceptance criteria, or PR descriptions. Produces a traceability matrix mapping each requirement to line-level code evidence, grading status (implemented, partial, missing, deviated)."
---

# Skill: `/spec-verification` — Requirement-by-Requirement Traceability

Takes a specification and an implementation and answers, for every line of the spec, *is it there, where, and exactly as written?* The output is a traceability table with evidence links, a list of behaviour the code adds beyond the spec, and the decisions product must still take. It is the Spec axis of `/code-review` run to completion on its own: the review samples requirements to find defects; this skill walks all of them to establish coverage.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-spec_verification-<suffix>.md` (suffix `<workItemId>-<slug>`, e.g. `-30758-control-tickets`), created through *Claim*. It updates only an artifact this session owns (rule 3); otherwise a re-run writes a new one
- `../_modules/pr-counterpart.md`
- `../_modules/pr-host.md`

> [!CAUTION]
> **ABSOLUTE RULES — ZERO TOLERANCE FOR DEVIATION:**
> 1. **MANDATORY .MD ARTIFACT & SUMMARY:** every `/spec-verification` response writes or updates the artifact and begins with a clickable link to it plus section anchors (see *Output*).
> 2. **READ-ONLY:** never edit code, check out, stash, pull, install, build or run tests. When the PR head has moved past the local tree, read the new head from the remote ref (`git show origin/<branch>:<path>`); never `git checkout` or `git pull` on the user's behalf.
> 3. **NO GRADE WITHOUT EVIDENCE:** every ✅/◐/❌/⚠ row cites a `path:line` you re-opened at the reviewed head. A sub-agent's or an earlier review's claim is evidence to check, not a verdict.
> 4. **DO NOT AUTO-PROCEED:** never start implementing the gaps. Report and stop.

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

Accept, in order of preference:

1. **Work item URL or id** (`https://dev.azure.com/{org}/{project}/_workitems/edit/{id}`, `https://{org}.visualstudio.com/{project}/_workitems/edit/{id}`, `#30758`, GitHub/GitLab issue URL).
2. **PR URL/id or branch** → its linked work item(s) (`az repos pr work-item list`, `gh pr view --json body`), then **walk up to the parent story**: a PR's task usually says "implement per #parent"; the parent holds the spec.
3. **A spec/plan file or pasted text.**

Fetch the full item, not just the description:

```bash
az boards work-item show --id <id> --org <org-url> --expand all -o json   # fields + relations
# fields of interest: System.Description, Microsoft.VSTS.Common.AcceptanceCriteria, System.Rev, System.ChangedDate
```

- **`--org`**: the form the workspace already uses (`pr-host` › *Organization URL*). Fetching the item and stripping its HTML follow `pr-host` › *Fetch the PR, its work items and acceptance criteria*; what is specific here is below.
- **Strip HTML** before quoting (`<li>` → `- `, `<br>`/`</p>` → newline, drop tags, unescape entities).
- Record the **revision and last-changed date** in the header: a spec that changed after the branch was cut explains "drift" findings.
- **Follow every relation** (`System.LinkTypes.Hierarchy-Reverse` parent, `Hierarchy-Forward` children, `Related`, `Dependency-Forward` successor). Fetch each one's title, type, state and first lines of description. This is how you tell *deferred* from *missing*: a child task "PDF-export (broken out)" or a successor story "Rapport …" moves those spec lines to ↗, and a related bug may already name a known gap.
- **Discussion comments** often carry product decisions. Try `az devops invoke --area wit --resource comments --route-parameters project=<p> workItemId=<id> --api-version 7.1-preview.4`; the CLI may reject preview versions (*"could not convert string to float"*) and `az rest` may answer with a sign-in page. If both fail, **say so in the header** instead of pretending the description is the whole spec.
- **Wiki plan pages** referenced by the item (e.g. `/<WikiSection>/<page>`): `az devops wiki page show --wiki <name> --path "<path>" --include-content`; an empty `content` means not readable — say so.
- **PR descriptions** are the *authors'* statement of intent, not the spec. Keep them as a separate column of evidence: where PR text and story disagree, the story wins for grading and the disagreement is itself a row (⚠ or ❔).

### Step 2: Pin the implementation

```bash
git -C <repo> fetch -q origin
git -C <repo> rev-parse --short HEAD origin/<branch>        # local vs remote head
git -C <repo> status --short | wc -l                        # dirty?
```

- Verify against the **PR head on the remote**, and state whether the local tree equals it. If local is behind, read changed files with `git show "origin/<branch>:<path>"` (quote or brace the ref — zsh treats `$B:source/...` and `$B:tests/...` as history modifiers).
- **Counterpart PRs:** whatever the input (story, PR URL, branch), run the counterpart lookup in `pr-counterpart` › *Counterpart discovery* and pin every PR it finds. A story is usually implemented by sibling tasks in different repos, each with its own PR, so starting from one PR link finds only half the evidence. A requirement graded against one half is never ✅ when the other half owns part of it. Record the classification in the artifact's *Context*. An *expected but missing* half grades the lines it owns as ✗ or ↗ (with the owning item id), never as ✅.
- In a **multi-repo workspace**, resolve the PR for every repo (`pr-host` › *Resolve the PR from a branch*) and verify both halves: a field limit is a backend constant *and* a frontend schema rule *and* a column length; a select's option list is a backend enum *and* a frontend facade.

### Step 3: Decompose the spec into atomic lines

Turn prose into one row per checkable claim, numbered by section (A1…, B1…, C1…). Typical sections:

- **A. Behaviour** — lifecycle (create / save-and-return / close), who may do what, notifications and their content, time windows, guards ("must not X while Y"), list columns, search fields, filters, "mine / all" splits, visibility per persona, hide/show rules.
- **B/C. Fields** — one row per field: label, required/optional, control type (select / multiselect / datepicker / textarea), **every option value**, **every max length**, defaults, derivation ("fetched automatically from …").
- **Deferred markers** — lines the spec itself tags (*"later"*, *"nice to have"*, *"a later user story"*, or the same words in the spec's own language) or that a linked child/successor owns. Keep them as rows graded ↗ with the owning item id; do not drop them.
- **Self-contradictions** — when two sentences of the spec disagree (e.g. "must not see status" followed by "sees number, reason, handler, status"), make one ❔ row that quotes both, states what the code does, and asks product to pick. Never silently choose a side.

### Step 4: Grade every line against the code

For each row, find the evidence in **every layer that enforces it** and open it at the reviewed head:

| Claim type | Where to look |
|---|---|
| Option list / label | backend enum `[Display(Name)]` members; frontend enum facade / `…Names` map; the control that renders it (combobox / radio / multiselect) |
| Max length / required | the backend's field-limit constants + request validator + entity config; frontend schema (`zod`/`yup`) + generated constants; the DB column |
| Date rule ("today or future") | backend domain rule with time zone; frontend `minDate` + schema; what happens to an unchanged stored past date on edit |
| Permission / visibility | role → action grants; endpoint policies; per-row predicates; the restricted DTO's field list (what is *absent* matters) |
| List column / filter / search | the list endpoint's projection, its filter / predicate builder, the request record; the frontend column definitions and filter bar |
| Lifecycle rule | the aggregate method (`Close`, `Update`, …) and its tests; the endpoint that calls it; guards in sibling endpoints that bypass the aggregate (raw SQL cascades, bulk updates) |
| Notification content | the notification sender's content builder: which facts/notes are included, which roles receive it, and under which condition |
| Hide-when-empty / UI rules | the component and the helper it uses; whether the rule is per field or per section |

Grade with this legend and nothing else:

| Grade | Meaning |
|---|---|
| ✅ | implemented as written (quote the matching value/label when it is a literal) |
| ◐ | partial — part of the sentence is there, part is not; say which part |
| ❌ | missing — nothing in either repo; and not owned by a linked item |
| ↗ `#id` | deferred to a linked child/successor/related item, or tagged later/optional by the spec itself |
| ⚠ | deviates — implemented differently from the wording; say whether the PR text calls it deliberate |
| ❔ | product decision needed — spec is contradictory or ambiguous and the code picked one reading |

Rules of grading:
- A spec that asks to **"make room for"** something (a column, an enum slot) is ✅ when the storage exists even if nothing exposes it.
- "**Required**" that the code enforces at a later step (e.g. required to *close* but optional to *save*) is ⚠, not ❌, when the spec also demands save-and-return; explain why both cannot hold literally.
- A **wider audience than specified** (notify all managers instead of the chosen one) is ◐, not ✅.
- An **extra filter or column** the spec did not ask for is not a defect; mention it inline as "extra, harmless" and list it in *Beyond the spec* only if it changes behaviour.
- Never grade from the PR description, a commit message, a sub-agent summary, or an earlier review. Re-open the line.

### Step 5: Beyond the spec

List behaviour present in the diff that no spec line asks for (guards, cascades, uniqueness rules, irreversibility, moderation paths, side effects on other features, new concepts such as a coarse status). For each: where, and whether a PR description announces it. This is what the acceptance test must cover and what product must accept explicitly.

### Step 6: Decisions needed

Collect every ❔, every ◐ whose completion depends on a product choice, and every ❌ whose absence might be intentional (e.g. a filter on a dimension the entity does not have). Phrase each as the two or three concrete options, with what each costs.

### Step 7: Cross-reference, do not duplicate

- If a `<prefix>-code_review-<suffix>.md` for the same PR exists from **your own model**, reference its Spec findings instead of restating them — and **every such reference is a link to the finding's anchor in that file**, never bare text: `→ [finding 9](<prefix>-code_review-<suffix>.md#finding-9)`. The code-review artifact places `<a id="finding-N"></a>` before each finding, so the relative `file.md#finding-N` form resolves in Markdown preview from the workspace root; a range is written `[findings 8–10](…#finding-8)`. Do not read other models' artifacts unless the user asks for a comparison.
- **Renumbering hazard:** a code-review refresh that drops a finding renumbers the rest. After any refresh of the review, re-read its `### 🟡 N —` headings and fix both the number and the anchor of every reference here (`grep -n -o "finding[s]* [0-9–-]*[0-9]"` finds them). A link to the wrong anchor is worse than no link.
- If reviewer threads exist on the PR (see `/pr-feedback-review` Step 2 for the fetch), mark rows an active thread already covers with the thread id, so the user does not raise the same point twice.

### Deep mode (`/spec-verification deep`)

For long specs (> ~40 lines) or two-repo features, run Steps 3–5 in parallel sub-agents — one per spec section (behaviour / field group A / field group B / beyond-spec) — each given the decomposed rows for its section, the repo paths, the head SHAs and the read-only rule, and each returning rows with proposed grades and `path:line`. Then **re-open every cited line yourself** before writing the grade. Sub-agent output is evidence, not a verdict; the first-pass agent in the originating run misread two enum labels and over-graded a "make room for" line as ❌.

---

## 3. Output Format & Deliverables

### Artifact `<prefix>-spec_verification-<suffix>.md`

```markdown
# Spec Verification — <Spec title/id> vs <PR(s)/branch>

## Context
| Story | <link> — type, state, revision N (last changed <date>). AC field present / absent; description used. |
| Parent / children | … (which child owns which deferred lines) |
| Related / successor | … |
| Code verified | <repo> `<branch>` @ <sha> (= PR head; local tree equal / N behind, read from remote) … |
| Not available | discussion comments / wiki page / … and why |

**Legend:** ✅ · ◐ · ❌ · ↗ · ⚠ · ❔ (one line)
**Result:** <N> spec lines — **<n> ✅ · <n> ◐ · <n> ❌ · <n> ↗ · <n> ⚠ · <n> ❔**. <One sentence: nothing silently wrong / the gaps are X, Y, Z.>

## A. Behaviour
| # | Spec says (short quote, spec language) | Status | Evidence (clickable path:line, both repos) |

## B. <Field group>
## C. <Field group>
(one row per field: control, options, limit — cite the constant, the validator, the schema)

## D. In the code but not in the spec
- bullets with where + "announced in PR text? yes/no"

## Decisions needed before the story can close
1. … (options with cost)
```

Rows cite files as `[File.cs:42](<workspace-relative path>#L42)` under Claude Code and `file://` absolute under Antigravity, per the `artifact-protocol`. References to another artifact's section or finding (`code_review`, `pr_feedback_review`, `implementation_plan`) are links to that file's HTML anchor (`other.md#finding-9`, `other.md#thread-110409`), so a reader can jump between the two documents. Quote spec lines in the spec's language; write the rest in the review language. Keep each Evidence cell to the proof, not a narrative.

### Chat response

Begin with the artifact link and anchors (read the line numbers off the written file with `grep -n '^## '`):

```markdown
📄 **[<prefix>-spec_verification-<suffix>.md](<prefix>-spec_verification-<suffix>.md)**

Key Sections:
- 📄 [Context](…#L3): what was used and what could not be read
- 📄 [A. Behaviour](…#L19), [B. …](…#L47), [C. …](…#L68): one row per spec line
- 📄 [D. Beyond the spec](…#L93) and [Decisions needed](…#L106)
```

Then, in prose: the verdict and totals in one or two sentences; the ❌/◐/❔ rows in a short list (these are what the reader acts on); the ↗ rows as "deferred to #…" in one line; any source you could not read and what pasting it would unlock. Nothing else — the table carries the rest.

---

## 4. Verification & Validation

Before sending:

1. **Recount the totals** from the table (count rows per grade with a script, not by eye); the originating run shipped a wrong total once.
2. **Re-open every cited `path:line`** at the stated head. If the head moved since you read a file (`git rev-parse origin/<branch>` differs from the header), re-point the lines using `git show "origin/<branch>:<path>" | grep -n …` and state the new head in *Context* — never check out to do it.
3. **Every ❌ names what was searched** (request record, filter bar, DTO) so a reader can confirm the absence.
4. **Every ↗ names the owning item id**; a deferred row with no owner is a ❌.
5. **Every ❔ quotes both readings** of the spec.
6. **Re-run on request** ("check again", "refresh after the new commits"): in the same session, update this session's artifact; in a new session, write a new one through *Claim* and carry the earlier one's rows over. Either way, diff the heads, re-grade only the rows whose files changed, update *Context* with the new SHAs and what changed, and keep the row numbering stable so earlier references ("→ A12") still resolve.
