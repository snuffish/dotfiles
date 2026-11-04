# Manual Test Plan Artifact Template

On-demand reference for [SKILL.md](../SKILL.md) › _3. Artifact & Chat Output_. The plan is read twice: as markdown in an editor, and as HTML via `/export-file html` (`render_html.py`). Every rule below keeps both readable.

````markdown
<!-- artifact-owner: <host>-<model> · session <id> · created <ISO-8601> -->

# Manual test plan: <title> (#<workItemId>)

<One sentence: what the change does, in the words a tester would use.>

- **Work item:** [#<id>](url) <title> · AC present / absent (PR description used)
- **PR:** <repo> [!<id>](url) → `<target>`
- **Branch:** `<branch>` @ `<sha>` · uncommitted changes: yes / no
- **Counterpart:** Found / Found, excluded / Expected but missing / None

**At a glance:** <N> scenarios (<n> 🔥) · log in as `<account>` · blocker: <one line, or "none">

> [!TIP]
> **How to use this plan.** Do _Setup_ once, then run the scenarios top to bottom. Tick each _Expect_ box when you see it, and set the scenario's **Result**: ✅ pass, ❌ fail (write what you saw), ⏭️ skipped. Scenarios marked _consumes data_ change records; _Test data_ says how to reset them.

> [!WARNING]
> **Before you start.** Only when a destructive or blocking prerequisite exists: what breaks, why, the exact command, and **destructive** if it destroys data.

## <a id="setup"></a>1. Setup

```bash
<minimal command sequence, each read from the repo>
```

| Service | Address                 | Source                    |
| ------- | ----------------------- | ------------------------- |
| App     | http://localhost:<port> | [<file>:<n>](<path>#L<n>) |

## <a id="logins"></a>2. Logins

|     | Account | Password         | Role             | Use for           |
| --- | ------- | ---------------- | ---------------- | ----------------- |
| ⭐  | `<id>`  | `<dev password>` | <role / persona> | <which scenarios> |

## <a id="test-data"></a>3. Test data

| Record | State that matters | Used in |
| ------ | ------------------ | ------- |
| <name> | <state>            | S1, S4  |

Source: [<seeder>:<n>](<path>#L<n>) (or **seeded by this run**).

<details>
<summary>IDs, inspect query and reset</summary>

<record ids, one per line>

```sql
-- inspect (read-only); one clause per line, lines ≤ 100 chars
```

```sql
-- reset / undo; one statement per line
```

</details>

## <a id="scenarios"></a>4. Scenarios

| #         | Scenario | As          | Risk | Result |
| --------- | -------- | ----------- | ---- | ------ |
| [S1](#s1) | <claim>  | `<account>` | 🔥   | ⬜     |

### <a id="s1"></a>S1 · <observable outcome, phrased as a claim>

**As** `<account>` · **Risk** 🔥 <why: the Step 3/4 finding behind it>

**Given** <preconditions; "consumes data: <record>" when it does; omit the line if none>

**Steps**

1. <step: concrete route, UI labels in the app's language>
2. …

**Expect**

- [ ] <observable result>
- [ ] …

> ⚠️ **Watch for:** <the specific wrong output this change could produce; omit for a plain happy path>

**Result:** ⬜ not run

## <a id="watchlist"></a>5. Regression watchlist

| Surface                      | Where                           | What you would see |
| ---------------------------- | ------------------------------- | ------------------ |
| <screen / API / merge order> | [<file>:<line>](<path>#L<line>) | <symptom>          |

## <a id="not-testable"></a>6. Not manually testable

| What                                    | Why not by hand | Safety net                                |
| --------------------------------------- | --------------- | ----------------------------------------- |
| <outcome / race / volume / third party> | <reason>        | <test name, dry-run, staging — or "none"> |

## <a id="not-covered"></a>7. Not covered by design

- <refactor / test-only / internal change>: no observable effect.
````

---

## Layout Rules

**Content**

- **Scenarios** are ordered **most-likely-to-be-broken first**, not in diff order. Six sharp scenarios beat twenty that restate the diff.
- **Risk markers** (distinct from `/code-review` 🔴/🟡/🟢): `🔥` high (removed signal, ungated consumer, contract, permission, migration) · `⚠️` medium (changed behaviour on an updated path) · `🔹` low (happy path, cosmetic).
- Order scenarios that **consume** a precondition after the ones that need it, and say `consumes data: <record>` in _Given_.
- Quote UI labels in the app's language; write prose in the conversation's language (or profile _Report language_).
- Omit _Before you start_, _Given_, _Watch for_, `<details>` and empty rows when unused; never omit _Regression watchlist_ (`None found — checked <what>` when clean). Keep the _How to use_ tip.

**Readability (markdown and HTML)**

- **Metadata** is a bullet list, never a table with an empty header row.
- **Tables** have at most 5 columns, and cells hold short text. UUIDs, SQL, long URLs and file paths go below the table or in a `<details>` block.
- **Link labels** are `file.ext:line` (e.g. `[Operation.cs:96](…)`), never the full path; the URL carries the path.
- **Code blocks** keep lines ≤ 100 characters: one SQL statement or clause per line, long shell commands split with `\`.
- **Reference material** a tester reads only when needed (record ids, inspect and undo queries) goes in `<details><summary>…</summary>` with a blank line after `<summary>` and before `</details>`, so markdown inside still renders.
- **Expect** lines use checkboxes (`- [ ]`); in the HTML export they can be ticked and are remembered per browser.

**Results**

- Every scenario ends with `**Result:** ⬜ not run`, mirrored in the _Result_ column of the scenario table. Values: `⬜ not run` · `✅ pass` · `❌ fail — <what you saw>` · `⏭️ skipped — <why>`.
- When a scenario is run in a session that owns the artifact, update the scenario's _Expect_ boxes, its **Result** line and its table cell in the same edit (`artifact-protocol` › _Status Sync Rule_).
- **Links**: format source links per `artifact-protocol` › _Host-Specific Link Formats & Section Anchors_; use HTML anchors (`#s1`, `#watchlist`) for intra-document links.
