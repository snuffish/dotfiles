---
name: no-wt
description: "Directs commands to run directly in the working checkout without worktree or snapshot isolation. Use for /no-wt, \"run this in place\", \"without a worktree\", \"in my current checkout\"."
---

# Skill: `/no-wt` — Run a Request in Place

The in-place counterpart of [`/wt`](../wt/SKILL.md). It gives a plain prompt the `/no-wt` opt-out (`git-worktrees` › *Modes* › *Opt-out token*): no worktree, no snapshot, the work happens in the checkout the user is in.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — a Command it routes to writes its own
- `../_modules/git-worktrees.md`: for the opt-out token only; this skill creates no worktree

- **This skill adds no gates and lifts none.** The request keeps the gates it would have in a worktree: a plan before a non-trivial change (`core` › *Planning mode first*), and the routed Command's own gates. Pushing, creating or completing a PR, and posting to a host happen only when the user asks for them explicitly.
- **The user's checkout is theirs.** Before switching branches, merging, rebasing or resetting there, check `git status --porcelain`. With uncommitted changes, or on a branch the request does not name, ask first. Never stash, discard or overwrite their changes to make room.

---

## 1. When *not* to use

- **The prompt starts with another Command** (`/code-review 123 /no-wt`): that Command handles the token under `core` › *Worktree opt-in*; this skill is not involved.
- **The work already lives in a kept worktree**: resume it there with [`/continue`](../continue/SKILL.md).
- **The user wants the request isolated**: use [`/wt`](../wt/SKILL.md).

---

## 2. Core Protocol & Workflow

### Step 1: Parse the prompt

1. Remove every `/no-wt` token. What remains is the **request**.
2. **Also `/wt` in the prompt:** the two contradict each other. Ask which one applies, then stop.
3. **No request (bare `/no-wt`):** say in one line that the token runs the next request in place, for example `/implement-feature 1234 /no-wt`, then stop.

### Step 2: Route

| The request | Route |
|---|---|
| Names a registry Command or matches its trigger ("review PR 123" → `code-review`, "implement #1234" → `implement-feature`) | Invoke that Command with the request plus the token `/no-wt`. Report only that the request was routed. |
| Matches several Commands in sequence | Route to the first. Say which Command picks up the rest. |
| Matches no Command | Carry it out here, in the current checkout, under the rules above. After any change, run the project's verify commands (`core` › *Post-edit verification*). |

---

## 3. Output Format & Deliverables

No artifact. When routed, one line naming the Command, then that Command's own output. When run here:

```markdown
**<repo-dirname>**: in place on `<branch>`
- Done: <what ran>
- Verify: <commands and result, or "not run: <reason>">
```

---

## 4. Verification & Validation

- No worktree was created: `git -C <repo> worktree list --porcelain` shows no new `claude-skill:` entry.
- No uncommitted change of the user's was stashed, discarded or overwritten.
- No push, PR or host write happened without an explicit ask.
