# Skill-review lenses

On-demand reference for [`SKILL.md`](../SKILL.md) steps 2 and 4. Each lens has a check, the evidence command and a worked example. Run every lens; a lens with nothing to report still yields one *Checked, no finding* line. Search with `git grep` and `git ls-files`; a bare `*` or `====` in a zsh command breaks it.

## 1. Triggers

**Check:** the `description` is an always-loaded pointer. It leads with the word users type, holds one trigger per branch and carries no identity the body already holds. Sibling skills with overlapping triggers route between each other.

**Evidence:** read the `description` of the target and of every sibling that shares a trigger clause (`git grep -n '^description:' -- <skills-dir>`); compare the trigger clauses word for word.

**Example:** a backend review skill opened with the old repo name, its trigger clause matched the frontend and full-stack skills word for word, and nothing said which one wins. Fix: lead with the user's word (*backend*), keep one trigger per branch, add one routing clause naming the siblings, and mirror it in the neighbour.

## 2. Load points

**Check:** every file under `references/` is reachable at the step that needs it, as a pointer with a verb ("Follow …"), and also on the branches that cross a context boundary: a subagent brief, a handoff, a track another skill spawns.

**Evidence:** `git ls-files <skill>/references`, then for each file the line that names it; then read every brief the skill builds (`git grep -n -i 'subagent\|brief\|track' -- <skill>`) and list what it passes on.

**Example:** a subagent brief listed the diff path and the AC checklist but not the skill path or the reference file its pass reads, so the subagent never saw the checks.

## 3. Structure

**Check:** the main file holds what every branch needs; what only some branches reach sits behind a pointer. A concept's definition, rules and caveats share one heading. Each rule is written once.

**Evidence:** the step list and heading list (`git grep -n '^#' -- <skill>`); search a distinctive phrase of each rule across the skill and its siblings.

**Example:** one rule stated in full in three places; fix: the sibling skill that owns the topic holds the only full copy, the others keep a pointer and a one-line cell.

## 4. Size

**Check:** the body is within the project's budget (the profile's `Skill-review checks`; the registry default is the drift script's `SIZE_BUDGET`). A table every run reads fails the branching test, so moving it behind a pointer saves nothing.

**Evidence:** `wc -c` of the body (below the frontmatter) of `SKILL.md`, and the budget constant in the drift script.

**Example:** a body 1.7 KB over budget after the fixes; the large table is used by every run, so the finding is "measure, then trim the maintainer rationale", not "move the table".

## 5. Claims against code

**Check:** every symbol, path, flag, count and section anchor the skill cites exists at the pinned ref. Names that exist only on an unmerged branch are *latent* until it merges. A drift claim that greps only a signature cannot fail when the behaviour changes. Folder names in lists are the real ones.

**Evidence:** `git grep -n -w '<symbol>'` per cited name at the ref (and `git show <source-head>:<path>` for unmerged ones); `git grep -n '<anchor text>'` per `#anchor` and `›` pointer; read the matching claims in the claims file for the line they pin.

**Example:** a check cited a helper from an unmerged PR: 0 hits on `main`. Another listed a test-data helper under a folder it does not live in. A drift claim grepped the method name only, so it stayed green after the code under it changed.

## 6. Strict frontmatter

**Check:** the frontmatter parses with a strict YAML loader. An unquoted `: ` inside a plain scalar fails there while Claude Code parses it leniently.

**Evidence:** `ruby -ryaml -e 'YAML.safe_load(File.read(ARGV[0]).split("---")[1])' <SKILL.md>` for the target and each sibling; a parse error prints the line and column.

**Example:** three review skills failed on "…reviewers catch: …"; fix: `description: >-` or a quoted scalar.

## 7. Consumers of a rename or move

**Check:** before accepting any rename, move, merge or delete, every consumer of the old name is found: other skills, briefs, anchors, claims, CI and docs.

**Evidence:** `git grep -n -F '<old name or anchor>'` across the repo and the registry.

**Example:** renaming Pass G to F in the backend review would have made the full-stack track skip the backend conventions pass, because that track skips the frontend's Pass F by letter.

## 8. Standard and repo rules

**Check:** the text follows `writing-for-agents`: positive instructions, leading words, completion criteria, no negation-only rules. Project rules from the profile's `Skill-review checks` hold (for example, repo text never names personal skills).

**Evidence:** `git grep -n -i '<forbidden term>' -- <skill>`; read the steps for a done-criterion each.
