# fan-out

Shared protocol for Commands that fan out across parallel read-only sub-agents (`code-review`, `pr-feedback-review`, `squash-code-review`, `spec-verification`, `explain`, `suggestion`, `verify-assumptions`, `implement-feature`, and the *Speed fan-out* steps of `investigate`, `plan`, `pr-desc`, `what-am-I-missing`, `manual-testing`, `pr-fix-pipeline`, bare `suggestion` Step 4, `code-review` Steps 5b and 6c and `pr-feedback-review` Step 3), plus the one Command that fans out edits (`proceed`, *Edit lanes*).

## Modules

Read these before using this one:
- [core.md](core.md) (same folder as this file)

---

## Bare vs deep

- **Bare** (default): single-agent pass. Answers in chat when the Command's bare mode is chat-only (`explain`, `suggestion`, `what-am-I-missing`), or writes the Command's artifact directly.
- **`deep`**: spawns one read-only sub-agent per axis, vector, or claim batch, then aggregates into the Command's artifact.
- **Suggest, never switch silently.** When bare mode hits a scope that warrants `deep` (e.g. a cross-cutting architectural question or >10 claims), answer in bare mode and suggest re-running with `deep`. Never upgrade to `deep` unasked.

## Speed fan-out

A step that does several independent reads in a row can run them in parallel lanes in bare mode too, when the Command's SKILL.md names that step. This changes only wall-clock time: the output shape, artifacts and gates stay those of bare mode, so it is not an upgrade to `deep`.

- **Only where named.** Fan out only the steps the Command names, and only above the size threshold it names. Below it, run inline: spawning costs more than it saves. Run inline too when the host or the user's rules forbid spawning agents unasked.
- **Lanes.** At most 4 per step, so a later lens or verifier still fits the cap of 5. Lanes run on Sonnet (in Claude Code pass `model: "sonnet"` to the Agent tool, and `subagent_type: "Explore"` for search-only lanes; elsewhere use the host's default). Synthesis stays on the session model.
- **Brief.** The *Brief contract* applies, plus the lane's narrow question, what the lead already knows (so the lane does not re-read it), and the return format: findings only, each tagged ✅ Verified (`path:line`), 🟡 Inferred or ❓ Unknown, with no file dumps or pasted code.
- **Nested calls stay inline.** When the Command runs inside a sub-agent, or is called from a step that already fanned out (`code-review` Step 6c calling `what-am-I-missing`), do the step inline.
- **Aggregation.** As in *Aggregation*, except that the lead re-opens only the load-bearing citations: the ones the recommendation, options, PR body or #1 finding rests on.

## Review lenses

The *Speed fan-out* for checklist reviews: `plan` self-review and `--review`, `what-am-I-missing`, and `investigate` Step 6. Instead of walking every pillar or vector in the main context, the lead spawns 3 lens sub-agents in one message, each owning one group of the checklist:

| Checklist                                                          | Lens 1                                          | Lens 2                                                              | Lens 3                                         |
| ------------------------------------------------------------------ | ----------------------------------------------- | ------------------------------------------------------------------- | ---------------------------------------------- |
| `plan/references/review.md` › five pillars                         | 1 Architecture & domain modeling, 2 Project conventions | 3 Security, authorization & access rules, 4 Edge cases, resilience & invariants | 5 Verification & testing                       |
| `what-am-I-missing/references/vectors.md` › 7 vectors              | 1 Persistence, 2 Concurrency                    | 3 Boundaries, 4 Security, 7 Leaky abstractions                      | 5 Operational realities, 6 Testing realities   |

- **Brief.** The artifact under review by path (the plan file, or the target written to `<scratchpad>/lens-target.md` when it is not a file), the rulebook, Reference and profile paths the lead resolved, the lens's checklist items verbatim from the reference, and the severity scale. Leave out the author's reasoning and the conversation: the lens reviews what is written, not how it was reached.
- **Return.** Each finding with its severity, its `path:line` or plan section, and a one-line fix; or `none`.
- **Lead.** Dedupes across lenses by `path:line`, re-opens the load-bearing findings, then folds or ranks them per the Command. The lead remains the only author of the plan or answer.
- **Inline threshold.** Review inline when the target is small: a plan whose _Proposed Changes_ names a single file, or a single snippet or one-line decision. Also review inline when the host or the user's rules forbid spawning agents unasked, and write "inline review" where the verdict is reported.

## Edit lanes

The only exception to *Read-only* in the *Brief contract*, and only where a Command names it (`proceed` Step 2). It applies a list of already-approved fixes in parallel; it never decides what to change.

- **When.** At least 3 approved items that fall into at least 2 groups sharing no file. Keep a group together when its items touch the same file, a migration, a generated artifact or snapshot, or both sides of a contract (producer → consumer order). Below the threshold, or when everything lands in one group, edit inline.
- **Lanes.** At most 4, one per file group, spawned in one message as `general-purpose` sub-agents on Sonnet (`model: "sonnet"`), all in the same worktree or checkout. No `isolation: "worktree"`: the groups share no file, so they cannot conflict.
- **Brief.** The plan or artifact path and the item numbers this lane owns, quoted verbatim; the exact files it may edit; the References and profile rules that apply; `[worktree-context]` when active. It states: *"Edit only the listed files. No commits, pushes, worktrees, outward writes, installs, builds or test runs. Return each item number with the files you changed and one line on what changed, or why you could not apply it."*
- **Lead.** Runs `git -C <repo-root> diff --stat` and stops if any file outside the lanes' lists changed. Starts the Command's slowest verification command with `run_in_background` as soon as the lanes return, then reads every hunk against its item while it runs, fixes or reverts what is wrong, and re-runs only the commands whose files the fixes touched. The lead stays the only author of status fields and the chat reply.

## Brief contract

1. **Resolve target and scope first.** The lead agent resolves the PR, diff base, work items, profiles, and snapshot/workspace before spawning anything. Sub-agents never resolve scope or create/remove worktrees.
2. **Spawn in one message.** Launch all sub-agents in parallel in a single turn (cap at 5 per `MY-RULES.md`).
3. **Read-only.** Every sub-agent brief states: *"Read-only. Make no file edits, commits, worktrees, or outward writes. Cite every claim as `path:line`."*
4. **Paste `[worktree-context]` verbatim.** When a snapshot or workspace worktree is active (`git-worktrees` › *The `[worktree-context]` Block*), include the block in every brief and require paths mapped back to `workspace-path`.

## Aggregation

- **Sub-agent output is evidence, not a verdict.** Re-open every cited `path:line` yourself before including a finding or claim in the artifact or chat. Drop anything that does not hold up on inspection.
- **Deduplicate and reconcile.** Merge overlapping findings across axes into the strongest single entry; when two sub-agents disagree on the same code or claim, verify against the source and state the resolution (or flag the disagreement).
