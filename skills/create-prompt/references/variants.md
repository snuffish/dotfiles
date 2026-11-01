# `--variants` Option Protocol

Guidelines and output structure for generating multi-variant prompts when `--variants` is specified.

---

## 1. Variant Differentiation Axes

Generate 2–3 prompt alternatives when the user wants to evaluate different paths. Each variant must differ in **what the run does**, along one of these axes:

- **Skill**: the runner-up from step 2, when it was close (e.g. `/simplify` vs `/expressive`).
- **Depth**: a quick pass vs the skill's thorough mode (`deep`, broader scope, additional review lenses).
- **Plan-first**: discover and plan, then stop for approval before executing changes.

Two variants may share an axis (e.g., comparing two candidate skills). Variants that differ only in superficial wording or emphasis are redundant—emit fewer variants rather than padding. Mark exactly one variant as **(Recommended)**.

---

## 2. Multi-Variant Output Format

Replace the single-prompt output block with:

````markdown
**1. <approach, 2–4 words> (Recommended)**: `/<skill>` — <when to pick it, ≤12 words>

```text
<prompt>
```

**2. <approach, 2–4 words>**: `/<skill>` — <when to pick it>

```text
<prompt>
```

**Unresolved questions:** <what I must decide, each with your recommendation. Leave this block out when there are none.>

- <question> — recommend: <answer>

Next: paste one, or `/proceed N` to run it here (bare `/proceed` runs 1).
````
