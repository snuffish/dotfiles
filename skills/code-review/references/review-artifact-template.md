# Code Review Artifact Template & Structure

### Artifact Structure

Sections in this order, and **nothing after In Plain Terms**:

1. `## Review Context` — a small table: PR(s) and work item(s) per repo, **Counterpart** (the `pr-counterpart` › *Classification*: `<repo> !<id>` reviewed / found, not reviewed / expected but missing / single-repo change), base, **Head reviewed** per repo as `` `<source-ref>` @ `<short-sha>` `` (*Step 1b-a*) — e.g. `` Backend `origin/feature/31085_permit-…` @ `65c726bb` `` — never a bare SHA, **Reviewed from** (`` snapshot of `<source-ref>` @ `<short-sha>` (removed) `` / `… (kept at <path>)` / `` live checkout of `<branch>` ``), **Local checkout** per repo (its branch and `same commit` / `local ahead N / behind M` / `on <other-branch> — PR branch not checked out`; for a repo without a counterpart, where its contract side was read: `contract read at <default> @ <short-sha>`, plus the branch its checkout is on when that differs), **Untracked, not in snapshot** (`working`/`staged` only: file list or "none"), Spec source (or "none available"), Standards sources loaded, **Profile** (the profiles loaded, each upstream checklist and catalog as `<repo> origin/<default> @ <short-sha>` or "registry copy (upstream missing)", and any pointed-to heading not found; "none" without a profile), mode (standard/deep, plus `feedback`). With `feedback`: a **PR feedback** row linking the `pr_feedback_review` artifact(s), and giving the human thread count, how many threads attach to findings, and how many findings were added from threads. If *Step 6b* was skipped, the row says why.
2. `## Feature in Brief` — what the feature is and what it is meant to achieve, before any code is mentioned (see *Feature in Brief* below).
3. `## Summary of Changes` — 1–3 sentences on what the changes accomplish and their architectural intent.
4. `## Findings Summary` — the summary table. With `feedback`, the table gains a **Thread** column (`[#110776](#thread-110776)` with its host link, or `—`), and a `### PR Feedback Cross-Check` table follows it: one row per human thread with its *Thread*, *State at head* and *Disposition* (`covers finding N` / `added as finding N` / `decided — finding N lowered` / `refuted: <evidence>` / `no code defect`). The table accounts for every thread.
5. `## Detailed Review Findings` — 🔴/🟡 findings with their fix inline, then `### 🟢 Minor Findings`, then any subsections the profile's *Report additions* name (in the order it lists), then `### 💙 Praise`. A profile adds subsections here only, never top-level sections.
6. `## In Plain Terms` — only when there is at least one 🔴/🟡.

### Feature in Brief

*Summary of Changes* says **how** the code changed. This section says **what** is being built and **why**, so a reader can judge every finding against the goal. It is not a restatement of the diff.

Write 3–5 short sentences, or a few bullets, covering:

- **Who** it is for — the user role or persona (e.g. "case handlers", "suppliers", or the project's named personas when its Profile lists them).
- **The problem** they have today, or the gap the work closes. When the PR is a follow-up, also say what the earlier work left out.
- **The outcome** — what they can see or do once this ships.
- **Where it sits** — the parent story or feature it belongs to, and the counterpart PR in another repo when the work is split.

Rules:

- Draw it from the Step 2 spec source. The parent story usually carries the *why* when the child task is bare. Follow the work-item `Parent` link (Step 1) rather than stopping at a task with no description.
- Use domain words, not type, file or endpoint names. Keep the product's own terms (e.g. Swedish UI labels) and gloss each one in English the first time it appears.
- When no spec source exists, infer the purpose from the diff and say so: "*Inferred from the diff — no description or work item available.*" Never present a guess as the stated intent.
- Keep it neutral. Whether the code actually achieves the goal belongs in the Spec findings, not here.

### Findings Summary Table

| # | Severity | Axis | File | Issue |
|---|---|---|---|---|
| [1](#finding-1) · [plain](#finding-1-plain) | 🔴 | Correctness | `foo.ts` | Missing null check on `userId` |
| [2](#finding-2) · [plain](#finding-2-plain) | 🟡 | Spec | `bar.tsx` | AC "per category" not implemented |
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

1. **What the code is trying to do** — one sentence, in domain nouns (*contract
   template*, *subarea*, *case handler*), never type names (`ContractTemplate`,
   `SubareaContract`). When the product's working language is not English, keep its own
   word for a thing so the team recognises it, but gloss it in English the first time it
   appears — "*avtalsmall* (the master contract that subareas hang off)" — then use the
   term unglossed.
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
  Contract template  →  Subareas  →  Contracts
  ```
- **Don't repeat the fix.** Reference the numbered finding; the diff already lives above.
- **Skip 🟢 and 💙.** Polish and praise don't need restating.
- **Cap each at ~150 words.** If one needs more, the technical finding above it is
  underexplained — fix that instead of padding here.
- **Always write this section in simple English**, whatever language the rest of the review
  uses and whatever the product's working language is (a product that works in another
  language still gets an English explanation here). Don't add a line explaining the
  language choice.
- **Simple means simple.** Short declarative sentences, everyday words, one idea per
  sentence. "The record stays in the wrong state" — not "the entity's status remains
  inconsistent with its parent aggregate". Split any sentence that needs a second clause to
  survive. No acronyms without expanding them, no jargon a tester wouldn't use out loud.
- If the review produced no 🔴 or 🟡 findings, omit the section entirely rather than
  writing "nothing to explain".

---

