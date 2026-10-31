# Step 8 — Upgrade-Path Verification Against a Real Database

A fresh-database test is not sufficient: it exercises `CreateTable` on an empty schema and will pass while the upgrade path destroys data.

## Path A — Upgrade from the baseline, with data (mandatory for renames/backfills)

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

Then assert in SQL:
- Row counts survived in the **renamed** table, and the values are the ones you inserted.
- The history table survived with its rows.
- A table whose name was freed and reused is **empty** and has the **new** column set.
- System versioning is back **on** for every temporal table touched.
- Computed columns exist with the right definition.

## Path B — Round trip (`Down` then `Up`)

Run `database update <BaselineMigration>` then `database update` again. Assert the data returns to its original table and the column count reverts, then that re-applying restores the new shape. A `Down()` that cannot run is a `Down()` nobody can roll back with.

## Path C — Fresh database

Run the integration test suite that builds a database from scratch (TestContainers or equivalent).

## Tear down

```bash
docker rm -f mig-verify
```
