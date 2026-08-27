---
name: squash-ef-core-migrations
description: "Collapse several EF Core migrations on a feature branch into one clean migration. Use when a PR has accumulated multiple incremental migrations and should ship a single one, or when asked to squash/combine/consolidate/tidy migrations. Covers the safety gate, preserving hand-written SQL the scaffolder cannot reproduce, and verifying the upgrade path against a real database before trusting the result."
---

# Squash EF Core migrations

Replace N migrations added on a branch with one migration that produces the identical schema.

The mechanical part is easy: delete the files, reset the model snapshot, scaffold once. **The part that
breaks production is the audit**, because a regenerated migration is not equivalent to the migrations it
replaces. Everything below exists to protect that difference.

---

## Non-negotiable safety gate

Squashing rewrites migration history. Do it **only** for migrations that exist nowhere but this branch.

```bash
# Which migrations does this branch add that the integration branch does not have?
git diff $(git merge-base HEAD origin/main)...HEAD --name-only --diff-filter=A \
  | grep -E 'Migrations/.*\.cs$' | grep -v Designer
```

**Stop and ask the user** if any candidate migration:

- exists on `main`/`develop` or any release branch, or
- has been applied to a shared environment (dev/test/staging/prod), or
- is referenced in a deployment script or `__EFMigrationsHistory` outside a local database.

Rewriting an applied migration desynchronises `__EFMigrationsHistory`; the next deploy either re-runs DDL
that already happened or silently skips DDL that never did. A local database you can drop is fine — that
is the normal case on a feature branch.

---

## Step 1 — Inventory and classify every migration you are about to delete

Read all of them, in full, before deleting anything. Sort each into:

| Class | Signal | Consequence |
|---|---|---|
| **Scaffolded** | Only `CreateTable`/`AddColumn`/`CreateIndex`/`AlterColumn` calls | Safely regenerated |
| **Hand-written** | `migrationBuilder.Sql(...)`, renames, data backfills, custom SQL, guards | **Cannot be regenerated — must be re-injected by hand** |

Hand-written migrations are the whole reason this task is dangerous. They usually exist *because* the
scaffolder got it wrong once already, and the reason is often recorded in the migration's own doc comment.
Read those comments — they tell you what the scaffolder will do wrong again.

Watch for:

- **Table/column renames.** EF diffs by *name*, so it never infers a rename. See Step 5.
- **Data movement / backfills** — `UPDATE`, `INSERT ... SELECT`, computed backfills.
- **Temporal (system-versioned) tables** — DDL that toggles `SYSTEM_VERSIONING` off and on.
- **Anything guarded by `IF EXISTS`** — written for a specific database state.

## Step 2 — Back up before deleting

```bash
mkdir -p /tmp/mig-backup
cp <MigrationsDir>/<each-candidate>* /tmp/mig-backup/
cp <MigrationsDir>/<Context>ModelSnapshot.cs /tmp/mig-backup/snapshot-branch.cs
```

These are your reference for the hand-written SQL and your diff target in Step 5. Do not rely on `git` alone
— you will be checking files out over the top of them.

## Step 3 — Establish the baseline

The baseline is the newest migration that is **not** being squashed. Find it by name, never by assuming it
is the newest timestamp among the candidates:

```bash
git ls-tree -r --name-only origin/main -- <MigrationsDir> \
  | grep -E '/[0-9]{14}_.*\.cs$' | grep -v Designer | sed 's#.*/##' | sort | tail -3
```

> **The baseline can be newer than the migrations you are squashing.** A branch that merged the integration
> branch will interleave timestamps. That is fine and even desirable — the squashed migration gets a fresh
> timestamp and lands last — but it means "the last migration" is not the same as "the last of mine".

## Step 4 — Delete and reset the snapshot

```bash
rm <MigrationsDir>/<candidate>.cs <MigrationsDir>/<candidate>.Designer.cs   # for each candidate
git checkout origin/main -- <MigrationsDir>/<Context>ModelSnapshot.cs        # snapshot as of the baseline
```

The snapshot must describe the model **at the baseline**, otherwise the scaffolder diffs against the wrong
starting point and emits an empty or partial migration. Taking the integration branch's snapshot is correct
whenever the baseline is that branch's newest migration — verify:

```bash
# Expect 0 hits: the baseline snapshot must not know about your new entities
grep -cE '<NewEntityA>|<NewEntityB>' <MigrationsDir>/<Context>ModelSnapshot.cs
```

Then confirm the count of remaining migrations dropped by exactly the number you deleted (use `find`, not
`ls` — see Pitfalls).

## Step 5 — Scaffold one migration

```bash
dotnet ef migrations add <Name> \
  --project <LibraryProject> --startup-project <StartupProject> --context <Context>
```

A design-time `HostAbortedException` in the output is **normal** for a web startup project. Success is the
trailing `Done.`

## Step 6 — Audit the generated migration (the step that matters)

Never trust the scaffold. Catalogue what it emitted and compare against the originals:

```bash
NEW=<MigrationsDir>/<timestamp>_<Name>.cs
grep -nE 'migrationBuilder\.|name: "|table: "' "$NEW"
```

Then ask, for each hand-written migration from Step 1: **did the scaffolder reproduce this, and how?**

### The rename trap

Given `OldName` → `NewName`, EF sees two unrelated tables and emits one of:

1. `DropTable(OldName)` + `CreateTable(NewName)` — destroys every row and the temporal history. Loud, at
   least, if you read the diff.
2. **Silent mutation** — if the freed name is immediately reused by a *different* new entity, EF sees the
   name present in both models and emits `AddColumn` for the new entity's fields onto the **old table**,
   plus an empty `CreateTable` for the renamed one. Existing rows stay in a table that now means something
   else entirely, and the renamed table arrives empty. This produces no warning and no error.

Both are wrong. The fix is the same: **re-inject the hand-written rename and order it correctly.**

## Step 7 — Re-inject hand-written operations

Prefer **composing from the originals** over patching the scaffold. The original migrations were reviewed
and applied; the scaffold's framing may be wrong in ways that are laborious to unpick.

Write the single migration as:

1. Operations that must precede the rename (e.g. adding columns to an untouched table).
2. The hand-written SQL, verbatim from the backup.
3. The scaffolded `CreateTable`/`CreateIndex` blocks, taken from the original migrations — those were
   generated against the correct baseline, so they are already right.
4. Follow-up migrations folded in: a later `AddColumn` on a table this migration now *creates* becomes a
   column in its `CreateTable`. Preserve the exact type, nullability, default and `computedColumnSql`.

Order constraints to check by hand:

- A rename that frees a name must run **before** anything creating that name.
- `Down()` is the mirror: drop the new tables **before** the reverse rename, so the name is free again.
- Indexes that travelled with a renamed table must not be re-created on it; indexes belonging to the new
  table must be.

Confirm the snapshot still agrees with the model — this catches a column you fumbled in Step 7:

```bash
dotnet ef migrations has-pending-model-changes \
  --project <LibraryProject> --startup-project <StartupProject> --context <Context>
# want: "No changes have been made to the model since the last migration."
```

`has-pending-model-changes` validates the **snapshot**, which the scaffolder wrote. It says nothing about
whether your `Up()` produces that schema. Only Step 8 does.

## Step 8 — Verify against a real database

A fresh-database test is not sufficient. It exercises `CreateTable` on an empty schema and will happily pass
while the upgrade path destroys data.

**Path A — upgrade from the baseline, with data.** The one people skip, and the only one that catches the
rename traps.

```bash
docker run -d --name mig-verify -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='<pw>' \
  -p 14333:1433 mcr.microsoft.com/mssql/server:2022-latest

export CS="Data Source=localhost,14333;Initial Catalog=MigVerify;User ID=sa;Password=<pw>;TrustServerCertificate=True;"

# 1. Bring the database to the baseline — the schema production is actually on
ConnectionStrings__<Name>="$CS" dotnet ef database update <BaselineMigration> \
  --project <LibraryProject> --startup-project <StartupProject> --context <Context>

# 2. Insert rows into every table the migration renames, moves or backfills.
#    For temporal tables, UPDATE a row or two so the history table is non-empty.
#    No seed data? `ALTER TABLE <t> NOCHECK CONSTRAINT ALL` — this tests the DDL, not referential integrity.

# 3. Apply the squashed migration
ConnectionStrings__<Name>="$CS" dotnet ef database update \
  --project <LibraryProject> --startup-project <StartupProject> --context <Context>
```

Then assert, in SQL:

- row counts survived in the **renamed** table, and the values are the ones you inserted;
- the history table survived with its rows;
- a table whose name was freed and reused is **empty** and has the **new** column set;
- system versioning is back **on** for every temporal table touched;
- computed columns exist with the right definition.

**Path B — round trip.** `database update <Baseline>` then `database update` again. Assert the data returns
to its original table and the column count reverts, then that re-applying restores the new shape. A `Down()`
that cannot run is a `Down()` nobody can roll back with.

**Path C — fresh database.** Usually already covered by an integration test suite that builds a database
from scratch (TestContainers or equivalent). Run the full suite.

Finally, tear the container down:

```bash
docker rm -f mig-verify
```

## Step 9 — Finalise

- Run the repo's formatter and full test suite.
- Confirm the file count: one new migration + its `.Designer.cs`, N×2 deletions, one snapshot change.
- Document the hand-written part **in the migration itself** — say what the scaffolder gets wrong and why
  the SQL is hand-written. The next person to squash will read that comment in Step 1. This is how the
  knowledge survives; a commit message does not.

---

## Pitfalls

| Pitfall | Guard |
|---|---|
| Squashing a migration already applied somewhere shared | The safety gate. Ask, don't assume |
| Assuming the scaffold equals the originals | Step 6, every time — especially with a rename |
| Silent rename-and-reuse mutation | Assert the reused table is empty and the renamed one has the rows |
| Baseline picked as "newest timestamp among mine" | Resolve it by name against the integration branch |
| Snapshot left at the branch state | Scaffold comes out empty/partial. Reset it in Step 4 |
| Trusting `has-pending-model-changes` as proof | It checks the snapshot, not your `Up()` |
| `ls \| grep '^2026'` finding nothing | `ls` may be aliased to a table format. Use `find` |
| `cd` in a compound command breaking later relative paths | Use absolute paths, or `cd` once at the start |
| `HostAbortedException` read as failure | Normal for web startup projects; look for `Done.` |
| `STRING_AGG` collation conflict in verification SQL | Use `UNION ALL` of scalar counts instead |
| Temporal table rename failing | Toggle `SYSTEM_VERSIONING = OFF`, rename current **and** history tables plus PK/FK/index names, then back `ON` with `DATA_CONSISTENCY_CHECK` |

## Worked example — GR.PRIIS.Backend

Five migrations collapsed into one. Four were plain scaffolds; one was a hand-written rename of
`Register.OperationObjects` → `OperationActiveCounties`, freeing the name for a brand-new
`OperationObjects` entity — the exact rename-and-reuse shape from Step 6.

```bash
# Paths
MIG=source/GR.PRIIS.Library/DataAccess/Migrations
LIB=source/GR.PRIIS.Library
APP=source/GR.PRIIS.API      # startup project; PriisDbContext

dotnet ef migrations add AddOperationObjects --project $LIB --startup-project $APP --context PriisDbContext
```

The scaffold emitted 17 `AddColumn` calls onto the **existing** `OperationObjects` table plus an empty
`CreateTable("OperationActiveCounties")` — which would have turned every "Verksam även i län" row into a
junk object with `Type = 0` and left the county data homeless. The shipped migration therefore runs the
hand-written `sp_rename` block first, then creates `OperationObjects` fresh.

Verified by migrating a container to the baseline, inserting 2 rows and generating 2 history rows, then
applying: 2 rows + 2 history rows preserved under the new name, new table empty with 22 columns, both tables
still system-versioned, `DisplayName` computed column intact — and the same after a `Down`/`Up` round trip.
