# Skills

Local skill registry. This is a **source-of-truth / staging** area. You activate skills either by pointing a workspace skill-loader configuration (`skills.json`) directly at directories in this tree, or by symlinking individual skills into a flat live skills root (e.g. `~/.claude/skills/`).

Each skill is a directory containing `SKILL.md` with `name` + `description` frontmatter. The directory name always equals the `name` field, and every skill name is globally unique — so a flat loader can symlink any skill in without collisions.

## Kinds

Everything in the Registry is one of four kinds (defined in [`../GLOSSARY.md`](../GLOSSARY.md)):

| Kind | What it is | Is a skill? | Examples |
|---|---|:---:|---|
| **Command** | Carries out a workflow, invoked by name or by a matching request | yes | `/code-review`, `/create-ticket`, `squash-ef-core-migrations` |
| **Reference** | Knowledge the model loads by topic, never run as a workflow | yes | `modern-csharp`, `priis-backend-ef-core` |
| **Profile** | Project-specific facts a Command reads to adapt to that project: a base profile shared by the project's Commands, plus one Command profile per Command | yes | `priis-profile`, `implement-feature-priis-profile`, `code-review-priis-profile` |
| **Module** | A shared contract Commands depend on; never runs on its own | **no** | `core`, `artifact-protocol`, `git-worktrees`, `pr-counterpart`, `pr-host`, `project-profile` |

## Layout

```plaintext
skills/
  <general skills>/                # reusable across any project (Commands and References)
  _modules/                        # Modules: plain <name>.md, no frontmatter, never symlinked (ADR-0001)
  Projects/
    GR.PRIIS/                      # everything scoped to the GR.PRIIS product lives here
      priis-backend-<skill>/
      priis-frontend-<skill>/
      priis-profile/                 # base profile: facts every PRIIS Command profile shares
      implement-feature-priis-profile/
      code-review-priis-profile/
```

- **Top level** = general, project-agnostic skills.
- **`_modules/`** = Modules. Neither loader sees them: Claude Code only loads what is symlinked into `~/.claude/skills`, and Antigravity scans only the direct children of each `skills.json` root. Never put a `SKILL.md` in here. See [`../docs/adr/0001-modules-live-outside-skill-loaders.md`](../docs/adr/0001-modules-live-outside-skill-loaders.md).
- **`Projects/<Project>/`** = skills scoped to a specific project. Add a new folder per project as more are onboarded.

## Inventory

62 skills total — 35 general + 27 under `Projects/GR.PRIIS/` — plus 6 Modules.

| Group | Kind | Count | Entries |
| --- | --- | :---: | --- |
| General (top level) | Command | 33 | `artifacts`, `clean`, `code-documentation`, `code-review`, `continue`, `create-skill`, `create-ticket`, `explain`, `expressive`, `implement-feature`, `investigate`, `manual-testing`, `no-worktrees`, `organize`, `plan`, `plan-preview`, `plan-review`, `pr-feedback-review`, `pr-fix-pipeline`, `pr-post-comments`, `pr-summary`, `problem`, `proceed`, `refine`, `resolve-conflicts`, `spec-verification`, `squash-code-review`, `squash-ef-core-migrations`, `suggestion`, `sync-skills`, `verify-assumptions`, `what-am-I-missing`, `worktrees` |
| General (top level) | Reference | 2 | `modern-csharp`, `typescript-conventions` |
| `GR.PRIIS/priis-backend-*` | Reference | 7 | `dry`, `ef-core`, `fastendpoints`, `notifications`, `signalr`, `testing`, `workflow` |
| `GR.PRIIS/priis-frontend-*` | Reference | 6 | `component-patterns`, `forms`, `routing`, `rtk-query`, `testing`, `workflow` |
| `GR.PRIIS/priis-backend-*` | Command | 7 | `health-check`, `migrate-to-tunit` (retired — migration complete), `release-notes`, `review`, `scaffold`, `ship`, `verify` |
| `GR.PRIIS/priis-frontend-*` | Command | 4 | `health-check`, `review`, `scaffold`, `verify` |
| `GR.PRIIS/*-profile` | Profile | 3 | `priis-profile` (base), `implement-feature-priis-profile` (read by `implement-feature`), `code-review-priis-profile` (read by `code-review`) |
| `_modules/` | Module | 6 | `core`, `artifact-protocol`, `git-worktrees`, `pr-counterpart`, `pr-host`, `project-profile` |

(Project skill names are the group prefix + the listed suffix — e.g. `priis-backend-ef-core`, `priis-frontend-verify`. The names match the repo-local copies in each repo's `.claude/skills/`; the `review` skills carry a `references/lessons-from-prs.md` catalog. The repo-local `priis-*-review` on `origin/main` are the upstream; the registry copies are mirrors marked as such.)

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

1. **[`core`](_modules/core.md)**: golden invariants, execution gates (`/proceed`, post-edit verification, worktree opt-in), codebase investigation protocol and the precedence model. Depends on nothing.
2. **[`artifact-protocol`](_modules/artifact-protocol.md)**: host & AI model prefix (`<host>-<model>-`), mandatory contextual suffix, link formats, PR thread links and the canonical artifact catalog.
3. **[`git-worktrees`](_modules/git-worktrees.md)**: worktree isolation. `/code-review` and `/pr-feedback-review` snapshot through it, `/implement-feature` implements in a workspace worktree, and any Command switches to it when its invocation contains the token `/worktrees`, and `/no-worktrees` makes any Command work in place instead. A plain prompt reaches it through the `worktrees` Command, which runs the prompt under it; `no-worktrees` is its in-place counterpart. It hands a `[worktree-context]` block to every delegated skill so no skill acts on the user's main checkout.
4. **[`pr-counterpart`](_modules/pr-counterpart.md)**: finds the sibling-repo PR of a dual-repo change.
5. **[`project-profile`](_modules/project-profile.md)**: how a Command finds, layers and applies a project's Profiles (base profile + Command profile), the shared fields, overrides, upstream content and pointers ([ADR-0003](../docs/adr/0003-profile-resolution-is-a-module.md)). Read by `implement-feature` and `code-review`.
6. **[`pr-host`](_modules/pr-host.md)**: reading a PR from its host: URL parsing, the organization URL (`<org-url>`), `refs/heads/` stripping, resolving the PR from a branch, fetching the PR with its work items and acceptance criteria, fetching threads, and failed fetches ([ADR-0004](../docs/adr/0004-pr-host-access-is-a-module.md)). Read-only. Used by every Command that reads a PR.

A Command lists only the Modules it uses directly; a Module lists its own dependencies. Sections inside a Module are referred to by name (`` `git-worktrees` › *Workspace Lifecycle* ``), never by number. **References** and **Profiles** carry no `## Modules` section and inherit the standards through the precedence model. The order (workspace rulebooks, then project-scoped References and Profiles, then general References, then Modules) is defined once, in [`core` › *Precedence*](_modules/core.md#precedence).

## Naming convention (inside `Projects/GR.PRIIS/`)

| Prefix                                                   | Meaning                                                                                                          |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `priis-backend-*`                                        | Skill specific to **GR.PRIIS.Backend** (.NET / FastEndpoints / EF Core) — a Reference, or a Command for `health-check`, `migrate-to-tunit`, `release-notes`, `review`, `scaffold`, `ship`, `verify`. |
| `priis-frontend-*`                                       | Skill specific to **GR.PRIIS.Frontend** (React / RTK Query / TanStack Router) — a Reference, or a Command for `health-check`, `review`, `scaffold`, `verify`. |
| `<project>-profile`                                      | Base profile: the project's shared fields (layout, tracker, PR tooling, pattern skills, contracts, report language, known drift, worktree setup), loaded before any Command profile. |
| `<command>-<project>-profile`                            | Command profile read by that general Command, only the fields it needs: `implement-feature-<project>-profile` (facts per phase: implementing ID, scaffold, verify, ship), `code-review-<project>-profile` (review checklists, lessons, axis mapping, report additions). |

The `priis-backend-`/`priis-frontend-` prefix matches the names the repos use for their own copies, distinguishes the two apps within the single GR.PRIIS product folder, and keeps every skill name unique.

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

Some loaders (like `~/.claude/skills` on macOS/Linux or `%USERPROFILE%\.claude\skills` on Windows) expect a **flat** root — each skill a direct child (`root/<name>/SKILL.md`), with no grouping folders. To activate from this grouped staging tree, run `skills-sync --apply` from any shell (`claude.bash`; it runs [`sync-skills/sync_skills.py`](sync-skills/sync_skills.py), plain `skills-sync` only reports) or `/sync-skills`, which apply the rule below, or symlink by hand.

**Which skills to link:** every general (top-level) skill and every Profile (`*-profile`). Do **not** link a project Reference or Command that the project's own repo also ships in `.claude/skills/`. Claude Code resolves a name clash as *personal over project*, so the global link would silently override the repo's newer copy. Allow-list the exceptions, one name per line, in `Projects/<Project>/.flat-links`. List the workspaces that use a project in `Projects/<Project>/.workspaces` (one path per line, `~` allowed): the check then warns about a project skill that is neither linked nor shipped by that workspace's repos, and about gaps in its `.agents/skills.json`.

#### macOS / Linux (Bash/Zsh)

```bash
SKILLS="$PWD"   # run from this skills/ folder

# A single skill:
ln -s "$SKILLS/code-review" ~/.claude/skills/code-review

# Every general skill and every Profile, flattened by name:
for d in "$SKILLS"/*/ "$SKILLS"/Projects/*/*-profile/; do
  [ -f "$d/SKILL.md" ] && ln -sfn "${d%/}" ~/.claude/skills/"$(basename "$d")"
done
```

#### Windows (PowerShell)

```powershell
$Skills = (Get-Location).Path   # run from this skills\ folder

# A single skill:
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\skills\code-review" -Value "$Skills\code-review"

# Every general skill and every Profile, flattened by name:
@(Get-ChildItem -Path $Skills -Directory) + @(Get-ChildItem -Path "$Skills\Projects\*\*-profile" -Directory) |
  ForEach-Object { Get-Item (Join-Path $_.FullName "SKILL.md") -ErrorAction SilentlyContinue } | ForEach-Object {
    $srcDir = $_.DirectoryName
    $destDir = Join-Path "$env:USERPROFILE\.claude\skills" $_.Directory.Name
    New-Item -ItemType SymbolicLink -Path $destDir -Value $srcDir -Force
}
```

(If the loader globs recursively — `skills/**/SKILL.md` — point it at this root directly and the grouping is honored as-is.)

**Current live state:** every general skill and the PRIIS Profiles are flat-symlinked into `~/.claude/skills` (Modules never are). A project skill that its own repo also ships in `.claude/skills/` is **not** linked: Claude Code gives personal skills precedence over project skills, so a global link would shadow the repo's newer copy. `/sync-skills` reports the live count and any drift. Check by hand on macOS/Linux with:

```bash
find ~/.claude/skills -maxdepth 1 -xtype l          # dead links: expect none
ls -la ~/.claude/skills | grep -c -- "-> $PWD/"    # links into this tree (run from this skills/ folder)
```
