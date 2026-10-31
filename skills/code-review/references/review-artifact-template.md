# Code Review Artifact Template & Structure

On-demand reference for [SKILL.md](../SKILL.md) › *Step 7 — Artifact & Output Format*.

---

## Artifact Structure

Sections in this order, and **nothing after In Plain Terms**:

1. `## Review Context` — a markdown table with these rows:
   | Field | Content |
   | --- | --- |
   | **PR / Work Item** | Per repo: PR link/ID and linked work item(s) |
   | **Counterpart** | `pr-counterpart` › *Classification*: `<repo> !<id>` reviewed / found, not reviewed / expected but missing / single-repo change |
   | **Base & Head reviewed** | Base ref + per-repo `` `<source-ref>` @ `<short-sha>` `` (never a bare SHA) |
   | **Reviewed from** | ``snapshot of `<source-ref>` @ `<short-sha>` (removed)`` / `(kept at <path>)` / ``live checkout of `<branch>` `` |
   | **Local checkout** | Per repo: branch and `same commit` / `local ahead N / behind M` / `on <other-branch> — PR branch not checked out` (plus `contract read at <default> @ <short-sha>` when applicable) |
   | **Untracked, not in snapshot** | `working` / `staged` scopes only: file list or `none` |
   | **Spec & Standards sources** | Spec source (or `none available — Spec axis limited to unannounced behaviour`) + Standards files loaded |
   | **Profile** | Loaded profiles, each upstream checklist/catalog as `<repo> origin/<default> @ <short-sha>`, and any missing heading (`none` without a profile) |
   | **Mode & Blind-spot pass** | `standard` / `deep` (+ `feedback`); blind-spot outcome (`finding N` / `covered by finding N` / `refuted: <evidence>`) |
   | **PR feedback** *(`feedback` only)* | Link to `pr_feedback_review` artifact(s), human thread count, attached count, and added-finding count (or why skipped) |
2. `## Feature in Brief` — what is being built and why, in domain terms (3–5 sentences covering **Who**, **The problem**, **The outcome**, **Where it sits**; drawn from the Step 2 spec source, or marked *"_Inferred from the diff — no description or work item available._"*).
3. `## Summary of Changes` — 1–3 sentences on what the changes accomplish and their architectural intent.
4. `## Findings Summary` — the summary table below. With `feedback`, add a **Thread** column (`[#110776](#thread-110776)` + host link, or `—`) and follow with `### PR Feedback Cross-Check` (one row per human thread: _Thread_, _State at head_, _Disposition_).
5. `## Detailed Review Findings` — 🔴/🟡 findings with inline fixes, then `### 🟢 Minor Findings` (cap at 8, `+N more` after), then any profile _Report additions_ subsections, then `### 💙 Praise` (1–3 bullets).
6. `## In Plain Terms` — required whenever there is at least one 🔴/🟡 (omit when none).

---

## Findings Summary Table & Anchors

| # | Severity | Axis | File | Issue |
| --- | --- | --- | --- | --- |
| [1](#finding-1) · [plain](#finding-1-plain) | 🔴 | Correctness | `foo.ts` | Missing null check on `userId` |
| [2](#finding-2) · [plain](#finding-2-plain) | 🟡 | Spec | `bar.tsx` | AC "per category" not implemented |
| [3](#finding-3) · [plain](#finding-3-plain) | 🟡 | Standards | `Baz.cs` | Read query tracks entities (use `AsNoTracking`) |
| 4–7 | 🟢 | various | various | Polish — see [Minor Findings](#minor-findings) |

- **Intra-document anchors**: precede each 🔴/🟡 finding with `<a id="finding-N"></a>`, each plain-terms entry with `<a id="finding-N-plain"></a>`, and minor findings with `<a id="minor-findings"></a>`. Never use `#L<line>` for intra-document links.
- **In-review source file links**: format for the active host (`artifact-protocol` › *Host-Specific Link Formats & Section Anchors*), always using `workspace-path` (never the snapshot path).

---

## Detailed Findings Format

Each 🔴/🟡 finding carries, in order:
1. **Heading**: `### <sev> N — <title> · Verified|Plausible` (append `· blind-spot pass` when from Step 6c).
2. **Where**: clickable `path:line` link(s) (plus dual thread link when covered by a PR thread).
3. **What and why**: the failing sequence or broken rule (cite the Standards source file/rule or quote the Spec/AC line).
4. **Fix**: concrete `diff` block with a one-line rationale, or **Decision needed:** with options when the fix is a product/design choice.

---

## In Plain Terms

For every 🔴 and 🟡 finding, write four short beats (~150 words max, always in simple English, no code/backticks/type names; gloss domain terms once in parentheses):
1. **What the code is trying to do** — one sentence in domain nouns.
2. **What actually happens** — numbered sequence of events with real actors (or promised vs actual for Spec).
3. **Why it's a defect and not a matter of taste** — name the contradiction (another path in the repo handles it, a stated promise breaks, or data becomes self-inconsistent).
4. **Who notices and how bad** — user-visible symptom and why the severity fits.
