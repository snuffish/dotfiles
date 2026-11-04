# `--ui` mode

On-demand reference for [SKILL.md](../SKILL.md) › *Step 6*. Runs after the artifact is published and the snapshot removed, so it works with standard, `--deep` and `live`. It never posts to the PR.

Script: [review_ui.py](../scripts/review_ui.py), stdlib only, always `python3 -I`. `<md>` is the published artifact path.

1. **Serve** (Bash `run_in_background`): `python3 -I <skill>/scripts/review_ui.py serve <md> --open`. Read `URL` and `PID` from its output. Answers autosave to `<base>.answers.json`.
2. **Watch** with one persistent Monitor, `timeout_ms` 1800000; re-arm on expiry (autosave loses nothing). It emits one `SUBMITTED` per submit and ends with `SERVER_EXITED`:
   ```bash
   D=<base>.answers.done
   while :; do [ -e "$D" ] && { rm -f "$D"; echo SUBMITTED; }; kill -0 <PID> 2>/dev/null || { echo SERVER_EXITED; exit 0; }; sleep 1; done
   ```
3. **On each `SUBMITTED`**: `python3 -I <skill>/scripts/review_ui.py merge <md>`. Keep the server running: the user can adjust further and submit again.
4. **Rewrite every `ADJUST <key> thread-<id>` line merge printed**: in that thread, rewrite the quoted draft from the user's notes under its `UI decision` line, run `outward-writes` › *Voice pass*, set the heading back to `#### Ready-to-Send Reply (<language>) — Voice pass: done` and the decision to `adjusted from notes (<date>)` (keep the notes). Show each new reply in chat.
5. The server sees the changed .md on its next request; the page polls it and reloads, so merged replies and rewrites show up as the new drafts. A save from a page that still holds the old version gets 409 and asks the user to load the latest one.
6. **On `SERVER_EXITED`** (the user pressed *Finish*, or the server died): confirm the port is closed, then the chat link block, the gate line, and `/pr-post-comments "the replies"` as the next step. Keep the answers file. If the last submit was never merged, run `merge <md> --force-unsubmitted` only when the user says so. If the user ends the session without *Finish*, `kill <PID>`.

Merge rules:
- Four choices per reply: *Use AI draft* (unchanged), *Adjust AI draft* (the user's notes on what is wrong; the session rewrites the reply, step 4), *Write my own* (the user's exact text replaces the draft), *Skip*.
- An own reply loses `Voice pass: done`, so the pass runs again (`outward-writes` › *Voice pass*, rule 4; `/pr-post-comments` re-runs it).
- An adjust reply gets the heading `Reply (rewrite from --ui notes — not posted yet)` until step 4, so `/pr-post-comments` never posts the old draft.
- A skipped reply gets the heading `Reply (skipped in --ui — not posted)`; `/pr-post-comments` posts only *Ready-to-Send Reply* blocks.
- Each thread gets a `UI decision` line and the header a `UI answers` line; triage status fields are untouched.
- Threads are keyed by section order plus anchor id (counterpart PRs may share thread IDs). Re-running merge changes nothing.
- Re-serving, or the .md changing under a running server, keeps the user's unmerged changes and refreshes untouched replies from the .md. After a merge the .md is the new baseline: answers are re-seeded from it, and a thread the session has rewritten from notes goes back to *Use AI draft* with the new text.
- Exit 2: the .md changed since the server last read it (let the page reload, or re-serve). Exit 3: answers not submitted. Exit 4: a reply, its notes or its own text is empty.
- Standalone (no session watching): after each Submit, `serve` prints the `merge` command to run.

Security: the server binds `127.0.0.1` only (never `0.0.0.0`), requires the per-run token and a `127.0.0.1:<port>` Host header on every call, accepts JSON only, sets no CORS headers, and writes only `.answers.json` and `.answers.done`. *Finish* (`POST /api/close`) stops it.
