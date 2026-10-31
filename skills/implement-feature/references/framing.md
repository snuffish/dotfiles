# Request Framing & Multi-Perspective Re-phrasing (Phase 0 Step 9)

Do not jump straight into research or planning. Present the request/ticket re-phrased in 3–6 contrasting perspectives from the menu below (picking the 3–4 that contrast most sharply for the ticket, or all 6 when wide open), each giving the feature a distinct "touch", "feeling", and "approach":

- **Pragmatic / Minimalist** (surgical diff, lowest churn, fastest ship, minimal surface touched).
- **Defensive / Robust** (exhaustive validation, edge-case hardening, resilience, strict error boundaries).
- **Architectural / Extensible** (clean domain boundaries, reusable seams, future-proof abstractions).
- **User / DX-Forward** (optimized developer or end-user ergonomics, intuitive workflows, clear feedback).
- **AI- / Agent-Forward** (deterministic semantics, pure testable domain seams, machine-navigable contracts, zero hidden magic).
- **Dark-Launch / Decoupled** (gated rollout, feature-toggled execution, safe production merge ahead of upstream dependencies).

For each option, output:
- *Concept & Touch*: 1–2 sentences capturing the character, feeling, and approach (apply any locale/translation rule from the active project profile).
- *Key Trade-off*: what it prioritizes vs. what it defers or accepts.
- *Target Footprint*: anticipated blast radius and test expectation.

**Stop here** and prompt the user to pick one (e.g., "1", "2"), blend them (e.g., "Minimalist with Defensive validation"), or provide adjustments. Only continue to Phase 1 once the user confirms their chosen framing (bypass only when invoked with `--direct` or `/no-framing`).
