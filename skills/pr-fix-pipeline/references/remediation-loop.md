# Remediation Loop

On-demand reference for [SKILL.md](../SKILL.md) › _Step 4_ to _Step 6_.

---

## Narrow reproduction

Use the narrowest filter, then widen to the touched test classes for verification. Prefer the repo's own documented command when it has one.

| Runner                                   | Single test                                                                    | Whole class / file                      |
| ---------------------------------------- | ------------------------------------------------------------------------------ | --------------------------------------- |
| .NET, TUnit / Microsoft.Testing.Platform | `dotnet test --project <tests.csproj> --treenode-filter "/*/*/<Class>/<Test>"` | `--treenode-filter "/*/*/<Class>/*"`    |
| .NET, VSTest (xUnit, NUnit, MSTest)      | `dotnet test <tests.csproj> --filter "FullyQualifiedName~<Class>.<Test>"`      | `--filter "FullyQualifiedName~<Class>"` |
| Playwright                               | `npx playwright test <spec> -g "<title>"`                                      | `npx playwright test <spec>`            |
| Vitest                                   | `npx vitest run <file> -t "<name>"`                                            | `npx vitest run <file>`                 |
| Jest                                     | `npx jest <file> -t "<name>"`                                                  | `npx jest <file>`                       |

To make a FLAKY_TEST fail on purpose: pin the clock to the time from the failing run's log, run the class in reverse or alone, reuse the seed from the log, or use Playwright `--repeat-each 10`. Reproduce it before fixing it, and show it passing under the same forced condition after the fix.

---

## Re-run (INFRA_FLAKE and stale runs)

1. **Ledger first.** Append one line to `<repo-root>/.claude/flake-ledger.md` (create it with the header below if missing). Use an absolute date.
   ```markdown
   # Flake ledger

   | Date       | PR    | Test or job            | Symptom                                              | Run   | Re-runs | Outcome          |
   | ---------- | ----- | ---------------------- | ---------------------------------------------------- | ----- | ------- | ---------------- |
   | 2026-11-04 | !1234 | `OrderTests.Create_Ok` | SQL container exited during startup (Testcontainers) | 98765 | 1       | passed on re-run |
   ```
   Update the same line's `Re-runs` and `Outcome` after each re-run instead of adding a new line.
2. **Re-queue.** Count one re-run for every INFRA_FLAKE job in the run:
   - **Azure DevOps** re-queues the whole Build policy:
     ```bash
     az repos pr policy queue --id <prId> --evaluation-id <evaluationId> --org <org-url>
     ```
   - **GitHub Actions** re-runs only the failed jobs: `gh run rerun <runId> --failed`.

---

## Poll

1. **Find the new run.**
   - **Azure DevOps:** `az repos pr policy list --id <prId> --org <org-url> --query "[?configuration.type.displayName=='Build']"`. Read `context.buildId` and confirm it changed from the failed run. If it has not changed after one poll, treat it as BLOCKED instead of watching the old build.
   - **GitHub:** `gh pr checks <prId>` or `gh run list --branch <headRef>`.
2. **Wait for it to finish.** Check every 3–5 minutes with a non-blocking timer or notification, never a blocking `sleep` loop. Stop when it reaches a terminal state (`succeeded`, `failed`, `partiallySucceeded`, `canceled` on ADO; a conclusion on GitHub).
   - **Azure DevOps:** `az pipelines build show --id <buildId> --org <org-url> --project <project> --query "{status:status, result:result}"`
   - **GitHub:** `gh run view <runId>`

---

## PR description section

Build the new description as **the original description, unchanged**, followed by the section below. If the original already ends with a `## CI fixes` section from an earlier run, replace only that section. Write the whole text to a scratch file first.

```markdown
## CI fixes

| #   | Failure                                      | Class       | Fix                              |
| --- | -------------------------------------------- | ----------- | -------------------------------- |
| 1   | `<job>` › `<test or step>`: <one-line error> | FLAKY_TEST  | `<sha7>` <commit subject>        |
| 2   | `<job>`: <one-line error>                    | INFRA_FLAKE | Re-run 1×, passed (flake ledger) |
```

- **Azure DevOps:** `az repos pr update --id <prId> --org <org-url> --description "$(cat <file>)" --draft <isDraft from Step 1>`. Always pass `--draft` with the PR's current value, because `--description` alone publishes a draft PR. ADO limits a description to 4000 characters. If the result would be longer, shorten the `Failure` cells; if that is not enough, do not write anything. Report it and print the section instead.
- **GitHub:** `gh pr edit <n> --body-file <file>`.

Read the description back and confirm that everything above `## CI fixes` matches the Step 1 copy.

---

## Summary

```markdown
<✅ All builds green | ⚠️ Stopped: fix cap (5) reached | ⚠️ Stopped: re-run cap reached on <job> | ⚠️ Stopped: blocked — <reason>> — **<repo> PR !<id>**

| #   | Job › test | Class       | Root cause | Action     | Commit / run | Result |
| --- | ---------- | ----------- | ---------- | ---------- | ------------ | ------ |
| 1   | …          | REAL_BUG    | …          | Fixed code | `<sha7>`     | ✅     |
| 2   | …          | INFRA_FLAKE | …          | Re-run 1×  | run <id>     | ✅     |

- Fix iterations: <n>/5 · Re-runs: <n> · Final run: <url>
- Flake ledger: <committed in `<sha7>` | uncommitted in the working copy | no entries>
- PR description: `## CI fixes` <added | updated | not written: reason>
```

For a stop that is not green, add one line on what a person must do next.
