# Capturing the Reviewer's Selected Code

On-demand reference for [SKILL.md](../SKILL.md) › *Step 2 — Fetch PR Metadata, Reviewers & Discussion Threads*.

An inline thread is anchored to the lines the reviewer selected. Quote that selection in the artifact (*Selected code*) from the **commit the reviewer saw**, not from head (head shows what the code is *now*, which belongs in *State at head*):

- **Azure DevOps**: the selection is `threadContext.rightFileStart.line` … `rightFileEnd.line` (new side; if only `leftFileStart`/`leftFileEnd` are set, the reviewer selected removed lines on the base side). Map `iterationContext.secondComparingIteration` to that iteration's `sourceRefCommit.commitId` (left side: `commonRefCommit.commitId`). Fetch iterations once per PR:
  ```bash
  az devops invoke --org <org-url> --area git --resource pullRequestIterations \
    --route-parameters project=<project> repositoryId=<repo> pullRequestId=<prId> --api-version 7.1 -o json > iterations.json
  # filePath starts with '/': strip it
  git -C <repo> show <iteration-commit>:<filePath-without-leading-slash> | sed -n '<start>,<end>p'
  ```
- **GitHub**: a review comment carries `path`, `original_commit_id`, `original_start_line` (null for one-line selection), `original_line`, and `side` (`LEFT` = removed lines). Read `git -C <repo> show <original_commit_id>:<path> | sed -n '<start>,<end>p'`, falling back to the tail of `diff_hunk`.
- **Commit unreachable** (force-pushed branch where `git fetch origin <sha>` fails): quote the same range at head and label it `(at head — iteration commit no longer reachable)`.
- Store the snippet alongside each thread in the scratchpad dump so `deep` mode sub-agents receive it. Cap at 20 lines (`// … <n> more lines` after). Omit for general threads with no file anchor.
