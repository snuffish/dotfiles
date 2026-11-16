# CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists in the working directory or any parent directory — e.g. a workspace root above several git repos), use its **lean commands** to locate code and trace call flows. They return about 1 KB each. `codegraph explore` returns about 25 KB per call, mostly source code; use it only when you want one fast overview and the token cost doesn't matter.

1. **Map:** `codegraph context --no-code -n 10 "<symbols>"` returns entry points with file:line.
2. **Walk:** `codegraph callees <sym> -f <file>` and `codegraph callers <sym> -f <file>` for each level (MCP: `codegraph_callers`), `codegraph query <name>` (MCP: `codegraph_search`), and `codegraph node -f <file> --symbols-only`.
3. **Read:** only the line ranges you need, with `Read` offset/limit or `codegraph_node` with `file`, `offset` and `limit`.

Use grep for what the graph doesn't connect: DI/startup wiring, implicit pipeline steps, enum-member usages and config files. A project CLAUDE.md may add repo-specific gaps.
