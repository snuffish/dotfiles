# Post-Fix Execution & Autonomous Remediation Loop

On-demand reference for [SKILL.md](../SKILL.md) › *Step 7: Post-Fix Execution & Autonomous Remediation Loop (after `/proceed`)*.

---

## Remediation Loop Steps

Once the user opens the gate with `/proceed` (or a plain reply per `core` › *The `/proceed` gate*):

1. **Implement and verify locally**: apply the fix in `repo-root` and run the plan's local verification commands (`core` › *Post-edit verification*).
2. **Commit and push (or re-queue)**:
   - When code changed: stage, run pre-commit gates, commit, and push following [`/commit`](../../commit/SKILL.md) Steps 2–5.
   - When no code change was needed (verified flake or stale merge ref): re-queue the red Build policy evaluation:
     ```bash
     az repos pr policy queue --id <prId> --evaluation-id <evaluationId> --org <org-url>
     ```
3. **Resolve the triggered run**:
   - **Azure DevOps**: query `az repos pr policy list --id <prId> --org <org-url> --query "[?configuration.type.displayName=='Build']"` to get the new `context.buildId` and evaluation status. Confirm `context.buildId` changed from the failed run's ID; if unchanged after a poll, pause as an external blocker rather than watching the old build.
   - **GitHub Actions**: query `gh pr checks <prId>` or `gh run list --branch <headRef>`.
4. **Watch run progress (no early exit)**:
   - Monitor until terminal status (`succeeded`, `failed`, `partiallySucceeded`, `canceled` on ADO; completed conclusion on GitHub) using non-blocking schedule timers / reactive notifications (never blocking shell `sleep` loops).
   - **Azure DevOps**: `az pipelines build show --id <buildId> --org <org-url> --project <project> --query "{status:status, result:result}"`
   - **GitHub**: `gh pr checks <prId>` or `gh run view <runId>`
5. **Loop until verified green**:
   - **All required checks green (`succeeded` / `approved`)**: mark the plan `Completed` and emit the completion block below.
   - **Still red, failing, or flaky**: pull the new failing step logs ([evidence-commands.md](evidence-commands.md)), classify the remaining failure, update the investigation and plan artifacts, apply the fix, verify locally, commit/push (or re-queue), and return to step 3.
   - **External blocker exception** (service outage, offline agent pool, missing credentials, manual approval gate): pause, cite the exact platform error, and emit the paused block below.

---

## Completion & Pause Blocks

Once verified green:
```markdown
✅ **Pipeline verified passed by agent** — **<repo> PR !<id>**
- Pipeline run: <pipeline> run <runId> (commit `<sha>`)
- Required checks: all green (`approved` / `succeeded`)
- Total iterations: <n>
```

If paused on an external blocker:
```markdown
⚠️ **Paused on external blocker (Skill incomplete)** — **<repo> PR !<id>**
- Pipeline run: <pipeline> run <runId>
- Blocker: <reason requiring human action>
- Waiting for: <unblocking action> before resuming verification loop.
```
