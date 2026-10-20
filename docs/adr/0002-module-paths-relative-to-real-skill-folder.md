# Module paths are relative to the skill's real folder

A Command's `## Modules` paths are relative to the folder its `SKILL.md` really lives in: `../_modules/<name>.md` for a top-level Command, `../../../_modules/<name>.md` for one under `Projects/<Project>/`. The block opens with a fixed preamble that tells the model to run `realpath` on the skill's base directory once, resolve each path from there, and stop and report the path if any Module cannot be read. This supersedes ADR-0001's "Module paths in Commands are absolute": the absolute `~/.terminal/skills/_modules/` path tied the Registry to one clone location.

ADR-0001 was right that a plain relative path breaks. Claude Code hands the model the symlink (`~/.claude/skills/<name>`) as the skill's base directory, and its Read tool resolves `..` lexically, so `~/.claude/skills/investigate/../_modules/core.md` does not exist. `realpath` follows the symlink before it applies `..` and lands on `skills/_modules/core.md` at either depth. Antigravity reads skills from their real folders, where both kinds of join agree.

## Considered Options

- **Keep `~/.terminal/skills/_modules/` absolute.** Rejected: works on any OS that expands `~`, but only from that one clone location.
- **A `<registry>` placeholder resolved by walking up to the folder that holds `_modules/`.** Rejected: the same text at every depth, but the model has to run a loop instead of one `realpath`, and the path no longer says where the Module is.
- **Symlink `_modules` into each loader root so a lexical `..` lands on it.** Rejected: it needs a tracked symlink under `Projects/<Project>/`, which git on Windows checks out as a text file unless `core.symlinks` is on.

## Consequences

- Every Command run costs one `realpath` call before its first Module read.
- The number of `../` encodes the skill's depth. A skill that moves between depths must update them. `/sync-skills` (formerly `/reload-skills`) lints every `## Modules` path from the real `SKILL.md` folder and reports missing paths, absolute paths and blocks without the stop sentence.
- A Module that cannot be read stops the Command instead of letting it run without `core`'s gates.
