# walkthrough.json schema

Checked by `../../pr-overview/scripts/render_overview.py` (`build_walkthrough`): a JSON with a top-level `tabs` key renders as a walkthrough. A missing, mistyped or unknown field fails the render with one `error:` line per problem (`known`). Example: `../../pr-overview/tests/fixture-walkthrough.json`. Back to [`SKILL.md`](../SKILL.md).

```text
{
  "page":   { "name", "title", "summary", "source", "head", "date" },   # all strings
  "tabs":   [ { "id", "label", "title", "blocks": [Block, ...] } ],      # two tabs or more
  "footer": ""                                                           # commit, what was not read, what was not run
}
Line  = "<text>"  or  { "text", "ref"? }                                 # ref: the path:line behind the sentence
Block = { "type": "text",    "text", "ref"? }                            # one paragraph
      | { "type": "heading", "text" }
      | { "type": "command", "text" }                                    # shown verbatim in monospace; \n for a second line
      | { "type": "steps",   "items": [Line, ...] }                      # numbered
      | { "type": "list",    "items": [Line, ...] }
      | { "type": "table",   "head": ["..."], "rows": [[Line, ...]] }    # every row has as many cells as head
      | { "type": "diagram", "mermaid", "label"? }
      | { "type": "note",    "text", "ref"?, "tone"? }                   # tone: warn (default) | bad
      | { "type": "tiles",   "items": [ { "label", "value", "tone"? } ] }   # tone: ok | warn | bad | mute
      | { "type": "cols",    "boxes": [ { "label", "blocks": [Block] } ] }  # two boxes or more, side by side
      | { "type": "details", "summary", "blocks": [Block] }              # collapsible, closed on load
```

## Writing the fields

- `page.name`: the browser-tab title, two to four words. `page.title`: the heading. `page.source`: the repo and the file or folder the flow lives in. `page.head`: the branch and the short commit (`main 2b29f14`). `page.date`: the day the code was read.
- Tab `id`: lower-case letters, digits and dashes, unique. It is the link hash (`#import`), and the first tab's is `overview`. `settings`, `sidebar`, `customize`, `upgrade` and `downloads` are refused (`RESERVED`), and so is any id starting with `comment-`, because claude.ai keeps them on a published page.
- Text is plain text and the renderer escapes it. Two marks are read (`INLINE`): `` `code` `` and `**bold**`. No HTML and no other Markdown. `command` text, table headers, tab labels, `page.title`, tiles and the labels of a `cols` box or a `diagram` take no marks.
- `ref`: `path:line` or `path:from-to` at `page.head`. The path starts at the repo root the first time a tab names the file; after that the same tab may use the file name alone. One `ref` may hold several ranges and files, comma-separated (`run.sh:55-67, labels.py:51`). The renderer prints it as written and does not check it.
- A table cites code in a last `Code` column, or with a `ref` on the cell.
- A `details` or `cols` block holds no `details` or `cols` of its own.
- Mermaid: no `classDef` colours (the page sets the theme), no HTML besides `<br/>`, under about 12 nodes. Quote a label that holds brackets: `OK["0 leak(s)"]`.
- `tiles` are optional and most pages have none: only for the three or four numbers that are the point of the flow (a threshold, a share, a limit). A tile takes no `ref`, so each number is also stated with its `ref` on the tab that explains it.
