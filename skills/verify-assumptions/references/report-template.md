# Report template

Read in Section 3. Verdict grades follow `core` › *Codebase investigation* › *Confidence Ledger*.

## Chat (always)

```markdown
**Verified against:** <sources, with versions>
**Web sweep (`deep` only):** <claims swept, latest versions found, disconfirming leads and how each was resolved, or "no disconfirming leads">

| # | Claim | Verdict | Evidence | Effect |
|---|---|---|---|---|
| A | <claim> | ✅ Confirmed / ❌ Contradicted / ◐ Partial / ❔ Undocumented | <short quote> — [page#section](url) or [file:line](path#Lline); *disputed: [lead](url)* when unresolved | Holds / Weakened: … / **Reopen**: … |

**Decisions to revisit:** <reopened decisions as questions with a recommendation, or "none">
**Proposed edits (after /proceed):** <exact changes to the plan, ADR or doc, or "none">
```

## Artifact (`deep` or more than 10 claims)

Write `<prefix>-assumption_check-<suffix>.md` in the artifact dir with one section per claim: claim, version, sources consulted, search queries run, disconfirming leads with their tier and resolution, verbatim quotes, verdict, effect. In chat, show only the contradicted, undocumented-and-load-bearing and reopened rows, plus the `artifact-protocol` › _Chat link block_.
