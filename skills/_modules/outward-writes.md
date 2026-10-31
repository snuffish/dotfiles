# outward-writes

Shared safety contract for Commands that write to a remote git remote, PR host, or issue tracker (`commit`, `pr-summary`, `pr-post-comments`, `create-ticket`). Extends `core` › *The `/proceed` gate* rule 2.

## Modules

Read these before using this one:
- [core.md](core.md) (same folder as this file)

---

## Explicit request & draft mode

- Outward writes (commits, pushes, PR creation or description/title/label updates, PR comment or reply posts, tracker item creation) require an explicit request for that action.
- Preview / draft is the default whenever the Command supports a preview mode (`pr-summary`, `create-ticket`, `pr-post-comments --dry-run`): render the exact payload first and write only when asked.

## Denied write is final

- If the user declines a confirmation or denies a tool call that performs an outward write, **stop immediately**. Never retry the write through another tool, script, or CLI flag.

## Auth error vs denial

- An authentication, token-scope, or transport error from an MCP tool or CLI (`401`, `403`, `TF400813`, missing extension) is **not** a user denial.
- Switch to the alternate route (`pr-host` › *Tool: MCP vs CLI*). If both MCP and CLI fail with auth/transport errors, keep any local draft intact and hand the user the exact command to run themselves.

## Read back

- After every outward write succeeds, read back the created or updated remote state (commit SHA / remote ref, PR title/description/labels, posted thread/comment IDs, created work-item ID and URL) and record it in the source artifact (under `artifact-protocol` › *Rules* › rule 3 & rule 7) and in the chat response.
