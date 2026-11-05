# Web sweep

Read in Step 4 and pass this file to the web-sweep sub-agent. The source-group agents ask "what do the docs say?"; this agent asks "what out there would prove the claim wrong?" Docs describe intent and lag behind releases; issue trackers and changelogs record what actually ships.

## Brief

_"Read-only. Make no file edits, commits, worktrees or outward writes. You are checking claims against the outside world, not your memory: treat everything you think you know about these tools as a guess to test. For each numbered claim, run the searches below, read every promising hit with WebFetch, and report leads. Cite every lead as a URL with its publish or last-update date."_

## Searches per claim

Run at least these, adjusting terms to the product. Use WebSearch `standard` mode first; switch to `extended` when results are thin, off-target or older than the pinned version, and from the start for niche tools and post-cutoff claims.

1. **Locate the live official page**: `<product> <feature> docs`, preferring the domain from `source-routing.md`. Report its current URL, which may differ from the one the source-group agent remembers.
2. **Search for the opposite**: phrase the claim's negation and its failure symptoms: `<feature> not working`, `<feature> ignored`, `<feature> deprecated`, `<feature> removed in <major>`, `<error message>`.
3. **Issue tracker**: `site:github.com/<owner>/<repo> <feature>` (issues and discussions, open and recently closed), or the product's own tracker.
4. **What changed since**: the release notes or changelog from the pinned version to the latest release: `<product> <pinned version> release notes`, `<product> breaking changes <major>`. Report the latest version and anything between that touches the claim.

Skip a search only when an earlier one already settled the claim with a primary source, and say so.

## Report

Per claim, in one block:

```markdown
### <#> <claim>

- **Latest version found:** <version, date, URL> (pinned: <version>)
- **Official page:** <URL#section> — supports / silent / contradicts: "<quote>"
- **Disconfirming leads:** <URL, date, tier, one-line summary> … or "none found"
- **Queries run:** <the search strings>
```

## Lead tiers

| Tier         | Examples                                                                                                   | Can decide a verdict?                                                              |
| ------------ | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Primary      | Release notes, changelog, a maintainer's comment or label on the official tracker, the merged commit or PR | Yes, for the version it names                                                      |
| Corroborated | An issue on the official tracker with a reproduction that others confirm on the pinned version             | Makes the verdict at most **Partial**; the lead agent tries to raise it to Primary |
| Lead only    | Stack Overflow, blogs, forum posts, AI-generated answers, unconfirmed issues                               | No; it tells the lead agent where to look                                          |

Report leads of every tier, and say when a lead predates the pinned version (it may already be fixed).
