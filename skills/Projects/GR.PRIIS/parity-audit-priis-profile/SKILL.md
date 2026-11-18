---
name: parity-audit-priis-profile
description: "[Project: GR.PRIIS] Command profile adapting /parity-audit to PRIIS: the Quartz job scope and lane split, the shared scheduler wiring to cite, local-stack recipes for a second Worker (container with its own hostname, same-id second container), QRTZ history queries with tick conversion, and the approved-seed recipe for TickerQ leftovers. Load with parity-audit in the GR workspace. Load ONLY when working in the GR.PRIIS repository or the GR folder that holds it."
user-invocable: false
---

# `parity-audit-priis-profile` — PRIIS project profile for `/parity-audit`

Reference data for the general `parity-audit` skill (`/parity-audit`). Steps, gates and the report shape belong to `/parity-audit`; this profile only answers its fields for PRIIS. Shared PRIIS fields (Layout, Tracker, Report language, …) are in the `priis-profile` skill › _Profile fields_. Local-stack rules (write approval, snapshot and restore) are the repo skill `priis-local-stack`'s; read its §1 before Step 6. Facts were _verified 2026-11-12_ on the Quartz migration branch; recheck line numbers on yours. `<lib>` below = `backend/source/GR.PRIIS.Library`; type it out in commands.

---

## Profile fields

| Field | Value |
| --- | --- |
| **Units (Quartz jobs)** | Cron jobs: `git -C <repo> grep -n "CronTrigger(" <new> -- backend/source/GR.PRIIS.Library` (15 when verified). Event jobs: `git -C <repo> grep -n ") : BusinessEventJob<" <new> -- backend/source/GR.PRIIS.Library` (32 when verified; the bare `: BusinessEventJob<` also hits the generic constraints in `IEventJobScheduler.cs`), subclasses of `BusinessEventJob<>` (`<lib>/Common/Events/BusinessEventJob.cs`); each sits in its event's file under `<lib>/Feature/<area>/Events` (Register also `Register/Contracts/Events`), except `ProcessMatchingInquiryHalfTimeReminderJob` in `Matching/Jobs`. |
| **Units at the old ref (TickerQ)** | Cron: `git -C <repo> grep -n "cronExpression:" <old> -- backend/source/GR.PRIIS.Library` (13 when verified). All functions (45 when verified: 13 cron + 32 event): `git -C <repo> grep -n "TickerFunction(functionName" <old> -- backend/source/GR.PRIIS.Library`. |
| **Scope → paths** | A feature name covers `<lib>/Feature/<area>/**`: its `Jobs` and `Events` (Register also `Contracts/Events`). Register = 5 cron + 6 event jobs when verified. `<lib>/Common/Jobs` is infrastructure plus one counted cron unit, `TickerQLeftoverImportJob` (new-only; writes the TickerQ and QRTZ tables). `<lib>/Feature/Caching` holds the cron unit `DistributedCacheCleanupJob`. |
| **Shared wiring** | `<lib>/Setup.cs` `AddPriisQuartz` (`:391`): InstanceId `{MachineName}-{role}-{ProcessId}` from `PriisScheduler.InstanceId` (`<lib>/Common/Jobs/PriisScheduler.cs:18`) `:401`, time zone `:412`, thread pool `:413`, clustered ADO store `:414-431`, execution history `:437-448`, cron registration `q.AddDeclaredJobs()` `:432` (source-generated from `[CronTrigger]`; the schedule anchor), DI scan of `IJob` types `:450-454`. Callers: `backend/source/GR.PRIIS.Worker/Program.cs:79` (role `worker`; hosted service `:105`), `backend/source/GR.PRIIS.API/Program.cs:100` (`api`), `backend/source/GR.PRIIS.CLI/Program.cs:52` (`cli`). Also `<lib>/Common/Events/IEventJobScheduler.cs` (enlistment), `<lib>/Common/Jobs/PriisScheduler*.cs`. |
| **Shared wiring at the old ref** | `<lib>/Setup.cs:388` `AddPriisTickerQ`, called from `Worker/Program.cs:78` (NodeIdentifier `:85`), `API/Program.cs:100`, `CLI/Program.cs:52`. Exception handler `<lib>/Common/TickerQ/PriisTickerExceptionHandler.cs:11`; event retries `Retries = 3` in `<lib>/Common/Events/IEventJobScheduler.cs:88,119`. |
| **Lane split** (whole subsystem) | Matching (`<lib>/Feature/Matching/**`) · Register + Operations + Control + Feedback + Communication (`<lib>/Feature/{Register,Operations,Control,Feedback,Communication}/**`) · Ivo + Caching + infra (`<lib>/Feature/Ivo/Jobs`, `<lib>/Feature/Caching`, `<lib>/Common/Events`, `<lib>/Common/Jobs`). |
| **Docs to check against** | `backend/docs/Worker.md` (cron rules `:192-196`; the leftover-import section). |
| **Package cache** | `~/.nuget/packages/quartz*/<ver>`, `~/.nuget/packages/tickerq*/<ver>`; version in `backend/Directory.Packages.props`, or `obj/project.assets.json` for transitive packages (`TickerQ.Utilities` holds `TickerFunction`). Decompile with `ilspycmd -p -o <scratchpad>/<pkg>src <dll>`. |
| **Earlier artifacts** | `~/.cache/agent-artifacts/GR.PRIIS/` and the legacy location in `artifact-protocol` rule 4: list `*<PR>*`, `*<work item>*`, `*quartz*` and `*tickerq*`, but open them only at Step 7. |

## Step 5–6 — Local-stack recipes

Run each as its own Bash call from the repo root; long-running ones with `run_in_background`. `<connection string>` = `Server=<host>,1433;Database=…;User Id=…;Password=…;TrustServerCertificate=true` with the values from the repo skill `priis-local-stack` §2. Never write the password into this file.

1. **Stack.** `dotnet run --project backend/source/GR.PRIIS.AppHost` (starts Docker's SQL container; `open -a Docker` first on the Mac). Its Worker is `<MachineName>-worker-<pid>`.
2. **Publish HEAD's Worker.** `quiet dotnet publish backend/source/GR.PRIIS.Worker -c Release -o <scratchpad>/worker2`.
3. **Second Worker with its own id** (the production-like case). Image: `backend/Dockerfile:53`.
   ```bash
   docker run -d --name priis-worker2 --hostname priis-worker2 -v <scratchpad>/worker2:/app -w /app -e DOTNET_ENVIRONMENT=Development -e ASPNETCORE_URLS=http://+:8080 -e "ConnectionStrings__PriisDbContext=<connection string, host host.docker.internal>" -e Email__Host=host.docker.internal -e Email__Port=2525 mcr.microsoft.com/dotnet/aspnet:11.0 dotnet GR.PRIIS.Worker.dll
   ```
   `docker logs priis-worker2` should show `instanceId 'priis-worker2-worker-1'` (the process id is 1 in a container) and "1 beside this one".
4. **Same-id case** (only when it matters; not yet run, so treat the expected output as unproven). The id ends in the process id (`PriisScheduler.InstanceId`), so a native run on the same machine no longer collides. Two containers with the same `--hostname` do, since both run as process 1: repeat the step 3 command with `--name priis-worker3 --hostname priis-worker2`, so both report `instanceId 'priis-worker2-worker-1'`. Expect a single `QRTZ_SCHEDULER_STATE` row for that id.
5. **Wait** with `wait-port.sh` (curl `/healthz`) or a background `sleep`; a standalone foreground `sleep` is blocked.

## Step 5–6 — Queries (`priis-local-stack` `db.py`, read-only)

Quartz stores .NET ticks. To get UTC: `DATEADD(SECOND, <col>/10000000 - 62135596800, '1970-01-01')`.

| Purpose | SQL core |
| --- | --- |
| Trigger state | `SELECT TRIGGER_NAME, TRIGGER_STATE, MISFIRE_INSTR, <start>, <next>, <prev> FROM dbo.QRTZ_TRIGGERS WHERE TRIGGER_TYPE = 'CRON'` |
| Fires per minute and node | `SELECT JOB_NAME, CONVERT(char(16), <fired>, 120), COUNT(*), STRING_AGG(INSTANCE_NAME, ',') FROM dbo.QRTZ_EXECUTION_HISTORY WHERE JOB_NAME IN (…) AND <fired> >= '<start>' GROUP BY …` |
| Failures, run time | `… SUM(CASE WHEN SUCCEEDED = 1 THEN 1 ELSE 0 END), MAX(RUN_TIME) … GROUP BY JOB_NAME, INSTANCE_NAME` |
| Live nodes | `SELECT INSTANCE_NAME, <LAST_CHECKIN_TIME> FROM dbo.QRTZ_SCHEDULER_STATE` |

## Step 6 — Seeded TickerQ leftovers (needs the user's approval)

The local DB has no `TickerQ` schema; check with `SELECT SCHEMA_ID(N'TickerQ')`.

- **DDL.** Copy `backend/tests/GR.PRIIS.API.IntegrationTests/Common/Jobs/TickerQLeftoverImportJobTests.cs:171-183`.
- **Statuses.** Idle 0, Queued 1, InProgress 2, Done 3, Cancelled 6 (`:19-23`).
- **Payload.** UTF-8 JSON `{"SelectionId":"<guid>","TraceParent":null,"TraceState":null}` (`:167`), built with `CONVERT(varbinary(max), CONVERT(varchar(max), …))`.
- **Function and due time.** Use `ProcessMatchingInquiryHalfTimeReminderJob` rows due in 30 days, so nothing sends.
- **Run.** Pass the seed on stdin: `db.py --yes --snapshot "<count of QRTZ_JOB_DETAILS in that JOB_GROUP>" --restore "<restore>" < seed.sql`.
- **Restore** (assumes a baseline count of 0):
  ```sql
  DELETE s FROM dbo.QRTZ_SIMPLE_TRIGGERS s JOIN dbo.QRTZ_TRIGGERS t ON t.SCHED_NAME = s.SCHED_NAME AND t.TRIGGER_NAME = s.TRIGGER_NAME AND t.TRIGGER_GROUP = s.TRIGGER_GROUP WHERE t.JOB_GROUP = '<job class>'
  DELETE FROM dbo.QRTZ_TRIGGERS WHERE JOB_GROUP = '<job class>'
  DELETE FROM dbo.QRTZ_JOB_DETAILS WHERE JOB_GROUP = '<job class>'
  DROP TABLE [TickerQ].[TimeTickers]
  DROP SCHEMA [TickerQ]
  ```
- **Assert.** Moved rows (`Status = 6`, `SkippedReason = 'Moved to Quartz'`) = Quartz jobs = distinct `DESCRIPTION` = triggers.
- **Which node did it.** `UpdatedAt` on the moved rows, matched against `QRTZ_EXECUTION_HISTORY`. The Worker's logs go to the Aspire dashboard, not to the AppHost's stdout.
