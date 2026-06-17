# Skills

Local skill registry. This is a **source-of-truth / staging** area — it is not
itself loaded by any tool. Activate skills by pointing a loader at this tree, or
by symlinking individual skills into a live skills root (e.g. `~/.claude/skills/`).

Each skill is a directory containing `SKILL.md` with `name` + `description`
frontmatter. The directory name always equals the `name` field, and every skill
name is globally unique — so a flat loader can symlink any skill in without
collisions.

## Layout

```
skills/
  <general skills>/          # reusable across any project (e.g. modern-csharp)
  Projects/
    <Project>/               # everything scoped to one project lives here
      <skill>/
```

- **Top level** = general, project-agnostic skills.
- **`Projects/<Project>/`** = skills scoped to a specific project. Add a new
  folder per project as more are onboarded.

Currently:

| Path                 | Contents                                                  |
| -------------------- | --------------------------------------------------------- |
| `modern-csharp/`     | General C# 14 idioms — reusable in any C# project.        |
| `Projects/GR.PRIIS/` | All skills for the GR.PRIIS product (backend + frontend). |

## Naming convention (inside `Projects/GR.PRIIS/`)

| Prefix                                                   | Meaning                                                                                                         |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `backend-*`                                              | Specific to **GR.PRIIS.Backend** (.NET / FastEndpoints / EF Core).                                              |
| `frontend-*`                                             | Specific to **GR.PRIIS.Frontend** (React / RTK Query / TanStack Router).                                        |
| `source-command-backend-*` / `source-command-frontend-*` | Ported from a project slash-command (`.claude/commands/`); operational recipes rather than reference knowledge. |

The `backend-`/`frontend-` prefix still distinguishes the two apps within the
single GR.PRIIS product folder, and keeps every skill name unique.

Every project-specific skill is also **gated in its `description`**: it opens
with `[Project: GR.PRIIS.X]` and closes with
`Load ONLY when working on the GR.PRIIS.X project or in the GR repository.`

## Activating

The live skill ecosystem on this machine (`~/.claude/skills`, `~/.agents/skills`)
is **flat** — each skill is a direct child of the root (`root/<name>/SKILL.md`),
with no grouping folders. To activate from this grouped staging tree, symlink the
specific skills you want:

```bash
ln -s ~/.terminal/skills/Projects/GR.PRIIS/backend-ef-core ~/.claude/skills/backend-ef-core
# ...or loop over a project's skills:
for d in ~/.terminal/skills/Projects/GR.PRIIS/*/; do
  ln -s "$d" ~/.claude/skills/"$(basename "$d")"
done
```

(If the loader you use globs recursively — `skills/**/SKILL.md` — point it at this
root directly and the grouping is honored as-is.)

## Provenance notes

- Skill bodies are verbatim copies of the project sources, except:
  - `modern-csharp` — deliberately generalized (title + description) from the
    backend's `modern-csharp` skill; the C# 14 idioms apply to any C# project,
    though some examples still use PRIIS types for illustration.
  - `Projects/GR.PRIIS/backend-dry` — authored to match the `dry` skill
    referenced in the backend `AGENTS.md`; every pattern maps to symbols that
    exist in the repo.
- The backend `AGENTS.md` also references a `dotnet-best-practices` skill, but no
  `SKILL.md` exists for it in the source repo, so it was not brought over.
