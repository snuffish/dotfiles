# State checks without `git status` phrases

Run these in place of reading the Step 1 `status` text when `status` is not in English or holds none of the phrases Step 1 and Step 6 look for. Each is one call.

## Step 1: repo and state

1. **Repo root:** `git rev-parse --show-toplevel` (in a multi-repo workspace, handle each changed repo separately; check for locked `claude-skill:` worktrees per `git-worktrees` › *Using this Module from a Command*).
2. **Stop and say why** when:
   - **Detached HEAD:** `git -C <repo-root> symbolic-ref -q HEAD` fails.
   - **An operation is in progress:** `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, or a `rebase-merge/` / `rebase-apply/` directory exists (`resolve-conflicts` › *Step 0 — Detect the Operation, the Sides and the Repo*). Route to [`/resolve-conflicts`](../../resolve-conflicts/SKILL.md), except a **resolved merge**: `MERGE_HEAD` exists and `git diff --name-only --diff-filter=U` is empty. Conclude it per [resolved-merge.md](resolved-merge.md).
   - **Protected/default branch** and **nothing to commit and nothing to push:** as in Step 1. Count what is waiting to be pushed with `git -C <repo-root> rev-list --count @{u}..HEAD 2>/dev/null`.

## Step 6: upstream

Run each as its own Bash call:

1. `git -C <repo-root> rev-parse --abbrev-ref HEAD` gives the branch `<BR>`.
2. `git -C <repo-root> rev-parse --abbrev-ref --symbolic-full-name @{u}` gives the upstream. It fails when none is set.
3. When the upstream is `origin/<BR>`, run `git -C <repo-root> push`. Otherwise, or when step 2 failed, run `git -C <repo-root> push -u origin HEAD`.

After the push, read it back with `git -C <repo-root> rev-list --count @{u}..HEAD` (expect `0`) and `git -C <repo-root> rev-parse --abbrev-ref --symbolic-full-name @{u}` (expect `origin/<BR>`).
