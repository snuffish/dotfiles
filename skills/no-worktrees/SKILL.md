---
name: no-worktrees
description: Runs a request in the user's own checkout, with no worktree or snapshot, even when the Command it routes to isolates by default (/code-review and /pr-feedback-review snapshot, /implement-feature uses a workspace worktree). Strips the `/no-worktrees` token wherever it sits in the prompt, routes a request that matches a registry Command to that Command with the opt-out token, and otherwise carries out the request in place. Trigger whenever a prompt contains `/no-worktrees` anywhere and invokes no other Command, or asks to do something "in my checkout", "without a worktree" or "in place". Not for isolating a request (/worktrees).
---

# Skill: `/no-worktrees` — Run a Request in Place

The in-place counterpart of [`/worktrees`](../worktrees/SKILL.md). It gives a plain prompt the `/no-worktrees` opt-out (`git-worktrees` › *Modes* › *Opt-out token*): no worktree, no snapshot, the work happens in the checkout the user is in.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — a Command it routes to writes its own
- `../_modules/git-worktrees.md`: for the opt-out token only; this skill creates no worktree

- **The token belongs to whoever was invoked.** When the prompt starts with another Command (`/code-review 123 /no-worktrees`), that Command handles the token under `core` › *Worktree opt-in*. This skill is not involved.
- **This skill adds no gates and lifts none.** The request keeps the gates it would have in a worktree: a plan before a non-trivial change (`core` › *Planning mode first*), and the routed Command's own gates. Pushing, creating or completing a PR, and posting to a host happen only when the user asks for them explicitly.
- **The user's checkout is theirs.** Before switching branches, merging, rebasing or resetting there, check `git status --porcelain`. With uncommitted changes, or on a branch the request does not name, ask first. Never stash, discard or overwrite their changes to make room.

---

## 1. When to Use

### When *not* to use

- The prompt starts with another Command. That Command handles the token.
- The work already lives in a kept worktree. It stays there; resume it with [`/continue`](../continue/SKILL.md).
- The user wants the request isolated. That is [`/worktrees`](../worktrees/SKILL.md).

---

## 2. Core Protocol & Workflow

### Step 1: Parse the prompt

1. Remove every `/no-worktrees` token. What remains is the **request**.
2. **Also `/worktrees` in the prompt:** the two contradict each other. Ask which one applies, then stop.
3. **No request (bare `/no-worktrees`):** say in one line that the token runs the next request in place, for example `/implement-feature 1234 /no-worktrees`, then stop.

### Step 2: Route

| The request | Route |
|---|---|
| Names a registry Command or matches its trigger ("review PR 123" → `code-review`, "implement #1234" → `implement-feature`) | Invoke that Command with the request plus the token `/no-worktrees`. Report only that the request was routed. |
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
