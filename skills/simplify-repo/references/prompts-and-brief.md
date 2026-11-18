# Prompts and the review brief

On-demand reference for [`/simplify-repo`](../SKILL.md): the text handed to `/simplify` per row (Step 4), the review brief (Step 7) and the reviewer's prompt (Step 9).

---

## Row target

Pass this as the argument of `/simplify`, once per row. The first paragraph matters most: `/simplify` otherwise gathers a diff and launches four agents.

```text
Review target: row <X> (<folder>), whole files at HEAD, not a diff. Single pass, no sub-agent
fan-out. Behaviour unchanged, including how each file is started (script, module, CI step):
no change to <the contracts from Step 2>.

Files to edit, and no others:
<one path per line>

Tests you may edit where a change needs it:
<one path per line>

Protected, keep any change to one small hunk and list it separately:
<one path per line>

Start from these hints: <the row's ● and ○ hints, each with file:line>.
Proposed changes: <the row's Proposed change cell>. Apply them where they hold up. Report each
one as applied, changed or dropped, with the reason.

Never open, search or edit: <no-touch paths>. Never run: <forbidden commands>.
Reading another file to reuse a helper is fine. Do not commit.
```

Leave out a block whose list is empty (no tests, no protected files).

---

## Review brief

Facts only. Leave out verdicts such as "safe" or "behaviour-preserving": the reviewer has to establish those without being steered by this run. Before the commits exist, write `Range: not committed yet` and fill the table in Step 8.

```markdown
# Review brief: first cleanup of <repo or folder>

Range: `<first>^..<last>` on `<branch>` (pushed <date> | not committed yet).
Spec: simpler code, same behaviour. No change to <contracts from Step 2>. Treat that as unproven.

## Commits

| Commit | Row | Files |
| ------ | --- | ----- |

## What changed

- <Row>: <one clause per applied change, naming the symbol and what it now uses>
- Not edited: <files in scope that were left alone>

## Verification (<machine and runtime version>, before the commits)

- `<command as it ran>`: <n passed | failed: the failing check>
- Not run: <forbidden commands, and anything skipped, with the reason>

## Known risks

1. <path:line>: <what could differ, and why the change was kept>
2. No test covers: <each changed path marked `no test` in Step 6>
3. Protected files: <file>: <the one hunk>, or "none touched"
4. <what the push sets off, and anything recorded elsewhere that the change makes stale>

## Dropped on purpose

- <proposed change>: <the behaviour it would alter, or the test it lacks>
```

In Step 11, update it in place: add the follow-up commits and the review artifact's path under the `Range` line, and rewrite each known risk to its state now (`covered since <sha>`, `build <id> succeeded`, `still open`).

---

## Reviewer prompt

The sub-agent starts with no context, so the prompt carries everything it needs and nothing of this run's reasoning.

```text
Review a cleanup that claims to change no behaviour. Read-only: make no file edits, commits,
worktrees or outward writes, and run no builds or tests.

Run /code-review --axes correctness,standards,spec on the range <first>^..<last> of <repo-root>
(branch <branch>). If you cannot invoke the skill, read its SKILL.md and follow it. The Spec
source is the review brief at <absolute path of the brief>. It lists what changed and the risks
its author saw. Treat every "same behaviour" as unproven: compare each changed hunk with the
code before it.

Rules for this review:
- A risk the brief names is still a full finding when it holds. Naming it did not make it safe.
- A changed code path that no test runs is a finding on the Standards axis: give the path and the
  test file that should cover it. Do not write or run tests.
- Never open, search or grep: <no-touch paths>. Scope every search to: <the folders of the picked
  rows, their test folders and the docs folders that cite them>.
- Draft your own findings before you read any earlier review of this range.
- Report confirmed findings only, in the review artifact. Post nothing to a PR or tracker.

Return the artifact's absolute path, then one line per finding: severity, path:line, the claim.
Add what you could not check from this machine.
```
