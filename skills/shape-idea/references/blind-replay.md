# Blind replay: proving a review-skill change

Read from [../SKILL.md › Step 5](../SKILL.md). Use it to plan how a change to a review skill (new pass, new agents, new mode) is shown to find more, not just written.

**The idea.** Re-run the review, old version and new version, on merged PRs that human reviewers already commented on. The human threads are the answer key: count how many of their points each version finds, how many wrong points it raises, and what it costs.

## Pick the PRs

- Merged, with several human review threads, and touching the area the change targets.
- The PRs the skill's own lessons or rules cite are the richest answer keys, and the most leaky ones (next section).

## Keep it blind

The rules were often written from those same threads, so a review that reads them unchanged has seen the answers.

1. **No PR id.** Review a local ref at the PR's head (`git branch replay/<id> <head-sha>`; the source branch may be gone), with `--base <lastMergeTargetCommit>` from the PR. A PR-mode run reads the threads and the description.
2. **Current skill, old code.** The PR head carries the skill files of its own time. Copy the branch's skill, rules and references over the review worktree's copies.
3. **Strip the citations.** In that copy, delete every line of the rules **and** lessons that cites the replayed PR ids (`grep -n '!<id>'`), and every entry the change itself adds that came from those PRs (a recorded rejection, an allow-list row). Both versions read the same stripped copy, so any leak left in paraphrased text affects both alike.
4. **Same switches.** Turn off steps the change does not touch (e.g. a browser click-through) in both runs.
5. **Agent definitions load from the session's checkout.** Run the replay from the branch that holds the new definitions.

## Score

| Column | Meaning |
|---|---|
| Thread hits | Human threads the run raised, of all human threads |
| Extra true | Findings no thread raised that the user judges real, each logged with one line of reason |
| False pos. | Findings the user judges wrong |
| Tokens | Summed `usage` from the run's main transcript and every sub-agent transcript (`<session-id>/subagents/*.jsonl`) |

A change that **removes** findings (suppression, filtering) adds two columns: *Blocking lost* (human Blocking threads the old version raised and the new one does not) and *False pos. removed*. Its bar weighs both: no Blocking lost.

Agree the bar before the runs (e.g. at least one extra true Blocking or Should-fix finding per PR, and no more false positives), and what happens when it is missed (drop the change, keep the parts that stand alone).

## Record

- Full comparison in an artifact in the artifact dir.
- One row per PR × version in the PR description, with the columns above.
