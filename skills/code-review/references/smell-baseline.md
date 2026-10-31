# Smell Baseline (Fowler, _Refactoring_ ch. 3)

On-demand reference for [SKILL.md](../SKILL.md) › *Step 3 — Identify the Standards Sources* and [deep-mode.md](deep-mode.md).

Two rules bind this baseline:
- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), rated 🟢 unless it causes a concrete defect or maintenance cost you can name. Skip anything tooling already enforces (formatters, linters, analyzers).

| Smell | What it is | Fix |
| --- | --- | --- |
| Mysterious Name | Name doesn't reveal what it does or holds | Rename; if no honest name comes, the design is murky |
| Duplicated Code | Same logic shape in more than one hunk or file | Extract the shared shape, call it from both |
| Feature Envy | Method reaches into another object's data more than its own | Move it onto the data it envies |
| Data Clumps | Same few fields/params keep travelling together | Bundle them into one type |
| Primitive Obsession | Primitive/string standing in for a domain concept | Give the concept its own small type |
| Repeated Switches | Same `switch`/`if`-cascade on the same type recurs | Polymorphism, or one shared map |
| Shotgun Surgery | One logical change forces scattered edits | Gather what changes together |
| Divergent Change | One module edited for several unrelated reasons | Split so each changes for one reason |
| Speculative Generality | Abstraction/params/hooks the spec doesn't need | Delete; inline until a real need shows |
| Message Chains | Long `a.b().c().d()` navigation | Hide the walk behind one method |
| Middle Man | Class/function that mostly delegates onward | Cut it, call the real target |
| Refused Bequest | Subclass ignores most of what it inherits | Drop inheritance, use composition |
