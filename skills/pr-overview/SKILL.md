---
name: pr-overview
description: 'Explains a pull request and its spec as one tabbed HTML page: Overview (the problem, before/after, tiles, what to review first), Architecture (one card per part of the change, with files, spec ids and diagrams), Spec (each decision or acceptance criterion against the code at the PR head) and Review (open findings, PO questions, merge state, follow-ups). Use for /pr-overview, "walk me through this PR", "overview of !18930", "does this PR meet the spec?". `--publish` also publishes it. Not for finding defects in a diff (use /code-review) or triaging reviewer threads (use /pr-feedback-review).'
disable-model-invocation: true
argument-hint: "<PR id | URL | branch> [--publish]"
---

# Skill: `/pr-overview` — One Page That Explains a PR

Explains what a PR does, why, and whether it meets its spec. The model gathers the facts and fills `overview.json`; `scripts/render_overview.py` writes the page, so layout and theme are identical on every run.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: the page is `<prefix>-pr_overview-<id>-<slug>.html`, claimed with `publish_new_artifact.sh` (extension `html`)
- `../_modules/pr-host.md`: resolve the PR, pin `lastMergeSourceCommit`, fetch work items and acceptance criteria
- `../_modules/project-profile.md`: where the spec lives (PRIIS: the User Story's decisions `D1–Dn`, plus the wiki plan)

- Read-only on the repo and the tracker: the skill reads the PR at its pinned head and writes only its own artifact. English output.
- Read the diff from a detached snapshot of the pinned head (`../_modules/git-worktrees.md` › _Snapshot Lifecycle_), never from the user's checkout.

---

## 1. When _not_ to use

| Situation                                    | Use instead                                |
| -------------------------------------------- | ------------------------------------------ |
| Find defects in the diff                     | [`/code-review`](../code-review/SKILL.md)  |
| Triage what reviewers already said           | [`/pr-feedback-review`](../pr-feedback-review/SKILL.md) |
| Write the PR description                     | [`/pr-desc`](../pr-desc/SKILL.md)          |
| Explain one piece of code or one comment     | [`/explain`](../explain/SKILL.md)          |
| Explain how a flow or a set of commands works, with no PR | [`/walkthrough`](../walkthrough/SKILL.md) |

---

## 2. Core Protocol & Workflow

1. **Resolve the PR and pin its head** (`pr-host` › _Fetch the PR…_): `lastMergeSourceCommit` is the head every `path:line` is checked against. A branch resolves through `pr-host` › _Resolve the PR from a branch_.
2. **Fetch the spec**: the linked work items and their parent story (acceptance criteria, or the decisions list in PRIIS). Without one, the Spec tab says so and holds the PR description's promises instead.
3. **Size the change**: `git diff --stat <base>...<head>` in the snapshot.
4. **Draft the cards yourself first** from the diff: one card per part (a seam, a table, an endpoint group, a wizard), grouped by what changes together, not by folder.
5. **Map spec to code**: start one `Explore` sub-agent on `claude-sonnet-5-5`. Its brief carries the snapshot path, the pinned head, the spec rows (id and text) and the status list in [references/schema.md](references/schema.md) › *Spec status*; it returns one line per row: `id | status | path:line evidence`. Spot-check at least three of its rows yourself and say so in the footer. Done when every spec row has a status and evidence.
6. **Fold in earlier reviews of the same PR last** (`<artifact-dir>` family `*-code_review-*`, `*-priis_review-*`), after your own cards, so they do not steer them. Only confirmed findings go on the page; refuted ones are left out.
7. **Write `overview.json`** to the scratchpad, following [references/schema.md](references/schema.md).
8. **Render, claim and open**:

   ```bash
   python3 -I <skill-dir>/scripts/render_overview.py <scratchpad>/overview.json <scratchpad>/overview.html
   bash ~/.terminal/skills/_modules/scripts/publish_new_artifact.sh <scratchpad>/overview.html <artifact-dir>/<prefix>-pr_overview-<id>-<slug> html
   ```

   The renderer exits 1 and prints one `error:` line per problem when the JSON is wrong. Fix the JSON, never the page. Then open the claimed path (`open <path>` on macOS, `xdg-open <path>` on Linux). Done when `python3 -I <skill-dir>/scripts/check_diagrams.py <path>` exits 0 (every diagram drew; exit 2 means the machine has no Chrome, so say the diagrams were not checked) and the page opens.
9. **`--publish`**: publish the claimed file with the Artifact tool (`icon: "doc"` on a first publish; the renderer already follows the page contract, so skip the design pass) and attach the link to the work state as `work_product`.

### Rules

- Every claim cites `path:line` at the pinned head. Anything not checked goes in `footer`, e.g. a wiki plan not read.
- Domain words come from the repo's `GLOSSARY.md`; architecture words are the `codebase-design` terms (module, seam, adapter, depth).
- A card's `problem` and `solution` are one sentence each, in plain words. Diagrams are Mermaid, kept under about 12 nodes.
- Posting the page to the PR is out of scope; `/pr-post-comments` does that on request.

---

## 3. Output Format & Deliverables

Chat: the artifact path (and the URL with `--publish`), then three lines: size and head, spec met x/N, the one thing to review first. The page itself:

| Tab | Content | Source in `overview.json` |
| --- | --- | --- |
| Overview | Problem before/after, tiles, "review this first" | `overview` (`scripts/render_overview.py`, `build`) |
| Architecture | One card per part of the change | `architecture[]` |
| Spec | Matrix: id, text, status, evidence | `spec.rows[]` |
| Review | Findings, PO questions, merge state, follow-ups | `review` |

The page has no external CSS and no Tailwind; Mermaid loads from a pinned jsdelivr URL (`MERMAID` in `scripts/render_overview.py`), and tabs are plain JavaScript with a hash so `#spec` links work. Without JavaScript every tab shows in one column and diagrams stay as source.

---

## 4. Verification & Validation

- The renderer printed the HTML path and exited 0; a deliberately broken JSON exits 1 (`tests/fixture-18930.json` is the working example).
- Every `path:line` on the page was read at the pinned head; at least three sub-agent rows were spot-checked.
- No refuted findings and no unchecked claim without a footer note.
