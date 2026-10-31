# Skill Gap File Template & Chat Block

On-demand reference for [core.md](../core.md) › *Skill gaps* and the [skill-gap](../../skill-gap/SKILL.md) Command.

---

## File template (`~/.terminal/skill-gaps/<prefix>-skill_gap-<skill>-<topic>.md`)

Claim the path (`mkdir -p ~/.terminal/skill-gaps` first) with `artifact-protocol` › *Claim*. Below the owner marker *Claim* writes:

```markdown
# Skill gap: <skill>

- **Status:** open
- **Found:** <YYYY-MM-DD HH:MM> by <host>-<model>, session <session id>, running <the Command, or none>
- **Where:** `<repo path>` · `<branch>` @ `<short SHA>`

**Skill gap (<skill>):** <what it missed or got wrong>
- **Evidence:** <command and output, or `path:line`>
- **Proposed edit:** `<realpath of the file>` › <heading>: replace `<old>` with `<new>`
- **Check:** `/sync-skills`, plus anything that shows the fix works
- **Logged:** [<file name>](<absolute path of the gap file>)
```

The directory is git-ignored and sits outside every repo, so the write is allowed under read-only Commands and from snapshots. When a later session fixes the gap, it sets **Status** to `fixed`; a gap that turns out not to apply gets `not a gap: <reason>`.

## Chat block

At the end of the turn, print one block per gap logged:

```markdown
**Skill gap (<skill>):** <what it missed or got wrong>
- **Evidence:** <command and output, or `path:line`>
- **Proposed edit:** `<realpath of the file>` › <heading>: replace `<old>` with `<new>`
- **Check:** `/sync-skills`, plus anything that shows the fix works
- **Logged:** [<file name>](<absolute path of the gap file>)
```
