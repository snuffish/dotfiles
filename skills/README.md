# Skills

Local skill registry. This is a **source-of-truth / staging** area. You activate skills either by pointing a workspace skill-loader configuration (`skills.json`) directly at directories in this tree, or by symlinking individual skills into a flat live skills root (e.g. `~/.claude/skills/`).

Each skill is a directory containing `SKILL.md` with `name` + `description` frontmatter. The directory name always equals the `name` field, and every skill name is globally unique — so a flat loader can symlink any skill in without collisions.

## Kinds

Everything in the Registry is one of four kinds (defined in [`../GLOSSARY.md`](../GLOSSARY.md)):

| Kind | What it is | Is a skill? | Examples |
|---|---|:---:|---|
| **Command** | Carries out a workflow, invoked by name or by a matching request | yes | `/code-review`, `/create-ticket`, `squash-ef-core-migrations` |
| **Reference** | Knowledge the model loads by topic, never run as a workflow | yes | `modern-csharp`, `backend-ef-core` |
| **Profile** | Project-specific facts one Command reads to adapt to that project | yes | `implement-feature-priis-profile` |
| **Module** | A shared contract Commands depend on; never runs on its own | **no** | `core`, `artifact-protocol`, `git-worktrees`, `pr-counterpart` |

## Layout

```plaintext
skills/
  <general skills>/                # reusable across any project (Commands and References)
  _modules/                        # Modules: plain <name>.md, no frontmatter, never symlinked (ADR-0001)
  Projects/
    GR.PRIIS/                      # everything scoped to the GR.PRIIS product lives here
      backend-<skill>/
      frontend-<skill>/
      source-command-backend-<skill>/
      source-command-frontend-<skill>/
      implement-feature-priis-profile/
```

- **Top level** = general, project-agnostic skills.
- **`_modules/`** = Modules. Neither loader sees them: Claude Code only loads what is symlinked into `~/.claude/skills`, and Antigravity scans only the direct children of each `skills.json` root. Never put a `SKILL.md` in here. See [`../docs/adr/0001-modules-live-outside-skill-loaders.md`](../docs/adr/0001-modules-live-outside-skill-loaders.md).
- **`Projects/<Project>/`** = skills scoped to a specific project. Add a new folder per project as more are onboarded.

## Inventory

54 skills total — 31 general + 23 under `Projects/GR.PRIIS/` — plus 4 Modules.

| Group | Kind | Count | Entries |
| --- | --- | :---: | --- |
| General (top level) | Command | 29 | `artifacts`, `ask-question`, `clean`, `code-documentation`, `code-review`, `create-skill`, `create-ticket`, `explain`, `expressive`, `implement-feature`, `investigate`, `manual-testing`, `organize`, `plan`, `pr-feedback-review`, `pr-fix-pipeline`, `pr-post-comments`, `pr-summary`, `problem`, `refine`, `reload-skills`, `resolve-conflicts`, `review`, `spec-verification`, `squash-code-review`, `squash-ef-core-migrations`, `suggestion`, `verify-assumptions`, `what-am-I-missing` |
| General (top level) | Reference | 2 | `modern-csharp`, `typescript-conventions` |
| `GR.PRIIS/backend-*` | Reference | 7 | `dry`, `ef-core`, `fastendpoints`, `notifications`, `signalr`, `testing`, `workflow` |
| `GR.PRIIS/frontend-*` | Reference | 6 | `component-patterns`, `forms`, `routing`, `rtk-query`, `testing`, `workflow` |
| `GR.PRIIS/source-command-backend-*` | Command | 6 | `health-check`, `migrate-to-tunit` (retired — migration complete), `release-notes`, `scaffold`, `ship`, `verify` |
| `GR.PRIIS/source-command-frontend-*` | Command | 3 | `health-check`, `scaffold`, `verify` |
| `GR.PRIIS/implement-feature-*` | Profile | 1 | `priis-profile` — project profile consumed by the general `implement-feature` orchestrator |
| `_modules/` | Module | 4 | `core`, `artifact-protocol`, `git-worktrees`, `pr-counterpart` |

(Project skill names are the group prefix + the listed suffix — e.g. `backend-ef-core`, `source-command-frontend-verify`.)

## Modules & Precedence

Every **Command** opens with a `## Modules` section that tells the model to read each Module it depends on before step 1, by absolute path (a relative link breaks when the skill is read through its `~/.claude/skills` symlink). A Module that depends on another Module links it relatively (`[core.md](core.md)`), because Modules are never symlinked. Each line also carries the Command's setting for that Module:

```markdown
## Modules

Read these before step 1:
- `~/.terminal/skills/_modules/core.md`: read-only until `/proceed`
- `~/.terminal/skills/_modules/artifact-protocol.md`: writes `<prefix>-code_review-<suffix>.md`
- `~/.terminal/skills/_modules/git-worktrees.md`: snapshot by default
- `~/.terminal/skills/_modules/pr-counterpart.md`
```

1. **[`core`](_modules/core.md)**: golden invariants, execution gates (`/proceed`, post-edit verification, worktree opt-in), codebase investigation protocol and the precedence model. Depends on nothing.
2. **[`artifact-protocol`](_modules/artifact-protocol.md)**: host & AI model prefix (`<host>-<model>-`), mandatory contextual suffix, link formats, PR thread links and the canonical artifact catalog.
3. **[`git-worktrees`](_modules/git-worktrees.md)**: worktree isolation. `/code-review` and `/pr-feedback-review` snapshot through it, `/implement-feature` implements in a workspace worktree, and any Command switches to it when invoked with `worktree`. It hands a `[worktree-context]` block to every delegated skill so no skill acts on the user's main checkout.
4. **[`pr-counterpart`](_modules/pr-counterpart.md)**: finds the sibling-repo PR of a dual-repo change.

A Command lists only the Modules it uses directly; a Module lists its own dependencies. Sections inside a Module are referred to by name (`` `git-worktrees` › *Workspace Lifecycle* ``), never by number. **References** and **Profiles** carry no `## Modules` section and inherit the standards through the precedence model. Instruction precedence resolves in this order:

1. **Workspace Rulebooks** (`CLAUDE.md` / `GEMINI.md` / `.agents/rules/`)
2. **Project-scoped References and Profiles** (`Projects/<Project>/...`)
3. **General References** (`modern-csharp`, `typescript-conventions`, etc.)
4. **Modules** (`core`, `artifact-protocol`, `git-worktrees`, `pr-counterpart`)

## Naming convention (inside `Projects/GR.PRIIS/`)

| Prefix                                                   | Meaning                                                                                                          |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `backend-*`                                              | Reference specific to **GR.PRIIS.Backend** (.NET / FastEndpoints / EF Core).                                    |
| `frontend-*`                                             | Reference specific to **GR.PRIIS.Frontend** (React / RTK Query / TanStack Router).                              |
| `source-command-backend-*` / `source-command-frontend-*` | Commands ported from a project slash-command (`.claude/commands/`); operational recipes rather than reference knowledge. |
| `implement-feature-<project>-profile`                    | Profile read by the general `implement-feature` orchestrator: resolved facts per phase (tracker, skills, verify, ship, contracts, known drift). |

The `backend-`/`frontend-` prefix distinguishes the two apps within the single GR.PRIIS product folder, and keeps every skill name unique.

Every project-specific skill is also **gated in its `description`**: it opens with `[Project: GR.PRIIS.X]` and closes with `Load ONLY when working on the GR.PRIIS.X project or in the GR repository.`

Load these skills directly by registering their paths in the workspace configuration (e.g. `.agents/skills.json`), replacing `<global_skills_dir>` with the absolute path to your local skills registry (e.g. `/Users/username/.terminal/skills` on macOS/Linux or `C:\Users\username\.terminal\skills` on Windows):

```json
{
  "entries": [
    { "path": "<global_skills_dir>" },
    { "path": "<global_skills_dir>/Projects/GR.PRIIS" }
  ]
}
```

Some loaders (like `~/.claude/skills` on macOS/Linux or `%USERPROFILE%\.claude\skills` on Windows) expect a **flat** root — each skill a direct child (`root/<name>/SKILL.md`), with no grouping folders. To activate from this grouped staging tree, symlink the specific skills you want.

#### macOS / Linux (Bash/Zsh)

```bash
# A single skill:
ln -s ~/.terminal/skills/Projects/GR.PRIIS/backend-ef-core ~/.claude/skills/backend-ef-core

# Every skill in the tree (general + all projects), flattened by name:
find ~/.terminal/skills -name SKILL.md -print0 | while IFS= read -r -d '' f; do
  d="$(dirname "$f")"
  ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"
done
```

#### Windows (PowerShell)

```powershell
# A single skill:
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\skills\backend-ef-core" -Value "$env:USERPROFILE\.terminal\skills\Projects\GR.PRIIS\backend-ef-core"

# Every skill in the tree (general + all projects), flattened by name:
Get-ChildItem -Path "$env:USERPROFILE\.terminal\skills" -Filter "SKILL.md" -Recurse | ForEach-Object {
    $srcDir = $_.DirectoryName
    $destDir = Join-Path "$env:USERPROFILE\.claude\skills" $_.Directory.Name
    New-Item -ItemType SymbolicLink -Path $destDir -Value $srcDir -Force
}
```

(If the loader globs recursively — `skills/**/SKILL.md` — point it at this root directly and the grouping is honored as-is.)

**Current live state:** All 54 skills are flat-symlinked (Modules never are) into the flat skills directory (`~/.claude/skills`), each pointing back into this tree. Verify on macOS/Linux with:

```bash
ls -la ~/.claude/skills | grep -c '\-> .*/.terminal/skills/'   # expect 54
```
