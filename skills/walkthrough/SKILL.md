---
name: walkthrough
description: 'Explains how a flow, a script or a set of commands works as one tabbed HTML page: an Overview tab (what it is for, the whole flow, what each part reads and writes) and one tab per part (what it does, why it exists, numbered steps with path:line), with collapsible sections for the detail. Use for /walkthrough, "walk me through how X works", "explain these commands, one tab per phase", "how does this pipeline work and what is it for?". `--publish` also publishes it; `--dry-run` stops after the render. Not for a pull request and its spec (the user runs /pr-overview), a short answer in chat (use /explain) or research before a change (use /investigate).'
disable-model-invocation: true
argument-hint: "<commands, files or a flow> [--publish] [--dry-run]"
---

# Skill: `/walkthrough` — One Page That Explains How Something Works

Explains what a flow, a script or a set of commands is for and how each part works, at the commit it was read at. The model reads the code and fills `walkthrough.json`; the `/pr-overview` renderer writes the page (`build_walkthrough` in `../pr-overview/scripts/render_overview.py`), so it looks like a `/pr-overview` page.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: the page is `<prefix>-walkthrough_page-<slug>.html`, claimed with `publish_new_artifact.sh` (extension `html`); `<artifact-dir>` is the one of the repo being explained, also when the session started in another repo

On-demand references (`references/`):

- [`references/schema.md`](references/schema.md) — the JSON fields and the block types; read before step 5

- Read-only on the repo: the skill reads the checkout in place and writes only its own artifact.
- English output. File names, commands and labels stay as the repo writes them, also when its docs are in another language.
- It describes what the code does; it does not review it. A suspected defect met on the way is one line in the footer.
- `<registry>` is the parent of this skill's real folder.

---

## 1. When _not_ to use

| Situation                                          | Use instead                               |
| -------------------------------------------------- | ----------------------------------------- |
| A pull request and whether it meets its spec       | [`/pr-overview`](../pr-overview/SKILL.md) |
| One piece of code or one comment, answered in chat | [`/explain`](../explain/SKILL.md)         |
| Research before designing a change                 | [`/investigate`](../investigate/SKILL.md) |
| Find defects                                       | [`/code-review`](../code-review/SKILL.md) |

---

## 2. Core Protocol & Workflow

1. **Scope.** List the parts the user named (commands, files, functions, steps of a flow) in the order they run, and find each one's entry point in the code.
   - A part the code does not have (a mistyped command, a flag that does not exist, an invocation that cannot work) gets no tab. It becomes a `note` on the Overview tab, one per mismatch, and the part the code does have gets the tab under the name the code uses.
   - A part the named ones depend on that the user did not name (a shared helper, a step that must run first) is explained where it is used. It gets a tab of its own only when the named parts cannot be understood without it.
   - List `<artifact-dir>` for an earlier `*-walkthrough_page-*`, `*-pr_overview-*` or `*-explanation-*` on the same topic. Open one only to see which files it cites: every fact is still read again (`core` › _Codebase investigation_).

   Done when every named part has an entry point with its `path:line`, or a mismatch note.

2. **Pin.** `git -C <repo> branch --show-current` and `git -C <repo> rev-parse --short HEAD` go in `page.head` (`main 2b29f14`; on a detached checkout the short commit alone). Run `git -C <repo> status --short` before rendering: an uncommitted change in a file the page cites is named in the footer.
3. **Read each part from its entry point to its output**, yourself (an `Explore` sub-agent may locate files; every `path:line` on the page is one you read): what it reads, what it writes, each step in order, what stops it, and what a second run does. Note the `path:line` of every fact as you read. Read the repo's own docs for the flow (run book, README, decisions) for the purpose, and cite them the same way. Done when every part has what it reads, what it writes, its steps, what stops it and what a second run does, each with a `path:line`.
4. **Find the purpose.** Two or three sentences a newcomer understands: why this exists and what would go wrong without it. Take it from the repo's docs or the code's own comments. When the repo does not say, write that in the footer and do not guess. Done when the purpose cites a doc or a comment, or the footer says the repo does not state it.
5. **Write `walkthrough.json`** to the scratchpad, following [`references/schema.md`](references/schema.md): the Overview tab first, then one tab per part in run order. Done when every row of _What goes on each tab_ is on its tab and the render in step 6 prints no `error:` line.
6. **Render, check, claim and open**:

   ```bash
   python3 -I <registry>/pr-overview/scripts/render_overview.py <scratchpad>/walkthrough.json <scratchpad>/walkthrough.html
   python3 -I <registry>/pr-overview/scripts/check_diagrams.py <scratchpad>/walkthrough.html
   bash <registry>/_modules/scripts/publish_new_artifact.sh <scratchpad>/walkthrough.html <artifact-dir>/<prefix>-walkthrough_page-<slug> html
   ```

   - The renderer prints the HTML path when the JSON is right. When it is wrong it exits 1 and prints one `error:` line per problem, a misspelt key included. Fix the JSON, never the page.
   - `check_diagrams.py` prints one line per tab (`<tab>: 2/2 drawn`, or `no diagram`). A line ending in `FAIL` is a diagram that did not draw: fix its Mermaid and render again. `no Chrome or Chromium found` (exit 2) means the diagrams were not checked, and the chat says so.
   - Then open the claimed path (`open <path>` on macOS, `xdg-open <path>` on Linux).

7. **`--publish`**: publish the claimed file with the Artifact tool (`icon: "doc"` on a first publish; the renderer already follows the page contract, so skip the design pass) and attach the link to the work state as `work_product`. **`--dry-run`**: stop after the render and the diagram check, with no claim, no open and no publish.

### What goes on each tab

| Tab          | Blocks, in order |
| ------------ | ---------------- |
| Overview     | The purpose (step 4) as one or two `text` blocks, each with its `ref`; a `table` with one row per part (columns Part, Reads, Writes, What it does, Code); one `diagram` of the whole flow; a `note` per mismatch from step 1; `details` for what every part shares, what must run before, where files land, and the words the page uses |
| One per part | A `command` with the real invocation (for a function, its usage line); `text` starting `**What it does.**`; `text` starting `**Why it exists.**`; `cols` with In and Out; a `heading` and the `steps`, each with its `ref`; a `note` for what stops it or surprises; `details` for the depth |

### Rules

- The text outside `details` is for a reader who has not seen the code: plain words, short sentences, one idea per step. A term of art is explained where it first appears.
- Depth goes in `details`, whose summary starts `More:` on a part's tab and names its content on the Overview tab: exact rules and thresholds, every check with its error, options and defaults, what a second run does, edge cases.
- Every step, and every statement about the code in a `details` block or a table, carries a `ref` read at the pinned commit. A definition of a word needs none.
- What you inferred, and did not read as a statement or see in a run, is worded as an inference where it stands ("may", "inferred from …"). Anything not read or not run is named in the footer.
- An example value is invented and says so. Never paste rows from the repo's data files onto the page.
- `steps` is for a real sequence only. Tab labels are numbered only when the repo's docs or the code fix the order the parts run in.

---

## 3. Output Format & Deliverables

Chat: the artifact path alone in a code block (and the URL with `--publish`; the scratchpad page's path with `--dry-run`), then three lines: what was read and at which commit, each mismatch between the request and the code, and what was not checked.

The page has no external CSS and no Tailwind, and tabs are plain JavaScript with a hash, so a link can point at one tab. A diagram inside a closed `details` block is drawn when the section opens (the `toggle` listener in `JS`, `../pr-overview/scripts/render_overview.py`).

---

## 4. Verification & Validation

- The renderer printed the HTML path and no `error:` line, and `check_diagrams.py` printed no `FAIL` line (`../pr-overview/tests/fixture-walkthrough.json` is the working example).
- Every `ref` on the page was read at the pinned commit.
- The footer names the commit, what was not read and what was not run.
