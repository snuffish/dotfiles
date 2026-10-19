# Modules live outside the skill loaders

Shared contracts that Commands depend on (`core`, `artifact-protocol`, `git-worktrees`, `pr-counterpart`) are not skills. Each is a plain markdown file at `skills/_modules/<name>.md`, with no frontmatter and no `SKILL.md`, and is never symlinked into `~/.claude/skills`. A Command pulls a Module in by telling the model to read its path (`skills/_modules/<name>.md`) before it starts. No host has an import mechanism between skills, so a file path is the only real dependency edge. Registering Modules as skills put them in the skill list, where they could be invoked or auto-loaded on their own, with descriptions that never meaningfully trigger. Every listed skill also costs context on every turn, and the listing has a fixed budget (1% of the context window), so a Module that is registered as a skill pushes out the descriptions of real skills.

## Considered Options

- **Keep them as skills with `user-invocable: false` + `disable-model-invocation: true`.** Rejected: that is two flags spent making an entry act as if it were not a skill, and Antigravity's support for those flags is unknown.
- **Package the Registry as a Claude Code plugin and share Modules through `${CLAUDE_PLUGIN_ROOT}`.** This is the only documented way to share files between skills. Rejected: Antigravity cannot load Claude plugins, and every Command would be renamed to `/<plugin>:<name>`.
- **Relative paths via `${CLAUDE_SKILL_DIR}/../_modules/`.** Rejected: whether it resolves a symlinked skill to the link or the target is undocumented, and Antigravity has no equivalent.
- **A sibling `~/.terminal/modules/` directory.** Rejected in favour of keeping the whole Registry under `skills/`. `_modules/` is safe there because both loaders only look at the direct children of their roots: the Claude Code flat loader sees only what is symlinked, and Antigravity's `skills.json` lists `skills/Projects/GR.PRIIS` as its own root. `skills/Projects/` already sits at the root without a `SKILL.md` and causes no trouble.

## Consequences

- Module paths in Commands are absolute. A relative link breaks when a skill is read through its `~/.claude/skills/<name>` symlink. Superseded by [ADR-0002](0002-module-paths-relative-to-real-skill-folder.md).
- Module-to-Module references are relative (`[core.md](core.md)`). A Module is never symlinked, so it is always read from its real folder, and the reference survives the registry moving to another machine or path.
- A Module that grows into a folder must never contain a `SKILL.md`.
- `reload-skills` skips `_modules/` explicitly.
- Reading a Module is a read outside the working directory, which needs permission unless a `Read` allow rule covers `~/.terminal/skills/`. Skill folders get no automatic exemption.
