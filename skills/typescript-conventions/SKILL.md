---
name: typescript-conventions
description: General TypeScript conventions for any project — prefer `type` over `interface` for props, state, payloads and domain objects. Load when writing, reviewing or refactoring TypeScript or TSX code.
---

# TypeScript Conventions

Conventions for TypeScript in every codebase, unless a workspace rulebook or project-scoped Reference says otherwise.

---

## 1. Prefer `type` before `interface`

- Always prefer `type` over `interface` for props, state, payloads, and domain objects (`type ComponentProps = { ... }`, not `interface ComponentProps`).
- Reserve `interface` strictly for third-party declaration merging or framework-mandated abstractions.
