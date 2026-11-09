<!-- CODEGRAPH_START -->

## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists in the working directory or any parent directory — e.g. a workspace root above several git repos), use its **lean commands** to locate code and trace call flows. They return about 1 KB each. `codegraph explore` returns about 25 KB per call, mostly source code; use it only when you want one fast overview and the token cost doesn't matter.

1. **Map:** `codegraph context --no-code -n 10 "<symbols>"` returns entry points with file:line.
2. **Walk:** `codegraph callees <sym> -f <file>` and `codegraph callers <sym> -f <file>` for each level (MCP: `codegraph_callers`), `codegraph query <name>` (MCP: `codegraph_search`), and `codegraph node -f <file> --symbols-only`.
3. **Read:** only the line ranges you need, with `Read` offset/limit or `codegraph_node` with `file`, `offset` and `limit`.

Use grep for what the graph doesn't connect: DI/startup wiring, implicit pipeline steps, enum-member usages and config files. A project CLAUDE.md may add repo-specific gaps.

If no `.codegraph/` directory exists there or in any parent, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- End every plan with these two blocks, in this order, so they are the last thing visible in the terminal:
  1. **Steps:** a numbered list of concrete steps.
  2. **Unresolved questions:** what I must decide, each with your recommendation. Leave this block out when there are none.

## Commit workflow

- When the user asks to commit or push, commit immediately. Do not wait on test runs or formatting unless the user asks for them. If tests or format are pending, say so in one line and continue.
- Never create a git worktree unless explicitly asked; work on the current branch.
- Split unrelated changes into separate logical commits and push to the current branch's upstream.

## Git & Branch Isolation

- For multi-file bug investigations, flaky test repairs, or new features, prefer isolated git worktrees (`/worktrees`) to keep the primary checkout clean.
- Before formulating a fix plan for a reported defect, check recent commits on active PR branches (`git log -n 5 --oneline origin/main..HEAD`) to verify the defect is not already resolved upstream.

## Handoffs (/proceed workflow)

- Every handoff step ends by writing the next-step handoff document. Do this without being asked.
- Handoff status lines must list every branch and PR involved (names + IDs). Re-read the status line before saving.
- Verify claims against real data (live PR, real directory, CI run) before marking a step done. If you can't, say explicitly what was only unit-tested.

## Bash Calls

- One simple command per Bash call: no `cd x;`, no `VAR=…;` prefix, no `;`/`&&` chains, no multi-line scripts. Allow rules match only simple commands, so compound ones always prompt.
- Use absolute paths or `git -C <dir>` instead of `cd`; use `quiet <cmd>` instead of `| tail`.
- Run build, pack, lint and format commands through `quiet`, or the quiet-guard hook rejects them.

## Friction becomes configuration

- Treat every correction, rejection or "why did you do that?" from me as a missing instruction, not a one-off. Treat a fix that worked the same way: if it lives only in this conversation, it is lost.
- After each round (a delivered answer, a failed command, a review I push back on), ask: what does this output reveal about the system that produced it? Which skill, rule, hook, setting or memory let it happen, or would have prevented it?
- Then make the change that removes the friction at its source, in the narrowest home that will be loaded next time: the skill's SKILL.md or references (a repo's own skill-gap process when it has one), a project AGENTS.md or rule file, a hook or `settings.json` entry, or a memory file. Prefer an automated check over prose when one can catch it.
- Name the change in one line at the end of the turn ("Recorded in X so it does not recur"). If the right home is unclear or the change is global, propose it and ask instead of guessing.

@~/.claude-mem/MY-RULES.md
