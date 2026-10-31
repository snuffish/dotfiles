# Spec Verification Artifact Template

On-demand reference for [SKILL.md](../SKILL.md) › *3. Output Format & Deliverables*.

```markdown
# Spec Verification — <Spec title/id> vs <PR(s)/branch>

## Context
| Story | <link> — type, state, revision N (last changed <date>). AC field present / absent; description used. |
| Parent / children | … (which child owns which deferred lines) |
| Related / successor | … |
| Code verified | <repo> `<branch>` @ <sha> (= PR head; local tree equal / N behind, read from remote) … |
| Not available | discussion comments / wiki page / … and why |

**Legend:** ✅ · ◐ · ❌ · ↗ · ⚠ · ❔ (one line)
**Result:** <N> spec lines — **<n> ✅ · <n> ◐ · <n> ❌ · <n> ↗ · <n> ⚠ · <n> ❔**. <One sentence: nothing silently wrong / the gaps are X, Y, Z.>

## A. Behaviour
| # | Spec says (short quote, spec language) | Status | Evidence (clickable path:line, both repos) |

## B. <Field group>
## C. <Field group>
(one row per field: control, options, limit — cite the constant, the validator, the schema)

## D. In the code but not in the spec
- bullets with where + "announced in PR text? yes/no"

## Decisions needed before the story can close
1. … (options with cost)
```

- Format file links per `artifact-protocol` › *Host-Specific Link Formats & Section Anchors*; link cross-referenced findings or threads in other artifacts via HTML anchors (`other.md#finding-9`, `other.md#thread-110409`).
- Quote spec lines in the spec's language; write the rest in the review language. Keep Evidence cells to proof, not narrative.
