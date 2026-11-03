# artifact-protocol

How every Command names, places, claims, and links markdown artifacts at the workspace root.

---

## Artifact Location, Host & Model Prefix Resolution & Mandatory Contextual Suffix

Claude Code and Antigravity IDE share one workspace root, and multiple sessions or models may work on the same repo concurrently or consecutively. Every artifact uses a host+model prefix, a contextual suffix, and an atomic session-ownership claim so no session ever overwrites another's file:

```text
<workspace-root>/<host>-<model>-<base_artifact_name>-<suffix>.md
```

When the session runs inside a linked git worktree (`.claude/worktrees/<name>`, detected via `git rev-parse --git-dir` ≠ `--git-common-dir`), `<workspace-root>` is the **main workspace root** above `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")`, never the linked worktree directory.

### Rules:
1. **Resolve Prefix (`<host>-<model>-`) Once Before Writing**:

| Running as | System Prompt Indicator | Active Model Indicator | Prefix (`<host>-<model>-`) |
|---|---|---|---|
| Claude Code | *"You are Claude Code"* | Model in system prompt (e.g. Opus 5.5 → `opus-5.5`; fallback `claude`) | `claude-<model>-` |
| Antigravity IDE | *"You are Antigravity"* | Model in user settings/context (e.g. `gemini-4-argon`; fallback `gemini`) | `antigravity-<model>-` |
| Any other host | *(none of above)* | Active model | `<host>-<model>-` |

2. **Mandatory Contextual Suffix (Anti-Overwrite Invariant)**:
   - Always append a descriptive kebab-case `-<suffix>` (never write unsuffixed files).
   - Derivation priority: (1) **Work Item / PR / Ticket ID + Slug** (`-18176-verksamhetsobjekt`), (2) **Branch or Feature Name** (`-new-users-audit`), (3) **Topic / Task Descriptor** (2–4 words, `-ticket-category-config`).
3. **Ownership (No-Overwrite Invariant)**: a session may update an artifact only when **this session owns it** (proven by the `artifact-owner` marker from *Claim*). Every other artifact — including earlier sessions of the same host and model — is read-only. Re-running in a new session claims the next free `-<n>` name. Only three exceptions exist:
   - **The user explicitly names the file and asks to update it** in this conversation. Re-read the file first and keep its owner marker unchanged.
   - **Record lines** defined by a Command (`/pr-post-comments` *Posted to PR*, `/create-ticket` ID line, `skill_gap` **Status** line).
   - **Status fields** declared by the artifact's Command (updated together under rule 7).
   A file with no owner marker is read-only unless created in this conversation.
4. **Claim (atomic create; counter on collision)**: draft in a session-private file (`<scratchpad>` or `mktemp`), with the owner marker on line 1:
   `<!-- artifact-owner: <host>-<model> · session <session-id> · created <ISO-8601 timestamp> -->`
   Then publish with `O_EXCL` (`set -C`):

   ```bash
   # $1 = draft file, $2 = target path without extension, $3 = extension (default: md)
   publish_new_artifact() {
     local ext="${3:-md}" p="$2.${3:-md}" n=1
     until ( set -C; cat "$1" > "$p" ) 2>/dev/null; do n=$((n + 1)); p="$2-$n.$ext"; done
     printf '%s\n' "$p"
   }
   ```

   - **Collision counter**: `<name>.md`, `<name>-2.md`, `<name>-3.md`, …. If a counter was added, note in chat that the base name belongs to another session.
   - **Later updates by the owner**: edit in place and re-run `grep -n` for section anchors.
   - **Readers & family selection**: treat `<name>.md`, `<name>-2.md`, … across all `<prefix>` values as one family. When one family matches the current branch/PR/ticket, pick the newest by `created` timestamp (else mtime); when multiple families or ambiguous candidates exist, list them (branch match first as `(Recommended)`) and ask the user.
   - **Independence rule**: when writing a review or verification artifact (`code-review`, `spec-verification`), produce your own findings **before** reading another model's or session's artifact for the same target so the audit stays independent (unless the user explicitly asked to reconcile or `/squash-code-review`).
5. **Single Identity Rule**: never write multiple host/model variants in one turn.
6. **Clickability Rule**: write directly to `<workspace-root>`. Exceptions: `skill_gap` files in `~/.terminal/skill-gaps/` (`core` › *Skill gaps*) and `/export-file` outputs (`export-<suffix>.<ext>` in cwd or user-specified path).
7. **Status Sync Rule (no half-updated artifact)**: when recording progress (`Approved`, `Completed`, `🕓 Fixed, not pushed (<sha>)`, `✅`, posted thread IDs), update **every** status field the artifact's Command declares (header `Status:`, summary matrix, per-item status, checklist) in the same edit, then `grep` for stale markers (`⏸`, `Not addressed`, `uncommitted`) and resolve every hit. Preserve historical analysis with a dated note beside it.
8. **HTML Export Pipeline (`--html`)**:
   - Skills supporting `--html` (e.g. `/investigate --html`, `/export-file /html`) write the canonical markdown artifact `<prefix>-<base>-<suffix>.md` first, then compile its sibling `<prefix>-<base>-<suffix>.html` at the **workspace root** using the shared compiler:
     ```bash
     python3 ~/.terminal/skills/_modules/scripts/render_html.py <markdown-file> [<html-file>] --open
     ```
   - Markdown remains the lean, canonical AI source of truth for cross-session handoffs, diffs, and LLM reasoning.
   - The compiled `.html` sibling includes Tailwind CSS, Mermaid 11 ESM CDN for client-rendered diagrams, responsive typography, and auto-launches in the default browser via `--open` (`xdg-open` on Linux, `open` on macOS, `start` on Windows).
   - In chat output, link both files: `📄 [<artifact>.md](<link-to-md>) · 🌐 [<artifact>.html](<link-to-html>)`.

---

## Host-Specific Link Formats & Section Anchors

| Host | Chat Link Syntax | Example |
|---|---|---|
| **Antigravity IDE** | Absolute `file://` URI + `#L<line>` | `[<file>.md](file://<workspace-root>/<file>.md#L8)` |
| **Claude Code, IDE extension** (`$CLAUDE_CODE_ENTRYPOINT != cli`) | Workspace-relative path + `#L<line>` | `[<file>.md](<file>.md#L8)` |
| **Claude Code, terminal CLI** (`$CLAUDE_CODE_ENTRYPOINT = cli`) | `antigravity-ide://file/` + absolute path + `:<line>` (`%20` for spaces, no range) | `[<file>.md](antigravity-ide://file/<workspace-root>/<file>.md:8)` |

- **Section anchors in chat**: always point at a line number (`#L<line>` or `:<line>`), never a heading slug. Read actual line numbers after writing or editing:
  ```bash
  grep -n '^#\{1,3\} ' <artifact-path>
  ```
- **Intra-document links (inside markdown files)**: use `<a id="..."></a>` and `#anchor`, never `#L<line>`.
- **Cross-host reading**: always format links for your **own** active host.

## Chat link block

Every Command that writes or updates an artifact emits a compact link block in chat using the active host's link format above, and re-emits it after any edit that shifts line numbers:

```markdown
📄 [<artifact-filename>](<host-link-to-file>)
- [Section 1](<host-link-to-L1>) · [Section 2](<host-link-to-L2>) · [Section 3](<host-link-to-L3>)
```

---

## PR Discussion Thread Links & Canonical Artifact Catalog

- **PR Discussion Thread Links (Dual Navigation)**: see [references/pr-host-threads.md](references/pr-host-threads.md) › *PR Discussion Thread Links (Dual Navigation)*.
- **Canonical Artifact Catalog**: see [references/artifact-catalog.md](references/artifact-catalog.md).
