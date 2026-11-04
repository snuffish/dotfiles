# outward-writes

Shared safety contract for Commands that write to a remote git remote, PR host, or issue tracker (`commit`, `pr-summary`, `pr-desc`, `pr-post-comments`, `create-ticket`), plus _Voice pass_ for Commands that draft text other people will read (`pr-feedback-review`, `pr-polish`, `implement-feature`, `priis-prod-diagnose`). Extends `core` › _The `/proceed` gate_ rule 2.

## Modules

Read these before using this one:

- [core.md](core.md) (same folder as this file)

---

## Explicit request & draft mode

- Outward writes (commits, pushes, PR creation or description/title/label updates, PR comment or reply posts, tracker item creation) require an explicit request for that action.
- Preview / draft is the default whenever the Command supports a preview mode (`pr-summary`, `create-ticket`, `pr-post-comments --dry-run`): render the exact payload first and write only when asked.

## Voice pass

Prose a person will read under the user's name (PR thread replies, review comments, PR descriptions, ticket bodies, tracker comments, a reply to whoever asked) goes through `/unslop` before the user sees the preview. This holds for every such draft, including one written outside the Commands listed above (for example thread replies drafted after `/fix-findings`); and when the user asks to "unslop" an outward draft, they mean this pass, not a bare `/unslop rewrite`:

1. **Swedish prose**: `/unslop mimic <text>`. It drafts in the taught voice card (`~/.claude/skills/unslop/.unslop/voice/snuffish-sv/`) and must pass every removal gate, as the rule section of `~/.claude/skills/unslop/references/commands/mimic.md` says.
2. **Other languages**: `/unslop rewrite <text>`. The only voice card is Swedish, and mimic would push English text toward Swedish habits.
3. **Prose only**: keep code blocks, diffs, `path:line`, SHAs, IDs, commands, links, template headings and checkbox lists exactly as they are. If the pass changes a fact, a number or a quoted identifier, drop that change.
4. **Once per text**: run it on the final draft, in the skill that writes the draft. Mark the draft `Voice pass: done (mimic)` or `Voice pass: done (rewrite)` in its artifact so the posting skill skips it and can fill the spec's `"voice_pass"` (`pr-post-comments` › _Step 4_). If the user revises the text, run the pass again.
5. **Optional**: if `/unslop` is not installed, or the pass keeps failing its gates, keep the original draft, say so in the preview, and record `skipped: <reason>`. Never block a write on a pass that could not run; only an unrecorded pass blocks one.

## Denied write is final

- If the user declines a confirmation or denies a tool call that performs an outward write, **stop immediately**. Never retry the write through another tool, script, or CLI flag.

## Auth error vs denial

- An authentication, token-scope, or transport error from an MCP tool or CLI (`401`, `403`, `TF400813`, missing extension) is **not** a user denial.
- Switch to the alternate route (`pr-host` › _Tool: MCP vs CLI_). If both MCP and CLI fail with auth/transport errors, keep any local draft intact and hand the user the exact command to run themselves.

## Read back

- After every outward write succeeds, read back the created or updated remote state (commit SHA / remote ref, PR title/description/labels, posted thread/comment IDs, created work-item ID and URL) and record it in the source artifact (under `artifact-protocol` › _Rules_ › rule 3 & rule 7) and in the chat response.
