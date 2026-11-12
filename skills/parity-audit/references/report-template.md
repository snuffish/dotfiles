# Parity audit report template

Sections in this order. Keep it terse: tables over prose, and the conclusion first.

```markdown
<!-- artifact-owner: … -->
# <Subsystem> parity audit: <PR> vs <old framework/version>

**Branch:** `<branch>` @ `<new-sha>` (<PR>) · **Baseline:** `<old-sha>` (<old lib + version>) vs <new lib + version>
**Method:** ≤3 discovery + ≤2 verify agents; libraries decompiled (<tool>); runtime proof on <local stack>. Read-only: <what was not touched>.

## Verdict

- **Same:** <what has parity>
- **Better:** <improvements>
- **Needs action** (ranked):

| # | Finding | Verdict | Fix |
|---|---|---|---|
| 1 | <behaviour, with path:line and "proven locally" when it was> | regression / parity, docs wrong / unclear | <one-line fix> |

## Shared wiring (applies to every unit)

| Dimension | Old @<old-sha> | New @<new-sha> | Verdict |
|---|---|---|---|

## Per-unit matrix

| Unit | Schedule (old → new path:line) | Misfire / concurrency | Tx + publish order (new lines) | Idempotent on re-run | Verdict |
|---|---|---|---|---|---|

## Cross-unit: shared tables and overlap

| Window | Units | Shared writes | Old | New | Risk |
|---|---|---|---|---|---|

### Fixes vs <named plan>
- <premise overturned / question made moot / question still open>

## Runtime proof (<date>, this session)
- Setup: <instances, ids, how they were made distinct>
- Counts: <table per job × bucket × instance>
- Seeded run: <baseline → result → 1:1 assertion → restore + baseline re-run>
- Limits: <timing only / serialised / not raced>
- Cleanup: <what was stopped, what still runs>

## Not settled
- <open evidence gaps>

## Compared with earlier work on <PR>
Written after the findings above were drafted.
- <artifact:line> — <confirmed / contradicted because … / decision already made in …>
- New in this audit: <findings>
```

Verdict words: `intended` (deliberate and fine), `regression` (worse than before, with a failure scenario), `parity` (the same, including the same bug), `unclear` (missing evidence named), `improvement`.
