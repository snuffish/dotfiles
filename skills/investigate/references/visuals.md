# Visuals in Investigation Output

These rules adapt the `/show-me` view rules; `/show-me` (`~/.agents/skills/show-me/SKILL.md`) sets `disable-model-invocation: true`, so only the user can run it, which the handoff offers.

Pick the smallest view that makes each point clear, at most three per artifact:

| Section               | Point to make                                                                                                          | View                                                   |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| §3 Current-State      | Interaction across components, threads, or processes, or anything where order matters (races, retries, async handoffs) | Mermaid `sequenceDiagram`                              |
| §3 Current-State      | Control flow within one process                                                                                        | Call tree in a `text` block                            |
| §7 Recommended option | What the option changes                                                                                                | `diff` of that call tree, state flow, or file tree     |
| §8 Failure scenario   | The trigger, when it depends on timing and the §3 visual does not already show it                                      | Mermaid `sequenceDiagram` with a `Note` at the failure |

- Every node in a visual is a symbol from the §3 code map table, so each one traces to a `path:line`. A visual never carries a claim that the text does not cite.
- Keep only the calls, files, and boundaries needed for the point. Use real names, not placeholders.
- The §7 `diff` shows shape (calls, states, files), not implementation code. The Plan Seed stays free of code.
- Skip visuals when the answer is a single fact that one cited sentence already states.
