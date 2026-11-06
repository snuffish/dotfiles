# Research lane briefs (Steps 1.3–4)

Used by `/investigate` § 3 _Research lanes_, and Lanes 2–3 by `/plan` _Case B_ step 2 when no investigation exists. Spawn all four lanes in one message per `fan-out` › _Speed fan-out_. Every brief starts with the shared block, then adds its lane's task.

## Shared block

- **Read-only.** _"Read-only. Make no file edits, commits, worktrees, or outward writes. Cite every claim as `path:line`."_ (`fan-out` › _Brief contract_)
- **Goal and questions:** the Step 0 goal sentence and the numbered core questions, verbatim.
- **Scope:** the `--scope` paths, or the repos from Step 1.2. A caller or contract outside the scope is reported as _outside scope_ with its `path:line` and not traced further.
- **Already known:** the rulebooks, Profiles and References loaded in Step 1.1 (by path), and any files the lead has already read, so the lane does not re-read them.
- **Navigation:** `core` › _Codebase investigation_ item 2, _Code Index First_ (lean `codegraph` commands when `.codegraph/` exists, `rg`/`grep` for wiring, config and unindexed text).
- **`[worktree-context]`:** pasted verbatim when a snapshot is active.
- **Return:** at most 15 findings, each one line, tagged ✅ Verified (`path:line`), 🟡 Inferred (with how to verify) or ❓ Unknown (with who can answer), and each naming the core question it answers. No pasted code, no file dumps, and no options or recommendations, because those belong to the lead.

## Lane 1 — History (Step 1.3)

Run `git log` on the files and symbols in scope, then follow `core` › _Codebase investigation_ item 3, _Historical Transcripts & Memory Lookup_ (claude-mem first, then host transcripts; memory finds, code proves). Return the established decisions that constrain the change, each citing the commit or code that proves it.

## Lane 2 — Prior art (Step 2)

Find the nearest analogous implementation (sibling endpoint, form, domain event, migration) and its flow across every layer. Name any competing patterns, and say which one is the current consensus and why (newest, most callers, or named in a Reference).

## Lane 3 — Trace (Step 3)

Trace the real flow cross-layer per `core` › _Codebase investigation_ item 1, _Trace Enclosing Scope & Cross-Layer Contracts_ (API ↔ client, domain ↔ DB, producer ↔ consumer, runtime ↔ config), including the enclosing classes, lifecycles and middlewares. List the unit and integration tests that cover the flow, and report a missing test as a finding.

## Lane 4 — Blast radius (Step 4)

Enumerate the direct callers, downstream subscribers, consumers and webhooks. Report data and migration risks, third-party and network boundaries, and the auth and access-control gates on the target paths.
