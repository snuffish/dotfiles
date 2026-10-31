# Reference & Profile Skill Templates

Same frontmatter (`name`, `description`, plus `user-invocable: false` for every Profile) and `# <Title>`, then the content sections directly — **no `## Modules` section** (References inherit standards through `core` › *Precedence*).

- **Project-scoped description gate**: opens with `[Project: <Project>]` and ends with the canonical gate (for GR.PRIIS: `Load ONLY when working in the GR.PRIIS repository or the GR folder that holds it.`).
- **Base profile (`<project>-profile`)**: follows `project-profile` (`skills/_modules/project-profile.md`, [ADR-0003](../../../docs/adr/0003-profile-resolution-is-a-module.md)) and answers all *Shared fields*. Create the base profile first if the project has none.
- **Command profile (`<command>-<project>-profile`)**: answers only the fields in that Command's *Project profile* table, points to `<project>-profile` › *Profile fields* by field name, and lists its *Precedence overrides*. The Command it serves must list `project-profile` in its `## Modules`.
