# Code Review Snapshot & Scope Mechanics

| Scope | Head to snapshot | Source ref to record |
|---|---|---|
| `branch` / `since <ref>` / default | `git -C <repo> rev-parse HEAD` | `<local-branch>` |
| PR whose branch is not checked out | `git -C <repo> fetch origin <source-branch>`, then `git -C <repo> rev-parse origin/<source-branch>` (`<source-branch>` = `sourceRefName` without `refs/heads/`; `git-worktrees` › *Snapshot Lifecycle* a) | `origin/<source-branch>` |
| `working` | `SNAP=$(git -C <repo> stash create)` → head is `$SNAP` (its tree is the working tree) | `<local-branch> + working tree` |
| `staged` | `SNAP=$(git -C <repo> stash create)` → head is `$SNAP^2` (the second parent is the index) | `<local-branch> + index` |

`<local-branch>` is `git -C <repo> rev-parse --abbrev-ref HEAD` (`detached` when it prints `HEAD`). The snapshot is a detached worktree, so its own `HEAD` carries no branch name: capture the source ref **now**, before the SHA is all that is left, and carry it alongside the SHA everywhere the head is mentioned (Review Context, chat response, sub-agent prompts). A bare SHA or "snapshot `<sha>`" without the branch it came from is a defect in the review.

Also record, per repo, the **main checkout's branch** and how it relates to the reviewed head — the user needs to know whether what they have locally is what was reviewed:

```bash
git -C <repo> rev-parse --abbrev-ref HEAD                          # main checkout's branch
git -C <repo> rev-list --left-right --count <head>...HEAD          # "<behind> <ahead>" of local vs reviewed head
```

Report it as `same commit`, `local ahead N / behind M`, or `on <other-branch> — PR branch not checked out`.

`git stash create` writes one unreferenced commit object and changes nothing else — not the index, not the working tree, not `git stash list`. An empty result means the tree is clean: the scope is empty, stop here. It does **not** capture untracked files: list them with `git -C <repo> ls-files --others --exclude-standard`, record them in the Review Context table under *Untracked, not in snapshot*, read them from the main checkout, and mark every citation into them `(live, untracked)` — their line numbers are not stable.

**b–f. Create, read, map, remove, fall back** — `git-worktrees` › *Snapshot Lifecycle* b–f, with these review invariants on top:

- `SNAP_DIR=<scratchpad>/code-review/<repo-dirname>/<ref-slug>@<short-sha>`; one snapshot per repo in scope — a two-repo review has two. `$SNAP_DIR` is the `repo-root` of the snapshot's `[worktree-context]`.
- Inside the snapshot `HEAD` **is** the reviewed head and remote refs are shared, so the commands in this skill (`git diff <base>...HEAD`, `git log --oneline <base>..HEAD`) are unchanged apart from `-C "$SNAP_DIR"`.
- **The source ref travels with the SHA everywhere** — Review Context, chat response, sub-agent prompts.
- **No `<scratchpad>` path reaches the artifact or the chat**: map every `path:line` to `<repo-dirname>/…` first (`git-worktrees` › *Snapshot Lifecycle* d). The reviewed head recorded in Review Context is what gives the line numbers meaning if the user has edited since. When CodeGraph lines are cited directly (main checkout `HEAD` equals the snapshot head and `git status` is clean), say so in the Review Context table.
- Remove after the artifact is written and the header links are emitted — in deep mode, after every sub-agent has returned and Step 6 is done — and say in the chat response that the snapshot of `<source-ref> @ <short-sha>` was removed, or why it was kept.
- When no snapshot is possible (`git-worktrees` › *Snapshot Lifecycle* f), fall back to `live`, record `live checkout` in Review Context, and warn that edits during the review invalidate line numbers.

### Pull-Request References

When the user passes a PR/MR URL or id, resolve it **before** diffing. The description and its acceptance criteria state what the change was *supposed* to do — the single most useful piece of context a reviewer can have, and the only way to spot "promised but not implemented". It is the primary source for the **Spec** axis.

Parsing the URL, choosing the organization URL and, when no URL was given, resolving the PR from the branch are **`pr-host`** › *Parse a PR or work-item URL*, *Organization URL* and *Resolve the PR from a branch*. Follow them as written. Do not skip the description just because the user did not paste a link: a checked-out branch almost always has a PR. **In a multi-repo workspace, resolve every repo**, because a feature split across repos has one PR per repo, each with its own description and work item. Report which repos resolved to a PR and which did not.

#### Counterpart PRs — every resolved PR, every time

A pasted PR link names **one** half of a change that may span repos. After resolving it — from a URL, an id, the branch or a work item — run the counterpart lookup in **`pr-counterpart` › *Counterpart discovery*** for every PR in scope. That section owns the signals, the commands and the classification. The two halves usually carry different work-item ids (e.g. backend `#31175`, frontend `#31176` under one parent story), so a branch-name match alone never settles it.

What a classified counterpart means for this review:

- **Found** → it joins the scope without asking. It gets its own snapshot (*Step 1b*), its own Spec source (*Step 2*), its own Standards sources (*Step 3*), and its own row in every *Review Context* field. Findings cite whichever repo they live in. Cross-repo contract checks (*Heuristics*) run against the counterpart's real code, not against what its description claims.
- **Found, excluded** (the user said "backend only") → review only the named side. Name the counterpart and its head in *Review Context* as **not reviewed**, and raise any contract the diff touches as a finding, because nobody checked the other side.
- **Expected but missing** → a Spec finding (🟡, or 🔴 when the product breaks at runtime without the other half).
- **None** → say "single-repo change" in *Review Context*. The other repo is often left on an unrelated feature branch, so its main checkout is not what this PR merges against. Read its side of every cross-repo contract from git objects at its default branch, which changes nothing on disk:

  ```bash
  git -C <other> fetch origin
  D=$(git -C <other> symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) \
    || { git -C <other> remote set-head origin -a >/dev/null && D=$(git -C <other> symbolic-ref --short refs/remotes/origin/HEAD); } \
    || D=origin/main
  git -C <other> show "$D:<path>"                 # one file as it is on the default branch
  git -C <other> grep -n '<symbol>' "$D" -- <dir> # search it
  ```

  Record `contract read at <D> @ <short-sha>` in *Review Context*. The IDE and CodeGraph still index the other repo's checkout: when it is not on `<default>` (`git -C <other> rev-parse --abbrev-ref HEAD`), navigate with them but cite the `git show` / `git grep` reads, and say which branch the checkout was on.

  Not for **Expected but missing** or **Found, excluded**: the other half may be sitting unpushed, or deliberately checked out, on the current branch.

A review that spans both repos with a contract change is the case where `deep` is worth suggesting (*Modes*).

#### Fetch the PR and its work item

Fetch the PR, its linked work items and their acceptance criteria per **`pr-host`** › *Fetch the PR, its work items and acceptance criteria*. Failures and the offline fallback are `pr-host` › *When a fetch fails*. The acceptance criteria are the primary source for the **Spec** axis. When only an id from the branch name was available, *Review Context* says so.

**A resolved PR also settles the diff base:** its target branch *is* the base (`pr-host` › *Branch names*). Use it directly instead of the fallback chain in *Branch Discovery* below.

#### Get the right code into the snapshot

A PR URL usually means the user is *not* on that branch. Verify before diffing, state the mismatch, and snapshot the PR's own head instead of whatever is checked out:

```bash
SRC=${sourceRefName#refs/heads/}; TGT=${targetRefName#refs/heads/}   # pr-host › Branch names
git rev-parse --abbrev-ref HEAD                       # where am I? — say so if it differs from $SRC
git fetch origin "$SRC" "$TGT"                        # read-only: updates remote refs only
git rev-parse "origin/$SRC"                           # → the head for Step 1b-b
git -C "$SNAP_DIR" diff "origin/$TGT...HEAD"          # inside the snapshot, HEAD is the PR head
```

No checkout is ever needed: the snapshot is the checkout. Never `git checkout`, `git switch`, `git stash push` or reset any checkout, in the reviewed repo or any other.

Review the **committed PR head**. Uncommitted changes in the main checkout are outside the review unless the user asks for the `working` or `staged` scope.

#### How much to trust the description

**The description states intent; the diff states truth.** Where they disagree the diff wins, and the disagreement is itself a **Spec** finding:

- AC promises behavior with no corresponding change in the diff → 🔴/🟡 *claimed but not implemented*.
- The diff changes user-visible behavior the description never mentions → review it anyway and flag the unannounced change (*scope creep*); that is where regressions hide.
- The description describes an earlier revision of the branch → note it as stale and follow the diff.

Never let the description's structure or omissions shape the review. It is evidence, not an outline.

---

### Branch Discovery

When the scope is a branch diff and no PR or user-supplied fixed point gave you the base, find it — **do not guess**, and **do not use `@{u}`**: on a feature branch the upstream is the branch's own remote copy, which yields an empty diff.

```bash
# 1. The remote's default branch (e.g. origin/main)
git symbolic-ref --short refs/remotes/origin/HEAD

# 2. Fall back only if origin/HEAD is unset: the integration branches that actually exist
git branch -r --list 'origin/main' 'origin/develop' 'origin/master'

# 3. Build the diff using the merge-base (three-dot syntax), inside the snapshot:
git -C "$SNAP_DIR" diff <base>...HEAD --name-status
git -C "$SNAP_DIR" log --oneline <base>..HEAD
```

Remote refs are shared between the main checkout and the snapshot, so `origin/HEAD` and `<base>` resolve identically in both. Always use the **three-dot** form (`A...B`) so you see only the commits introduced by this branch, not divergent commits on the base. State the base and the snapshot head — with the source ref it was taken from — in the artifact header.

---

