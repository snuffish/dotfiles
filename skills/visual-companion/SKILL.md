---
name: visual-companion
description: 'Shows mockups, diagrams and side-by-side options in a local browser tab or as ASCII previews in the terminal, and records the pick. Offer it, never start it unasked, during design or plan work when seeing an option beats reading it. Use for /visual-companion, "show me", "mock it up", "side by side". Not for the design conversation itself (use /brainstorming) or writing a plan (use /plan).'
argument-hint: "[browser|terminal] <what to show>"
---

# Visual Companion Guide

Companion for showing mockups, diagrams, and options in a browser tab or in the terminal.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these first:

- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: resolves the artifact dir for `--project-dir`; writes no artifact

On-demand references (`references/`):

- [references/screens.md](references/screens.md) — content fragments, CSS classes, events format, design tips, file naming

---

## The offer

Never start a session unasked. Ask once with one AskUserQuestion: **browser**, **terminal**, or **decline**.

- Skip the question when the user typed a medium (`/visual-companion browser …`) or already said yes to a calling skill's offer.
- Declined → don't offer again this session unless the user raises it.

## When to Use

Decide per-question, not per-session. The test: **would the user understand this better by seeing it than reading it?**

**Show it visually** when the content itself is visual:

- **UI mockups** — wireframes, layouts, navigation structures, component designs
- **Architecture diagrams** — system components, data flow, relationship maps
- **Side-by-side visual comparisons** — comparing two layouts, two color schemes, two design directions
- **Design polish** — when the question is about look and feel, spacing, visual hierarchy
- **Spatial relationships** — state machines, flowcharts, entity relationships rendered as diagrams

**Use plain chat** when the content is text or tabular:

- **Requirements and scope questions** — "what does X mean?", "which features are in scope?"
- **Conceptual A/B/C choices** — picking between approaches described in words
- **Tradeoff lists** — pros/cons, comparison tables
- **Technical decisions** — API design, data modeling, architectural approach selection
- **Clarifying questions** — anything where the answer is words, not a visual preference

A question *about* a UI topic is not automatically a visual question. "What kind of wizard do you want?" is conceptual — use chat. "Which of these wizard layouts feels right?" is visual — show it.

## Terminal mode

No server. Each visual question is one AskUserQuestion:

- 2–4 single-select options per question, each with an ASCII mockup in `preview` (monospace markdown).
- `preview` works on single-select questions only; the tool adds "Other" itself; at most 4 questions per call.
- Monospace only. When the question needs colour, fonts or clicks, suggest browser mode once.
- The answer (plus any notes) is the pick.

## Switching

Change medium only when the user says so. Stop the server first when leaving browser mode (*Ending*).

## How It Works (browser mode)

The server watches a directory for HTML files and serves the newest one to the browser. You write HTML content to `screen_dir`, the user sees it in their browser and can click to select options. Selections are recorded to `state_dir/events` that you read on your next turn.

**Content fragments vs full documents:** If your HTML file starts with `<!DOCTYPE` or `<html`, the server serves it as-is (just injects the helper script). Otherwise, the server automatically wraps your content in the frame template — adding the header, CSS theme, connection status, and all interactive infrastructure. **Write content fragments by default** ([references/screens.md](references/screens.md)).

## Starting a Session

`scripts/` sits beside this SKILL.md; run every script as `<skill-dir>/scripts/<name>`, where `<skill-dir>` is this file's folder (never relative to the user's checkout).

`--project-dir` is mandatory and is always the artifact dir (`artifact-protocol` › *Artifact directory*). Never omit it: the `/tmp` fallback deletes mockups on stop.

```bash
# Start AFTER the user picks browser mode. --open auto-opens their browser on
# the first screen; --project-dir persists mockups and enables same-port restart.
bash <skill-dir>/scripts/start-server.sh --project-dir <artifact-dir> --open

# Returns: {"type":"server-started","port":52341,
#           "url":"http://localhost:52341/?key=ab12…",
#           "screen_dir":"<artifact-dir>/.superpowers/brainstorm/12345-1706000000/content",
#           "state_dir":"<artifact-dir>/.superpowers/brainstorm/12345-1706000000/state"}
```

Save `screen_dir` and `state_dir` from the response, and `<session-dir>`, the folder that holds both (the JSON has no field for it). With `--open`, the browser opens itself when you push the first screen — you don't need to ask the user to open it, but still share the URL as a fallback (headless/remote setups won't auto-open).

**The URL contains a session key (`?key=…`).** The server rejects any request
without it, so always give the user the **complete** URL from the `url` field —
never strip the query string, and never hand out a bare `http://host:port`. The
key gates HTTP and WebSocket access so a stray browser tab or another machine on
the network can't read the screens or inject events. After the first load the
browser remembers the key via a cookie, so reloads and `/files/*` assets work
without repeating it.

**Finding connection info:** The server writes its startup JSON to `state_dir/server-info`. If you launched the server in the background and didn't capture stdout, read that file to get the URL and port. Session directories live under `<artifact-dir>/.superpowers/brainstorm/`.

**Launching the server by platform:**

- **Claude Code:** default mode works — the script backgrounds the server itself. On Windows the script switches to foreground mode; use `run_in_background: true` on the Bash call, then read `state_dir/server-info` on the next turn.
- **Codex:** reaps background processes; the script detects `CODEX_CI` and switches to foreground mode. Run it normally.
- **Gemini CLI:** add `--foreground` and set `is_background: true` on the shell tool call.
- **Copilot CLI:** add `--foreground` and start it with Copilot CLI's background shell mechanism (on Windows, call Git Bash's `bash.exe` from the PowerShell tool).
- **Other environments:** the server must keep running across turns. If your environment reaps detached processes, use `--foreground` with your platform's background mechanism.

If the URL is unreachable from your browser (common in remote/containerized setups), bind a non-loopback host:

```bash
bash <skill-dir>/scripts/start-server.sh \
  --project-dir <artifact-dir> \
  --host 0.0.0.0 \
  --url-host localhost
```

Use `--url-host` to control what hostname is printed in the returned URL JSON.

## The Loop

1. **Check server is alive**, then **write HTML** to a new file in `screen_dir`:
   - **Required: confirm the server is alive before referring to the URL or pushing a screen.** Check that `state_dir/server-info` exists and `state_dir/server-stopped` does not. If it has shut down, restart it with `start-server.sh` using the **same `--project-dir`**. Every start creates a new session dir: take `url`, `screen_dir`, `state_dir` and `<session-dir>` from the restart's JSON, drop the old ones, and push the current screen again as a new file. The port and key usually carry over, so the open tab reconnects. The server auto-exits after 4 hours idle (configurable with `--idle-timeout-minutes`).
   - Use semantic filenames and never reuse one ([references/screens.md](references/screens.md) › *File Naming*)
   - Use your file-creation tool — **never use cat/heredoc** (dumps noise into terminal)
   - Server automatically serves the newest file

2. **Tell user what to expect and end your turn:**
   - Remind them of the URL (every step, not just first)
   - Give a brief text summary of what's on screen (e.g., "Showing 3 layout options for the homepage")
   - Ask them to respond in the terminal: "Take a look and let me know what you think. Click to select an option if you'd like."

3. **On your next turn** — after the user responds in the terminal:
   - Read `state_dir/events` if it exists ([references/screens.md](references/screens.md) › *Browser Events Format*)
   - Merge with the user's terminal text to get the full picture
   - The terminal message is the primary feedback; `state_dir/events` provides structured interaction data

4. **Iterate or advance** — if feedback changes current screen, write a new file (e.g., `layout-v2.html`). Only move to the next question when the current step is validated.

5. **Unload when returning to terminal** — when the next step doesn't need the browser, push a waiting screen to clear the stale content:

   ```html
   <!-- filename: waiting.html (or waiting-2.html, etc.) -->
   <div style="display:flex;align-items:center;justify-content:center;min-height:60vh">
     <p class="subtitle">Continuing in terminal...</p>
   </div>
   ```

6. Repeat until done.

## Ending

1. State the pick in chat. In browser mode, add the paths of the screen and `state_dir/events` it came from.
2. Browser mode only: stop the server.

   ```bash
   bash <skill-dir>/scripts/stop-server.sh <session-dir>
   ```

In browser mode, mockups stay in `<artifact-dir>/.superpowers/brainstorm/` for later reference. This skill writes no artifact; a calling skill records the decision.

## Reference

- Screen catalog: [references/screens.md](references/screens.md)
- Frame template (CSS reference): `scripts/frame-template.html`
- Helper script (client-side): `scripts/helper.js`
