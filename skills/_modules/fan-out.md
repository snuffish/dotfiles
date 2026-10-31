# fan-out

Shared protocol for Commands that fan out across parallel read-only sub-agents (`code-review`, `pr-feedback-review`, `squash-code-review`, `spec-verification`, `explain`, `suggestion`, `verify-assumptions`, `implement-feature`).

## Modules

Read these before using this one:
- [core.md](core.md) (same folder as this file)

---

## Bare vs deep

- **Bare** (default): single-agent pass. Answers in chat when the Command's bare mode is chat-only (`explain`, `suggestion`, `what-am-I-missing`), or writes the Command's artifact directly.
- **`deep`**: spawns one read-only sub-agent per axis, vector, or claim batch, then aggregates into the Command's artifact.
- **Suggest, never switch silently.** When bare mode hits a scope that warrants `deep` (e.g. a cross-cutting architectural question or >10 claims), answer in bare mode and suggest re-running with `deep`. Never upgrade to `deep` unasked.

## Brief contract

1. **Resolve target and scope first.** The lead agent resolves the PR, diff base, work items, profiles, and snapshot/workspace before spawning anything. Sub-agents never resolve scope or create/remove worktrees.
2. **Spawn in one message.** Launch all sub-agents in parallel in a single turn (cap at 5 per `MY-RULES.md`).
3. **Read-only.** Every sub-agent brief states: *"Read-only. Make no file edits, commits, worktrees, or outward writes. Cite every claim as `path:line`."*
4. **Paste `[worktree-context]` verbatim.** When a snapshot or workspace worktree is active (`git-worktrees` › *The `[worktree-context]` Block*), include the block in every brief and require paths mapped back to `workspace-path`.

## Aggregation

- **Sub-agent output is evidence, not a verdict.** Re-open every cited `path:line` yourself before including a finding or claim in the artifact or chat. Drop anything that does not hold up on inspection.
- **Deduplicate and reconcile.** Merge overlapping findings across axes into the strongest single entry; when two sub-agents disagree on the same code or claim, verify against the source and state the resolution (or flag the disagreement).
