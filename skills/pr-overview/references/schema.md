# overview.json schema

Checked by `scripts/render_overview.py`; a missing or mistyped field fails the render with one `error:` line per problem. Example: `tests/fixture-18930.json`. All text is plain text (the renderer escapes it): no HTML, no Markdown.

A JSON with a top-level `tabs` key is a walkthrough instead (`build_walkthrough`): free tabs and collapsible sections, with its own schema in `../../walkthrough/references/schema.md`.

```text
{
  "pr":       { "id", "title", "repo", "head", "date", "summary", "size" },           # all strings
  "overview": {
    "problem":      { "before": Side, "after": Side, "source"? },
    "tiles":        [ { "label", "value", "tone"? } ],                               # tone: ok | warn | bad | mute
    "review_first": { "title", "text", "target" }                                    # target = an architecture card id
  },
  "architecture": [ {
      "id", "title", "problem", "solution",                                          # id: unique, used as the anchor
      "spec":  ["D2", ...],  "files": ["path:line", ...],                            # both non-empty lists
      "tags"?: [...], "wins"?: [...], "before"?: Side, "after"?: Side, "risk"?: ""   # risk renders as a red note
  } ],
  "spec":   { "note"?, "rows": [ { "id", "text", "status", "evidence" } ] },
  "review": { "findings"?: [...], "po_questions"?: [...], "merge"?: [...], "followups"?: [...], "source"? },
  "footer": ""                                                                       # head sha, spec source, what was not checked
}
Side = { "mermaid": "<diagram source>" }  or  { "text": "<one short paragraph>" }
```

## Spec status

`Met`, `Met in UI` (the API does not enforce it), `Met · PO open` (met, but a product-owner question is open), `Partly`, `Not met`, `Out of scope`. Anything else fails the render.

## Writing the fields

- `head`: the 9-character `lastMergeSourceCommit`. `date`: the day the code was read.
- `files` and `evidence`: `path:line` or `path:from–to` at `head`; `…/` may shorten a folder shared with the line above, and the spec table's `note` may define one-letter prefixes (`B/`, `L/`, `FE/`).
- `before` / `after`: a diagram when the shape is a flow, a sequence or a dependency; text when it is a rule or a lifecycle. Omit both when there is no before.
- Mermaid: no `classDef` colours (the page sets the theme), no HTML besides `<br/>`, under about 12 nodes.
- `risk`: only a confirmed finding or a stated follow-up, with its `path:line`.
- Tiles: three to four numbers a reviewer scans first (spec met x/N, open findings, follow-ups).
