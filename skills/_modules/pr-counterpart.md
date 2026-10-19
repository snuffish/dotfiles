# pr-counterpart

Dual-repo PR counterpart discovery: finds the other half of a change that ships as one PR per repo, and classifies the result.

## Modules

Read these before using this one:
- [git-worktrees.md](git-worktrees.md) (same folder as this file): only its *Repo Resolution* section, to list the repos in the workspace

---

## Counterpart discovery

A change that spans repos ships as **one PR per repo**: backend and frontend, service and client, library and consumer. The halves usually carry different work-item ids and branch names. Any skill that resolves a PR, whether from a URL, an id, a branch or a work item, runs this lookup **every time**, including when the user pasted exactly one PR link. Handling one half alone misses the other half's defects and every contract mismatch between them.

Run it when the workspace holds more than one repo (`git-worktrees` › *Repo Resolution*), or when the resolved PR touches a cross-repo contract that the workspace rulebook names. Check every signal. They are cheap, and each one catches cases the others miss:

| # | Signal | How to check (Azure DevOps; GitHub equivalents in brackets) |
|---|---|---|
| 1 | The PR description or footer names the other PR | `Frontend PR: !<id>`, `Backend PR: !<id>`, `This PR relates to: !<id>`, a `…/pullrequest/<id>` (`…/pull/<n>`) URL |
| 2 | A linked work item has a sibling under the same parent | `az boards work-item show --id <wi> --expand relations`, then `Parent` (`System.LinkTypes.Hierarchy-Reverse`), then the parent's children (`Hierarchy-Forward`). Each sibling's own PR is its `ArtifactLink` named `Pull Request`: `vstfs:///Git/PullRequestId/<projectId>%2f<repoId>%2f<prId>`. Older siblings point at completed PRs; keep the active ones. |
| 3 | A linked work item has a commit in the other repo | An `ArtifactLink` named `Fixed in Commit` whose `<repoId>` is the other repo. Find that repo's PR by `az repos pr list --repository <other> --status active` and match the source commit. |
| 4 | An active PR in the other repo carries the same or a sibling id | `az repos pr list --repository <other> --status active --query "[].{id:pullRequestId,src:sourceRefName,title:title}"`, matched on the ids from signals 1–3 (`gh pr list -R <owner>/<other> --search "<id>"`) |
| 5 | The other repo's checkout is on a matching branch | `git -C <other> rev-parse --abbrev-ref HEAD` |
| 6 | The diff touches a cross-repo contract the rulebook names (shared enum, API shape, generated client or API snapshot, realtime URL) | The counterpart is **expected**, even when signals 1–5 find nothing |

Never conclude "no counterpart" from signal 4 alone: sibling halves usually carry different work-item ids. Fetch the counterpart's metadata, work items and head with the same commands as the primary PR. For Azure DevOps that means `--org https://dev.azure.com/<org>`; the legacy `<org>.visualstudio.com` host fails auth.

## Classification

State the result in the first lines of the output and in the artifact's context table:

- **Found:** `<repo> !<id>` @ `<short-sha>` (`<source-ref>`). It joins the scope; each skill's hook says what that means for it.
- **Found, excluded:** the user explicitly limited the scope ("backend only"). Still report its id and head, and treat every contract check against it as not done.
- **Expected but missing:** signal 6 fired, or a description names a PR that is not live (abandoned, unpushed, never created). This is a finding, not a footnote.
- **None:** no signal fired. Say "single-repo change" once.
