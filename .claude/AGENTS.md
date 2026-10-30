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

## Agent skills

### Issue tracker

Issues are tracked as GitHub Issues on snuffish/dotfiles via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage labels are used as-is: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Skills registry

Local skill registry is in `skills/`. Run `python3 -I skills/sync-skills/sync_skills.py` to lint and sync loader symlinks. See `skills/README.md`.

@~/.claude-mem/MY-RULES.md
