---
name: squash-ef-core-migrations
description: "Collapse several EF Core migrations on a feature branch into one clean migration. Use when a PR has accumulated multiple incremental migrations and should ship a single one, or when asked to squash/combine/consolidate/tidy migrations. Covers the safety gate, preserving hand-written SQL the scaffolder cannot reproduce, and verifying the upgrade path against a real database before trusting the result."
---

# Squash EF Core migrations

Replace N migrations added on a branch with one migration that produces the identical schema while preserving hand-written SQL (renames, backfills, temporal-table toggles) that the EF Core scaffolder cannot reproduce.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — the deliverable is the squashed migration itself
- `../_modules/git-worktrees.md`

On-demand references (`references/`):
- [`references/upgrade-path-verification.md`](references/upgrade-path-verification.md) — Step 8 Docker SQL Server verification (Path A baseline upgrade with data, Path B `Down`/`Up` round trip, Path C fresh DB)

- This skill rewrites migration history: run the safety gate below first, and when invoked from a plan, only after `/proceed`.
- Check the project's migration conventions before scaffolding (e.g. in GR.PRIIS, read the repo team skill `priis-backend-ef-core` §13 for project paths and trimmed `.Designer.cs` conventions).

---

## Non-negotiable safety gate

Squashing rewrites migration history. Do it **only** for migrations that exist nowhere but this branch (`<default>` is the repo's integration branch, e.g. `main` or `develop`):

```bash
# Which migrations does this branch add that the integration branch does not have?
git diff $(git merge-base HEAD origin/<default>)...HEAD --name-only --diff-filter=A \
  | grep -E 'Migrations/.*\.cs$' | grep -v Designer
```

**Stop and ask the user** if any candidate migration:
- exists on `origin/<default>` or any release branch, or
- has been applied to a shared environment (dev/test/staging/prod), or
- is referenced in a deployment script or `__EFMigrationsHistory` outside a local database.

Rewriting an applied migration desynchronises `__EFMigrationsHistory`. A local database you can drop is fine.

---

## Step 1 — Inventory and classify every migration you are about to delete

Read all candidate migrations in full before deleting anything:

| Class | Signal | Consequence |
|---|---|---|
| **Scaffolded** | Only `CreateTable`/`AddColumn`/`CreateIndex`/`AlterColumn` calls | Safely regenerated |
| **Hand-written** | `migrationBuilder.Sql(...)`, renames, data backfills, custom SQL, guards | **Cannot be regenerated — must be re-injected by hand** |

Read any doc comments inside the migrations — they record what the scaffolder got wrong previously. Watch for:
- **Table/column renames** (EF diffs by *name* and never infers a rename; see Step 6 › *The rename trap*).
- **Data movement / backfills** (`UPDATE`, `INSERT ... SELECT`, computed backfills).
- **Temporal (system-versioned) tables** (DDL that toggles `SYSTEM_VERSIONING` off and on).
- **Guards (`IF EXISTS`)** written for a specific database state.

## Step 2 — Back up before deleting

```bash
BACKUP=$(mktemp -d -t mig-backup.XXXXXX)
cp <MigrationsDir>/<each-candidate>* "$BACKUP"/
cp <MigrationsDir>/<Context>ModelSnapshot.cs "$BACKUP"/snapshot-branch.cs
echo "$BACKUP"
```

## Step 3 — Establish the baseline

The baseline is the newest migration that is **not** being squashed. Find it by name on `origin/<default>` (a branch that merged `origin/<default>` may interleave timestamps):

```bash
git ls-tree -r --name-only origin/<default> -- <MigrationsDir> \
  | grep -E '/[0-9]{14}_.*\.cs$' | grep -v Designer | sed 's#.*/##' | sort | tail -3
```

## Step 4 — Delete and reset the snapshot

```bash
rm <MigrationsDir>/<candidate>.cs <MigrationsDir>/<candidate>.Designer.cs   # for each candidate
git -C <repo-root> checkout origin/<default> -- <MigrationsDir>/<Context>ModelSnapshot.cs
```

Verify the baseline snapshot does not contain the branch's new entities (`grep -cE '<NewEntityA>|<NewEntityB>' <MigrationsDir>/<Context>ModelSnapshot.cs` → `0`), and confirm the migration count via `find` (not `ls`).

## Step 5 — Scaffold one migration

```bash
dotnet ef migrations add <Name> \
  --project <LibraryProject> --startup-project <StartupProject> --context <Context>
```

A design-time `HostAbortedException` in output is normal for a web startup project; look for the trailing `Done.` Check project migration conventions (such as trimmed `.Designer.cs` files).

## Step 6 — Audit the generated migration (the step that matters)

Catalogue what the scaffold emitted (`grep -nE 'migrationBuilder\.|name: "|table: "' "$NEW"`) and compare against every hand-written migration from Step 1.

### The rename trap

Given `OldName` → `NewName`, EF sees two unrelated tables and emits either:
1. `DropTable(OldName)` + `CreateTable(NewName)` — destroys every row and temporal history.
2. **Silent mutation** — if `OldName` is immediately reused by a *different* new entity, EF emits `AddColumn` for the new entity's fields onto the **old table** plus an empty `CreateTable(NewName)`. Existing rows stay in a table that now means something else entirely, with no warning or error.

Both require re-injecting the hand-written rename in Step 7.

## Step 7 — Re-inject hand-written operations

Compose from the backed-up originals rather than patching a broken scaffold:
1. Operations that must precede the rename (e.g. adding columns to an untouched table).
2. Hand-written SQL, verbatim from `$BACKUP`.
3. Scaffolded `CreateTable`/`CreateIndex` blocks, with follow-up `AddColumn` migrations folded into `CreateTable` (preserving type, nullability, default, and `computedColumnSql`).
4. Check ordering by hand: a rename that frees a name runs **before** anything creating that name; `Down()` drops new tables **before** the reverse rename; indexes match their target table.
5. Confirm snapshot agreement: `dotnet ef migrations has-pending-model-changes --project <LibraryProject> --startup-project <StartupProject> --context <Context>`.

## Step 8 — Verify against a real database

Read and execute [`references/upgrade-path-verification.md`](references/upgrade-path-verification.md):
- **Path A**: migrate a real SQL container to `<BaselineMigration>`, seed rows (and history rows for temporal tables), apply the squashed migration, and assert row counts, column sets, and `SYSTEM_VERSIONING`.
- **Path B**: round-trip `Down()` to `<BaselineMigration>` and `Up()` again.
- **Path C**: run the integration test suite on a fresh database.

## Step 9 — Finalise

- Run the repo's formatter and full test suite.
- Confirm the file count: one new migration (and `.Designer.cs` per project convention), N×2 deletions, one snapshot change.
- Document the hand-written part **in the migration itself** so future squashes see it in Step 1.

---

## Pitfalls

| Pitfall | Guard |
|---|---|
| Silent rename-and-reuse mutation | Assert the reused table is empty and the renamed one has the rows (Step 8 Path A) |
| Baseline picked as "newest timestamp among mine" or snapshot not reset | Resolve baseline on `origin/<default>` (Step 3) and reset `<Context>ModelSnapshot.cs` (Step 4) |
| `ls \| grep '^2026'` finding nothing | `ls` may be aliased; use `find` |
| `cd` in a compound command breaking later relative paths | Use absolute paths under `<repo-root>` or a subshell `(cd <repo-root> && …)` |
| `STRING_AGG` collation conflict in verification SQL | Use `UNION ALL` of scalar counts instead |
| Temporal table rename failing | Toggle `SYSTEM_VERSIONING = OFF`, rename current **and** history tables plus PK/FK/index names, then back `ON` with `DATA_CONSISTENCY_CHECK` |
