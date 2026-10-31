# Research Sub-Agent Brief Template (Phase 1)

Follow `fan-out` › *Brief contract*. Spawn one `Explore` sub-agent per repo in scope (plus an optional cross-repo contract surface agent) in one message:

> Read-only. `<pasted [worktree-context] block>` — work only under `repo-root`, never touch `main-checkout`, report paths as `workspace-path` + relative path. Ticket `#<id>`: `<pasted title + acceptance criteria>`. Trace the nearest sibling feature `<name>` through every layer — `<sibling chain for this repo from the profile>`. Report: the files the change will touch with `path:line`, the pattern each one follows (and which of two competing patterns is newer), contract touchpoints (`<profile's contract list>`), and anything in the acceptance criteria the code cannot support yet. Return only the findings, one entry each.
