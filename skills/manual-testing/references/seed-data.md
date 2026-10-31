# Seeding Local Test Data (`--seed-data`)

On-demand reference for [SKILL.md](../SKILL.md) › *Step 8 — Seed the data (`--seed-data` only)*.

---

1. **Local only**: verify the connection string or base URL points at `localhost` or a local container. Never seed shared dev, test, staging, production, or cloud hosts — if pointed elsewhere, seed nothing, report the target, and finish the plan without seeding.
2. **Stack already running**: `--seed-data` never starts, builds, or migrates anything. If the local DB or API is unreachable, put the seed commands in *Test data* as `not run — <why>` and lead *Before you start* with the start command.
3. **Reuse before creating**: query current local state first. Reuse existing matching records; create a dedicated record for any scenario that consumes its precondition so scenarios stay order-independent.
4. **Tooling precedence** (every command/endpoint/table read from the repo):
   1. The project's own local-data skill or scripts (e.g. a `*-local-stack` skill with guarded write scripts) — its write rules win.
   2. The app's API as a role permitted to perform the action (runs real validation and domain rules).
   3. Documented additive seed/fixture commands.
   4. Raw SQL through the project's DB helper last (note on the record that domain validation was bypassed).
5. **Confirmation gates**:
   - Creating new records or updating records created in this run → runs under `--seed-data` without an extra prompt.
   - Modifying any pre-existing record → print `before → after` (with dry-run if available) and ask first.
   - Delete, truncate, reseed, or database recreate → label **destructive** and ask separately for each.
6. **Verify and record**: read back every seeded record to confirm its state matches the scenario's precondition. Record each real ID, display number, creation command, and undo command under *Test data* (or list failed seeds in *Before you start*).
