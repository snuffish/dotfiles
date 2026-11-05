# Skills

Local skill registry. This is a **source-of-truth / staging** area. You activate skills either by pointing a workspace skill-loader configuration (`skills.json`) directly at directories in this tree, or by symlinking individual skills into a flat live skills root (e.g. `~/.claude/skills/`).

Each skill is a directory containing `SKILL.md` with `name` + `description` frontmatter. The directory name always equals the `name` field, and every skill name is globally unique — so a flat loader can symlink any skill in without collisions.

## Kinds

Everything in the Registry is one of four kinds (defined in [`../GLOSSARY.md`](../GLOSSARY.md)):

| Kind | What it is | Is a skill? | Examples |
|---|---|:---:|---|
| **Command** | Carries out a workflow, invoked by name or by a matching request | yes | `/code-review`, `/create-ticket`, `squash-ef-core-migrations` |
| **Reference** | Knowledge the model loads by topic, never run as a workflow | yes | `modern-csharp`, `priis-backend-dry` |
| **Profile** | Project-specific facts a Command reads to adapt to that project: a base profile shared by the project's Commands, plus one Command profile per Command | yes | `priis-profile`, `implement-feature-priis-profile`, `code-review-priis-profile` |
| **Module** | A shared contract Commands depend on; never runs on its own | **no** | See [Inventory](#inventory) |

Before adding a new Command, check whether it is a mode or flag of an existing one, as `/plan preview` and `/plan --review` are. Make it a separate skill only when it has its own trigger and its own workflow. Three skills added in October 2026 (`plan-preview`, `plan-review`, `typescript-conventions`) were folded into existing skills within 5–11 days.

## Layout

```plaintext
skills/
  <general skills>/                # reusable across any project (Commands and References)
  _modules/                        # Modules: plain <name>.md (+ references/), no frontmatter, never symlinked (ADR-0001)
  Projects/
    GR.PRIIS/                      # everything scoped to the GR.PRIIS product lives here
      priis-backend-dry/
      priis-prod-diagnose/
      priis-profile/               # base profile: facts every PRIIS Command profile shares
      implement-feature-priis-profile/
      code-review-priis-profile/
```

- **Top level** = general, project-agnostic skills.
- **`_modules/`** = Modules. Neither loader sees them: Claude Code only loads what is symlinked into `~/.claude/skills`, and Antigravity scans only the direct children of each `skills.json` root. Never put a `SKILL.md` in here. See [`../docs/adr/0001-modules-live-outside-skill-loaders.md`](../docs/adr/0001-modules-live-outside-skill-loaders.md).
- **`Projects/<Project>/`** = skills scoped to a specific project. Add a new folder per project as more are onboarded.

## Inventory

53 skills total — 48 general + 5 under `Projects/GR.PRIIS/` — plus 8 Modules.

| Group | Kind | Count | Entries |
| --- | --- | :---: | --- |
| General (top level) | Command | 47 | `artifacts`, `clean`, `code-documentation`, `code-review`, `commit`, `continue`, `create-prompt`, `create-skill`, `create-ticket`, `explain`, `export-file`, `expressive`, `fix-findings`, `grill-me`, `handoff`, `implement-feature`, `insights`, `investigate`, `manual-testing`, `no-worktrees`, `organize`, `plan`, `pr-desc`, `pr-feedback-review`, `pr-fix-pipeline`, `pr-polish`, `pr-post-comments`, `pr-summary`, `problem`, `proceed`, `refine`, `remember-this`, `resolve-conflicts`, `skill-drift`, `skill-gap`, `skill-review`, `simplify`, `simplify-branch`, `spec-verification`, `squash-code-review`, `squash-ef-core-migrations`, `standup-recap`, `suggestion`, `sync-skills`, `verify-assumptions`, `what-am-I-missing`, `worktrees` |
| General (top level) | Reference | 1 | `modern-csharp` |
| `GR.PRIIS/priis-prod-*` | Command | 1 | `diagnose` (production diagnosis over remote desktop: read-only T-SQL rounds) |
| `GR.PRIIS/priis-backend-*` | Reference | 1 | `dry` (the other PRIIS team skills ship in the repo's `.claude/skills/`, not here) |
| `GR.PRIIS/*-profile` | Profile | 3 | `priis-profile` (base), `implement-feature-priis-profile` (read by `implement-feature`), `code-review-priis-profile` (read by `code-review`) |
| `_modules/` | Module | 8 | `core`, `artifact-protocol`, `git-worktrees`, `pr-counterpart`, `pr-host`, `project-profile`, `fan-out`, `outward-writes` |

(Project skill names are the group prefix + the listed suffix — e.g. `priis-backend-dry`. The PRIIS team skills (`priis-backend-*`, `priis-frontend-*`, `priis-fullstack-review`, `priis-ship`, …) live only in the GR.PRIIS repo's `.claude/skills/`; the registry keeps no copies.)

## Modules & Precedence

Every **Command** opens with a `## Modules` section that tells the model to read each Module it depends on before step 1, by a path relative to the skill's real folder (`../_modules/<name>.md`, or `../../../_modules/<name>.md` under `Projects/<Project>/`). The section opens with a sentence telling the model to resolve those paths through `realpath`, since a string join breaks through the `~/.claude/skills` symlink, and to stop if a Module cannot be read ([ADR-0002](../docs/adr/0002-module-paths-relative-to-real-skill-folder.md)). A Module that depends on another Module links it relatively (`[core.md](core.md)`), because Modules are never symlinked. Each line also carries the Command's setting for that Module:

```markdown
## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: writes `<prefix>-code_review-<suffix>.md`
- `../_modules/git-worktrees.md`: snapshot by default
- `../_modules/pr-counterpart.md`
```

A Command lists only the Modules it uses directly; a Module lists its own dependencies (for example, [`project-profile`](_modules/project-profile.md) is read by `implement-feature`, `code-review`, `plan`, `pr-feedback-review`, and `pr-summary`; [`pr-host`](_modules/pr-host.md) by every PR-reading Command). Sections inside a Module are referred to by name (`` `git-worktrees` › *Workspace* ``), never by number. **References** and **Profiles** carry no `## Modules` section and inherit the standards through [`core` › *Precedence*](_modules/core.md#precedence).

## Naming convention (inside `Projects/GR.PRIIS/`)

| Prefix                                                   | Meaning                                                                                                          |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `priis-backend-*`                                        | Skill specific to the GR.PRIIS backend (.NET / FastEndpoints / EF Core). Only `dry` lives here; the rest ship in the repo. |
| `priis-frontend-*`                                       | Skill specific to the GR.PRIIS frontend (React / RTK Query / TanStack Router). All ship in the repo, none here. |
| `priis-prod-*`                                           | Production diagnosis Command for GR.PRIIS (`priis-prod-diagnose`: read-only T-SQL rounds over remote desktop). |
| `<project>-profile`                                      | Base profile: the project's shared fields (layout, tracker, PR tooling, References per layer, contracts, report language, known drift, worktree setup), loaded before any Command profile. |
| `<command>-<project>-profile`                            | Command profile read by that general Command, only the fields it needs: `implement-feature-<project>-profile` (facts per phase: implementing ID, scaffold, verify, ship), `code-review-<project>-profile` (review checklists, lessons, axis mapping, report additions). |

The `priis-backend-`/`priis-frontend-` prefix matches the names the repos use for their own copies, distinguishes the two apps within the single GR.PRIIS product folder, and keeps every skill name unique.

Every project-specific skill is also **gated in its `description`**: it opens with `[Project: GR.PRIIS]` and closes with `Load ONLY when working in the GR.PRIIS repository or the GR folder that holds it.`

Load these skills directly by registering their paths in the workspace configuration (e.g. `.agents/skills.json`), replacing `<global_skills_dir>` with the absolute path to your local skills registry (e.g. `/Users/username/.terminal/skills` on macOS/Linux or `C:\Users\username\.terminal\skills` on Windows):

```json
{
  "entries": [
    { "path": "<global_skills_dir>" },
    { "path": "<global_skills_dir>/Projects/GR.PRIIS" }
  ]
}
```

Flat loaders (`~/.claude/skills`, `~/.gemini/config/skills`, `~/.gemini/skills`, or `%USERPROFILE%\.claude\skills` on Windows) expect each skill as a direct child (`root/<name>/SKILL.md`). Run `sync-skills` from the shell ([`../claude.bash`](../claude.bash) prompts to apply when link changes are pending; [`../code.bash`](../code.bash) defines a check-only alias fallback if `claude.bash` was not loaded) or invoke [`/sync-skills`](sync-skills/SKILL.md) to lint the registry and reconcile loader symlinks, `.flat-links` allow-lists, and `.workspaces` configs. For manual symlink loops on a machine without Python, see [`sync-skills/references/manual-linking.md`](sync-skills/references/manual-linking.md).
