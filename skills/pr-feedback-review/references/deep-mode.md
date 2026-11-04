# PR Feedback Review Deep Mode — Axis Briefs

On-demand reference for [SKILL.md](../SKILL.md) › *Deep Mode*. Follow [fan-out.md](../../_modules/fan-out.md) for the brief contract and aggregation rules.

---

1. **Complete Steps 1–2 in the lead agent first** — PR(s) resolved, votes and threads fetched and saved to the scratchpad dump (with selected code snippets), snapshot(s) created and compared against the local checkout.
2. **Spawn the three axis sub-agents in parallel** (`fan-out` › *Brief contract*). Each prompt includes the snapshot's `[worktree-context]` block, `git -C <snapshot> diff origin/<target>...HEAD`, the commit list, the path to the thread dump, and its axis brief (keyed by thread ID):
   - **Verification**: *"For every thread in the dump: what does the code at head do about it? Classify as fixed / partial / not addressed / superseded. Cite the commit and `path:line` at head (re-find moved lines), and name the test that pins it, or say there is none. Where the reviewer asked for something specific (a test, a doc line, an overload), check that exact thing exists. Return one entry per thread with its citation."*
   - **Merit**: *"For every thread: is the reviewer's claim correct, and is their proposed fix the right fix? Judge independently against the code and framework semantics. Try to refute both the reviewer and the current implementation. Flag proposals that would introduce a defect, claims the code already handles, and implied sibling locations. Return one entry per thread with its citation."*
   - **Impact**: include the list of artifacts in the artifact dir for this PR. *"For every thread that proposes a change: what else does it touch? Stacked branches off this PR, linked work items, cross-repo contracts, other callers, conflicts between threads, and decisions recorded in existing artifacts. Also compare the live PR description with the threads and diff to flag stale claims. Return one entry per thread plus stale description claims."*
3. **Aggregate** (`fan-out` › *Aggregation*): re-open every cited `path:line` yourself before setting *State at head*, join the three reports per thread, assign the Step 4 category, decide Path A/B, draft replies (explaining the concrete failing sequence whenever Merit refutes a reviewer claim), write the artifact, and remove the snapshot(s).
