# Profile resolution is a Module; Profiles stay skills

How a Command finds, layers and applies a project's Profiles is a shared contract, so it lives in one Module, `skills/_modules/project-profile.md`. The Profiles themselves stay skills under `skills/Projects/<Project>/`. A project has one **base profile** (`<project>-profile`) for the facts every Command needs, plus one **Command profile** (`<command>-<project>-profile`) per Command that adapts to it. A Command profile points to the base profile's fields by name instead of restating them. Until now the resolution rules lived only in `implement-feature`. They were already read from `git-worktrees`, `core` and four other Commands, and `/code-review` became the second Command to read a Profile, with a new rule `implement-feature` never had: content a team owns in a product repo is read from its `origin/<default>`, never from a registry copy or the reviewed head.

## Considered Options

- **Copy the resolution section into each Command that reads a Profile.** Rejected: the two copies differed on the first day (upstream sourcing, pointers to another skill's headings), and keeping copies in sync is the job Modules exist to remove.
- **Move the Profiles into `_modules/` (e.g. `_modules/profiles/priis.md`).** Rejected: a project-agnostic Command would have to name a project path, the `[Project: …]` description gate would stop working because Modules are never listed, and project facts would sit in the folder reserved for project-independent contracts.
- **One Profile per Command, with no base profile.** Rejected: the tracker, contract touchpoints, known drift and worktree facts would be duplicated in every Command profile of the project.

## Consequences

- A Command that reads Profiles lists `project-profile` in its `## Modules` and keeps a table of only its own fields. The shared fields and their fallbacks are defined once, in the Module.
- `git-worktrees` refers to the Module's shared fields instead of a Command's section.
- A Profile that delegates to another skill's section names the exact heading. A heading that is missing when the Profile is read is reported, not skipped.
- Every project with a Command profile also needs a base profile, even a short one.
