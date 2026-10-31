# Manual Test Plan Artifact Template

On-demand reference for [SKILL.md](../SKILL.md) › *3. Artifact `<prefix>-manual_test_plan-<suffix>.md`*.

````markdown
<!-- artifact-owner: <host>-<model> · session <id> · created <ISO-8601> -->

# Manual Test Plan — <title> (#<workItemId>)

|                 |                                                                                                 |
| --------------- | ----------------------------------------------------------------------------------------------- |
| **Work item**   | [#<id>](url) <title> · AC present / absent (PR descriptions used)                               |
| **PRs**         | <repo> [!<id>](url) → `<target>` · <repo> [!<id>](url) → `<target>` (stacked on !<id>)          |
| **Branches**    | `<repo>`: `<branch>` @ `<sha>` · `<repo>`: `<branch>` @ `<sha>` · uncommitted changes: yes / no |
| **Counterpart** | Found / Found, excluded / Expected but missing / None                                           |

**At a glance:** <N> scenarios (<n> 🔥) · log in as `<account>` · blocker: <one line, or "none">

> [!WARNING]
> **Before you start.** Only when a destructive or blocking prerequisite exists: what breaks, why, the exact command, and **destructive** if it destroys data.

## <a id="setup"></a>1. Setup

```bash
<minimal command sequence, each read from the repo>
```

| Service | Address                 | Source                  |
| ------- | ----------------------- | ----------------------- |
| App     | http://localhost:<port> | [<config>](<path>#L<n>) |

## <a id="logins"></a>2. Logins

|     | Account | Password         | Role             | Use for           |
| --- | ------- | ---------------- | ---------------- | ----------------- |
| ⭐  | `<id>`  | `<dev password>` | <role / persona> | <which scenarios> |

## <a id="test-data"></a>3. Test data

| Record | Seeded state         | Used in | Source                  |
| ------ | -------------------- | ------- | ----------------------- |
| <name> | <state that matters> | S1, S4  | [<seeder>](<path>#L<n>) |

<inspect query and reset snippet, if a scenario consumes its precondition>

<with `--seed-data`: the commands this run ran, each followed by its undo; or `not run — <why>` and the commands to run by hand>

## <a id="scenarios"></a>4. Scenarios

| #         | Scenario | As          | Risk |
| --------- | -------- | ----------- | ---- |
| [S1](#s1) | <claim>  | `<account>` | 🔥   |

### <a id="s1"></a>S1 · <observable outcome, phrased as a claim>

**As** `<account>` · **Record** <seeded record> · **Risk** 🔥 <why: the Step 3/4 finding behind it>
**Given** <preconditions; omit the line if none>

1. <step: concrete route, UI labels in the app's language>
2. …

**Expect**

- [ ] <observable result>
- [ ] …

> ⚠️ **Watch for:** <the specific wrong output this change could produce; omit for a plain happy path>

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

- **Seeded records** (`--seed-data`) show `seeded by this run` in *Source* instead of a seeder link.
- **Scenarios** are ordered **most-likely-to-be-broken first**, not in diff order. Six sharp scenarios beat twenty that restate the diff.
- **Risk markers** (distinct from `/code-review` 🔴/🟡/🟢): `🔥` high (removed signal, ungated consumer, contract, permission, migration) · `⚠️` medium (changed behaviour on an updated path) · `🔹` low (happy path, cosmetic).
- **Expect** lines use markdown checkboxes (`- [ ]`).
- Order scenarios that **consume** a precondition after the ones that need it, and note the order in *Given*.
- **Links**: format source links per `artifact-protocol` › *Host-Specific Link Formats & Section Anchors*; use HTML anchors (`#s1`, `#watchlist`) for intra-document links.
- Quote UI labels in the app's language; write prose in the conversation's language (or profile *Report language*).
- Omit *Before you start*, *Given*, *Watch for*, and empty rows when unused; never omit *Regression watchlist* (`None found — checked <what>` when clean).
