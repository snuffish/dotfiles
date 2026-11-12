# Parity audit lessons

Traps that hid or faked findings in earlier audits. Keep entries generic: name the library behaviour, not the project's open findings or PR threads (this registry is public).

## Evidence

- **Docs describe a policy, not whether it runs.** A scheduler's XML docs said a missed run "fires once now" (Quartz.NET's Smart policy = `FireAndProceed`). The decompiled startup path (`XmlSchedulingDataProcessor`) replaces each declared trigger with `StartTime=now` on every start, unless `ScheduleTriggerRelativeToReplacedTrigger` is set, so the misfire policy never acts after downtime. Read the code path that runs at startup, not only the option's doc comment.
- **"Not determinable" means "not decompiled yet".** The old library's misfire, self-overlap, retry and transaction-enlistment behaviour could all be answered from `~/.nuget/packages/<id>/<version>` with `ilspycmd`.
- **Old behaviour can be worse than its comment.** An old comment said the scheduler "never overlaps executions"; its loop did not await and its concurrency gate was off by default. Check what a comment claims.

## Runtime observation

- **Read the scheduler's tables before the proof.** Trigger start times equal to the last node start, and no history for daily jobs after an outage, surfaced the top finding before any verifier returned.
- **Same host, same id.** `InstanceId = {MachineName}-{role}` gives two local processes one id. The joining node then "recovers" the live node's jobs, and both share one state row. Use a container with its own `--hostname` for the real two-node case.
- **An empty source table makes the proof vacuous.** A migration job fired once a minute on two nodes but had no source table to read, so the fire count proved timing only. A seeded run (N rows → N jobs, distinct keys) proved the effect.
- **A serialised job never races its own lock.** With cluster-wide `DisallowConcurrentExecution`, a SQL `UPDLOCK, READPAST` guard is never contended. Say "one import per row in a two-node cluster", not "the lock holds".

## Process

- **Recount numbers.** "9 daily jobs" was really 10. Recount from the trigger list, not from memory of the rows.
- **Earlier decisions beat your open question.** A question this audit called open had already been settled by a production check in a PR thread, and only the earlier artifacts said so. Check them before calling a question open.
- **A published .NET app run from another cwd** needs `--contentRoot <publish dir>`, or appsettings is missing and options validation fails at start.
