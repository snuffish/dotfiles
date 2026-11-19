# Causes, homes and fix PRs

On-demand reference for [`SKILL.md`](../SKILL.md) Steps 6–8.

## Find the cause

For each finding the earlier review missed, ask which check should have caught it, and why it did not. Typical causes, in the order to test them:

| Cause | How to tell | Fix |
|---|---|---|
| No rule covers it | The project's review rules have no line that names the pattern. | A rule line in the rule file for that area. |
| No lessons entry | The rule exists in general, but no worked case shows what it looks like here. | An entry in the area's lessons file, or a new lessons file wired into the review like the others. |
| Thin allocation | The review's plan gave the area one agent while a smaller or easier area got several. | Change how the review splits work (cut-offs, which tracks get several finders), with a test on a fixture of this PR's diff. |
| Dropped on the way | The review found it, but it never reached the PR (left out of the posting question or the summary). | A step in the posting instructions that names every finding left out. |
| No hunt row | This skill's [`hunt.md`](hunt.md) has no row for the area, so the retro found it by luck. | A row in `hunt.md`, committed in the skill registry's own repo on a branch of its own. |

A cause needs proof: the plan output, the rule file on `origin/<default>`, or the transcript turn. A guess about the cause is not a fix. A finding can have two causes (a missing rule and a thin allocation); give each its own fix.

## Choose a home

One row per fix. Take the first home that fits:

| The fix | Home |
|---|---|
| Changes the PR's own code or config | A thread on the PR, for its author. Never a commit on someone else's PR branch. |
| Fits the concern of an open PR you own (same rule file, same skill gap; list them with `az repos pr list --creator <you> --status active`, `<you>` from `az account show --query user.name`, or `gh pr list --author @me`) | A commit on that PR. If another session holds its branch, commit from your own worktree, push, and tell the user that session must pull. |
| Anything else | A new PR, one concern each, so each can be reviewed and merged alone. |

Show the table with the reason for each row, then wait for the go.

## Open a fix PR

For each new PR:

1. **Worktree.** Create it from `origin/<default>` with `--no-track` and lock it in the same command (`git-worktrees` › *Workspace Lifecycle*). Peer sessions sweep clean, unlocked worktrees; an unlocked one can vanish mid-task.
2. **Edit**, then run the project's checks for what changed: tests of touched scripts, the skill drift checker and its claims file, size budgets of instruction files. A new fact in an instruction file gets a claim.
3. **Commit and push** through [`/commit`](../../commit/SKILL.md), passing the worktree and the message. Recheck that the target PR, if any, is still open before pushing.
4. **PR.** Create it as a draft with the repo's PR template, in English. The description says what the review missed on the source PR and how this change catches it next time, and lists the checks run with their results.
5. **Work item.** Follow the project's PR rules (`AGENTS.md`, personal local rules) for linking a work item. Never guess a parent ID that the rules do not resolve; ask, or under `--dry-run` record `parent unresolved`.
6. **Description updates** on a draft pass the draft flag, or the update publishes it. Read back the draft state and description.
7. Keep the worktree until the PR exists, then remove it per *Workspace Lifecycle* › *Remove*.

A draft PR may get no CI build in projects that skip drafts; say so in the report.
