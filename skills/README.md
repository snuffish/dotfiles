# Skills

Local skill registry. This is a **source-of-truth / staging** area. You activate skills either by pointing a workspace skill-loader configuration (`skills.json`) directly at directories in this tree, or by symlinking individual skills into a flat live skills root (e.g. `~/.claude/skills/`).

Each skill is a directory containing `SKILL.md` with `name` + `description` frontmatter. The directory name always equals the `name` field, and every skill name is globally unique — so a flat loader can symlink any skill in without collisions.

## Layout

```plaintext
skills/
  <general skills>/                # reusable across any project (modern-csharp, pr-summary)
  Projects/
    GR.PRIIS/                      # everything scoped to the GR.PRIIS product lives here
      backend-<skill>/
      frontend-<skill>/
      source-command-backend-<skill>/
      source-command-frontend-<skill>/
```

- **Top level** = general, project-agnostic skills.
- **`Projects/<Project>/`** = skills scoped to a specific project. Add a new folder per project as more are onboarded.

## Inventory

26 skills total — 4 general + 22 under `Projects/GR.PRIIS/`.

| Group                            | Count | Skills                                                                                                                |
| -------------------------------- | :---: | -------------------------------------------------------------------------------------------------------------------- |
| General (top level)              |   4   | `code-review`, `modern-csharp`, `pr-summary`, `refine`                                                               |
| `GR.PRIIS/backend-*`             |   7   | `dry`, `ef-core`, `fastendpoints`, `notifications`, `signalr`, `testing`, `workflow`                                 |
| `GR.PRIIS/frontend-*`            |   6   | `component-patterns`, `forms`, `routing`, `rtk-query`, `testing`, `workflow`                                          |
| `GR.PRIIS/source-command-backend-*`  | 6 | `health-check`, `migrate-to-tunit`, `release-notes`, `scaffold`, `ship`, `verify`                                    |
| `GR.PRIIS/source-command-frontend-*` | 3 | `health-check`, `scaffold`, `verify`                                                                                  |

(Skill names are the group prefix + the listed suffix — e.g. `backend-ef-core`, `source-command-frontend-verify`.)

## Naming convention (inside `Projects/GR.PRIIS/`)

| Prefix                                                   | Meaning                                                                                                          |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `backend-*`                                              | Specific to **GR.PRIIS.Backend** (.NET / FastEndpoints / EF Core).                                              |
| `frontend-*`                                             | Specific to **GR.PRIIS.Frontend** (React / RTK Query / TanStack Router).                                        |
| `source-command-backend-*` / `source-command-frontend-*` | Ported from a project slash-command (`.claude/commands/`); operational recipes rather than reference knowledge. |

The `backend-`/`frontend-` prefix distinguishes the two apps within the single GR.PRIIS product folder, and keeps every skill name unique.

Every project-specific skill is also **gated in its `description`**: it opens with `[Project: GR.PRIIS.X]` and closes with `Load ONLY when working on the GR.PRIIS.X project or in the GR repository.`

Load these skills directly by registering their paths in the workspace configuration (e.g. `.agents/skills.json`), replacing `<global_skills_dir>` with the absolute path to your local skills registry (e.g. `/Users/snuffish/.terminal/skills` on macOS/Linux or `C:\Users\username\.terminal\skills` on Windows):

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

**Current live state:** all 24 skills are flat-symlinked into the flat skills directory, each pointing back into this tree. Verify on macOS/Linux with:

```bash
ls -la ~/.claude/skills | grep -c '\-> .*/.terminal/skills/'   # expect 24
```
