# Handoffs (/proceed workflow)

- Every handoff step ends by writing the next-step handoff document. Do this without being asked.
- Handoff status lines must list every branch and PR involved (names + IDs). Re-read the status line before saving.
- **Portable to a new session.** `/proceed <handoff>` starts a fresh session, where this session's scratchpad and `/tmp` files are gone. Copy every file the handoff depends on to `<artifact-dir>/<suffix>/` and cite it there. `claude/plan-lint.py` flags a `<scratchpad>`, `/tmp/` or `/private/tmp/` path.
- Verify claims against real data (live PR, real directory, CI run) before marking a step done. If you can't, say explicitly what was only unit-tested.
