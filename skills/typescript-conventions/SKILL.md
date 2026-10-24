---
name: typescript-conventions
description: "General TypeScript conventions for any project — prefer `type` over `interface` for props, state, payloads and domain objects. Load when writing, reviewing or refactoring TypeScript or TSX code."
---

# TypeScript Conventions

Conventions for TypeScript in every codebase, unless a workspace rulebook or project-scoped Reference says otherwise. Other skills (`/clean`, `/expressive`, the review skills) link here instead of restating these rules.

---

## 1. Prefer `type` over `interface`

Declare props, state, payloads and domain objects with `type`:

```ts
type ButtonProps = { label: string; onClick: () => void };   // ✅
interface ButtonProps { label: string; onClick: () => void } // ❌ for new code
```

Why:

- **One construct for every shape.** Unions, intersections, mapped and conditional types (`type Status = 'open' | 'closed'`, `type Readonly<T> = …`) need `type` anyway. Using it for object shapes too means one form to read and write.
- **No silent merging.** Two `interface` declarations with the same name in scope merge into one, so a stray declaration can widen a type far from where it is used. A duplicate `type` is a compile error.

Use `interface` where merging is the point: augmenting a third-party module or global (`declare module 'x' { interface … }`, `interface Window { … }`), or where a framework requires it.

Converting existing interfaces is a separate refactor. Do it only when asked, or in code you are already rewriting.
