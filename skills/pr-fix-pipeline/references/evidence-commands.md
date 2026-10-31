# Pipeline Evidence Collection Commands

On-demand reference for [SKILL.md](../SKILL.md) › *Step 2: Collect the Evidence*.

---

## Azure DevOps

Always pass `--org <org-url>` (`pr-host` › *Organization URL*) and `--project <project>` explicitly (never rely on `--detect`, and never stash flags in a single shell variable in zsh). The run to diagnose and watch is the Build policy's `context.buildId`, not the newest row of `runs list`:

```bash
# Required checks on the PR — which policy is red, and which build it points at
az repos pr policy list --id <prId> --org <org-url> \
  --query "[].{policy:configuration.type.displayName,status:status,build:context.buildId,eval:evaluationId,blocking:configuration.isBlocking}" -o table

# Run history on the PR merge ref (for flake/history comparison)
az pipelines runs list --org <org-url> --project <project> --branch "refs/pull/<prId>/merge" --top 10 \
  --query "[].{id:id,def:definition.name,result:result,commit:sourceVersion,finished:finishTime}" -o json

# Failed records in the run's timeline → step names, log ids, issue messages
az devops invoke --org <org-url> --area build --resource timeline \
  --route-parameters project=<project> buildId=<runId> --api-version 7.1 \
  --query "records[?result=='failed'].{type:type,name:name,log:log.id,issues:issues[].message}" -o json

# One step's log as plain lines (`-o tsv` unwraps {value:[...]})
az devops invoke --org <org-url> --area build --resource logs \
  --route-parameters project=<project> buildId=<runId> logId=<logId> --api-version 7.1 \
  --query "value" -o tsv | grep -nE '##\[error\]|error [A-Z]+[0-9]+|\[Test Failure\]|failed|FAIL'
```

## GitHub Actions

```bash
gh pr checks <n>
gh run list --branch <headRef> --limit 10 --json databaseId,name,conclusion,headSha
gh run view <runId> --log-failed
```

## Always Also Gather

- **History of the same check**: recent runs of that definition on the target branch (`--branch refs/heads/main`) and other PRs (red everywhere → base/infra problem; red only here → this diff).
- **Whether the run is stale on either side**: inspect the PR merge commit's parents (`git log -1 --format=%p <mergeCommit>` = `<target> <source>`):
  - Source parent ≠ PR head → branch moved since the run.
  - Target parent behind `origin/<target>` → check whether `<target>` already fixed the failure (`git log <targetParent>..origin/<target>`). On Azure DevOps, confirm `git ls-remote origin refs/pull/<id>/merge` has updated before re-queuing (also inspect `isExpired`, `buildIsNotCurrent`, `lastMergeTargetCommitId` on the Build policy `context`).
- **Pipeline YAML**: read the executed YAML and its included templates at the PR's commit (`git show <sha>:<path>`).
- **Upcoming error warnings**: deprecated tasks, agent image migrations, runtime EOL (record separately under *Review section*).
