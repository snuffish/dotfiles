---
name: priis-backend-release-notes
description: "[Project: GR.PRIIS.Backend] Generates formatted Swedish release notes for a sprint or tag. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
disable-model-invocation: true
---

# priis-backend-release-notes

Use this skill when the user asks to run `/priis-backend-release-notes`.

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../../../_modules/core.md`
- `../../../_modules/artifact-protocol.md`: writes no artifact — the draft is shown in chat and published to the PRIIS wiki only after the user confirms it

---

## Command Template

# /priis-backend-release-notes — Versionsnyheter

Generate consumer-facing Swedish release notes from a sprint's closed work items and publish them to the PRIIS wiki.

**Usage:**
```
/priis-backend-release-notes [version] [sprint]
/priis-backend-release-notes 2.3.0 Sprint 41
/priis-backend-release-notes Sprint 41
/priis-backend-release-notes 2.3.0
/priis-backend-release-notes
```

- `version` — semver string (e.g. `2.3.0`). Ask the user if not provided.
- `sprint` — sprint name or number (e.g. `Sprint 41` or `41`). Defaults to the current active sprint.

---

## ADO & Wiki constants

| Key | Value |
|-----|-------|
| Project | `PRIIS` |
| Team | `PRIIS Team` |
| Wiki ID | `3d10e9b3-ed20-4e70-8ff5-6457aa76eefc` |
| Template wiki path | `/Startsida/Versionsnyheter/Så skriver du versionsnyheter/Mall för ny versionsnyhet` |
| Release notes parent path | `/Startsida/Versionsnyheter` |

---

## The format (since 2.10.0)

Users voted for release notes grouped by **who the change is for**, not by type of change. The PRIIS frontend (`/release-notes` page) parses the `##` headings: it shows the reader's own role sections first and collapses the other roles. **The heading text is therefore a contract — write it exactly as below.**

Sections, in this order (leave out a section that would be empty, except Sammanfattning):

1. `## Sammanfattning` — required. The fetch script extracts it as the start-page teaser.
2. `## Höjdpunkter` — the 2–3 most notable features, each as `### <Kort namn>` followed by a short paragraph.
3. `## För alla` — changes that reach (nearly) every user regardless of role.
4. `## För <Roll>` sections, in this fixed order, combining roles that share a persona:
   1. `## För Handläggare och Placeringshandläggare`
   2. `## För Lokal inköpssamordnare`
   3. `## För Lokal avtalshanterare`
   4. `## För Verksamhetsledare och Kontaktperson`
   5. `## För Registeradministratör`
   6. `## För Registervårdare`
   7. `## För Synpunktshanterare`
   8. `## För Dataanalytiker`
   9. `## För Systemadministratör`
5. `## Mindre förbättringar och rättningar` — small polish and all bug fixes, one line each.

**Role names in `## För …` headings** must be bare PRIIS role names, joined with `, ` and ` och ` (e.g. `## För Verksamhetsledare och Kontaktperson`). Allowed names: Handläggare, Placeringshandläggare, Lokal inköpssamordnare, Lokal avtalshanterare, Verksamhetsledare, Kontaktperson, Registeradministratör, Registervårdare, Synpunktshanterare, Dataanalytiker, Systemadministratör. "Handläggare" covers both "Handläggare självständig" and "Handläggare med guidning". Never write "Förfrågningsbesvarare" — that role exists only to make testing easier and is not used in production. Don't invent other headings such as `## Nyheter för leverantörer`; the frontend won't recognize them as role sections.

---

## Step 1 — Resolve sprint

Call `mcp__azure-devops__work` with `action: "list_team_iterations"`, `team: "PRIIS Team"`, `project: "PRIIS"`.

- If a sprint argument was given: match by name (e.g. `Sprint 41`) or number (e.g. `41` → `Sprint 41`).
- If no sprint argument: use the iteration where `timeFrame == current`.

Report the resolved sprint name and date range before continuing.

**Compute the deploy date.** PRIIS is deployed to production on the **first Monday after the sprint's `finishDate`**. Sprint 47, for example, ends Friday 2 October 2026 and is deployed Monday 5 October 2026. Report this date together with the sprint, and use it as the release date in the notes (see Step 5). Don't use the sprint's last day, and don't use the day the notes are generated.

---

## Step 2 — Fetch template (always fresh)

Call `mcp__azure-devops__wiki` with `action: "get_page_content"`:
- `wikiIdentifier`: `3d10e9b3-ed20-4e70-8ff5-6457aa76eefc`
- `project`: `PRIIS` — required alongside `wikiIdentifier` (the call is rejected without it unless a full `url` is passed instead)
- `path`: `/Startsida/Versionsnyheter/Så skriver du versionsnyheter/Mall för ny versionsnyhet`

Use the returned template for the date line, the reminders and any wording the team has added. If it disagrees with **The format** above (e.g. it still shows Nytt/Förbättringar/Rättningar), follow this file and tell the user the template needs updating.

---

## Step 2b — Fetch the two previous releases (style reference)

The published pages reflect the team's own final edits, so they are the best guide to current house style. The rules in this file can lag behind them.

1. Call `mcp__azure-devops__wiki` with `action: "get_page"`, `wikiIdentifier`, `project: "PRIIS"`, `path: "/Startsida/Versionsnyheter"` and `recursionLevel: "OneLevel"` to list the version pages.
2. Sort the version-numbered subpages by semver. Pick the two highest that are lower than the version being written, e.g. 2.11.0 and 2.10.0 when writing 2.12.0. Ignore non-version pages such as "Så skriver du versionsnyheter".
3. Fetch both with `action: "get_page_content"`. Keep them at hand for Step 5 and the comparison in Step 6.

Releases up to and including 2.9.0 use the old Nytt/Förbättringar/Rättningar layout. When one of the two previous releases is in the old layout, use it for terms, role names and the overlap check only, not for structure or bullet style.

These pages also cover two other checks: the "fixed earlier but never announced" check in Step 3c, and spotting items that were already announced.

---

## Step 3 — Fetch and process work items

1. Call `mcp__azure-devops__wit_work_item` with `action: "list_for_iteration"`, `project: "PRIIS"`, `team: "PRIIS Team"`, `iterationId` = the resolved iteration's `id` (a GUID, not the sprint name).
2. The response is a `workItemRelations` tree: root items carry `rel: null`, their child Tasks carry `rel: "System.LinkTypes.Hierarchy-Forward"`. **Collect every ID in the tree, root and child alike** — both are already scoped to this sprint. Batch-fetch full details for all of them via `mcp__azure-devops__wit_work_item` with `action: "get_batch"`, requesting fields: `System.WorkItemType`, `System.Title`, `System.State`, `System.Parent`, `System.Tags`.
3. Filter to **done states only**: `Closed` and `Ready for test`. (`Resolved` does not count as done.)
4. Separate by work item type, using each item's own `System.Parent`/`System.Tags` fields directly rather than its position in the tree:
   - **User Story** → place in Step 4
   - **Bug** → apply inclusion rule below, then place in Step 4
   - **Task** → retain for now (needed to find linked PRs in Step 3b); exclude from release note sections

---

## Step 3b — Fetch linked PRs for each work item

For each **User Story** and each **included Bug** (after applying the exclusion rules below):

1. Call `mcp__azure-devops__wit_work_item` with `action: "get"`, `expand: "Relations"` to fetch the full relations list. Note: `get_batch` does **not** support `expand` — relations require one `get` call per item, so this step is inherently one call per story/bug plus one per child task, not a batch.
2. From the relations, extract two things:
   - **Child task IDs** — relations whose `url` is a work item link and whose `rel` type indicates a child (`System.LinkTypes.Hierarchy-Forward`). Alternatively, match tasks already collected in Step 3 whose `System.Parent` equals this story's ID.
   - **Directly linked PR IDs** — relations where `rel == "ArtifactLink"` and the `url` matches the pattern `vstfs:///Git/PullRequestId/{repoGuid}/{prId}`. Extract both `repoGuid` and the numeric `prId`.
3. For each child **Task** ID identified, call `mcp__azure-devops__wit_work_item` with `action: "get"`, `expand: "Relations"` and extract linked PR IDs using the same `vstfs:///Git/PullRequestId/{repoGuid}/{prId}` pattern.
4. Deduplicate PR IDs across the story and all its child tasks.
5. For each unique PR, call `mcp__azure-devops__repo_pull_request` with `action: "get"`:
   - `pullRequestId` = the extracted numeric PR ID
   - `repositoryId` = the extracted `repoGuid` (use the GUID directly — see known GUIDs below)
   - `project` = `PRIIS`
   - Collect: `title`, `description`, `status`. **Only use PRs with `status: 3` (Completed)** — abandoned or active PRs were not shipped.
6. Store the resulting PR list keyed by parent work item ID (story or bug). Log a one-line summary per work item: `#<id> "<title>" → N PR(s) found`.

**Known repository GUIDs** (avoids a lookup round-trip):

| Repository | GUID |
|---|---|
| GR.PRIIS.Backend | `80d21315-a334-4b2f-a335-5a50fe19b9ef` |
| GR.PRIIS.Frontend | `52f22501-89d8-4c3d-a987-f597ebeaacf9` |
| GR.PRIIS.Docs | `64d6ae39-3fbf-4d5b-a15f-2066a6ab6cc3` |

---

## Step 3c — Exclusion rules

Apply all of the following before placing items. An item can be excluded for more than one reason — any single match is enough to drop it.

**Hotfix tag — applies to both User Stories and Bugs, not just Bugs.** A work item tagged `Hotfix` (case-insensitive, check `System.Tags`) was already built and deployed outside the normal sprint cadence, and its release was very likely already announced in an earlier version. This is true even when the work item's own `System.State` only flipped to `Closed` in the *current* sprint — the close date lags the actual deploy. When in doubt, check whether the linked PR's `closedDate` falls well before the current sprint's start date; if so, treat it as already-announced and exclude it, and say so when presenting the draft (don't silently drop it).

**Bug parent check** (bugs only):

| Condition | Include? |
|-----------|----------|
| Tagged `Hotfix` | ❌ No — already deployed separately |
| No parent | ✅ Yes |
| Parent is Feature | ✅ Yes |
| Parent is User Story | ❌ No — covered by the story |

For bugs that pass the tag check and have a `System.Parent` set, call `mcp__azure-devops__wit_work_item` with `action: "get"` on the parent ID and inspect `System.WorkItemType`.

**Fixed earlier but never announced — still include.** A bug investigated and closed in this sprint may turn out to have been fixed already in an earlier release, for example "by accident" by another PR. The linked PR may then only add a regression test. Do **not** exclude it for that reason. Check whether the problem is mentioned in the previous releases fetched in Step 2b. If it is not, the users who hit the problem have never been told it is gone, so include it under "Mindre förbättringar och rättningar". Write it from the affected users' experience and, when known, say when the problem started. Example (2.9.0, bug #30812): `Problemet som vissa handläggare upplevde med matchningsformuläret, att uppgifter försvann från olika fält och att matchningsärenden inte gick att skapa, är nu åtgärdat. Felet uppstod i samband med att utkast-funktionalitet introducerades i början på september.` Only exclude it when the earlier release notes already announced the fix.

**Non-production or not-yet-live functionality.** Exclude a work item — regardless of type — when its shipped functionality will never be encountered by a general PRIIS user in production:
- Restricted to non-production environments on purpose (e.g. a role or account that exists only to make manual testing easier in test/utb/dev). The role "Förfrågningsbesvarare" (`RoleType.InquiryResponder`) is such a role: it holds permissions in the access rules, but never name it.
- Shipped behind a configuration flag or secret that is explicitly disabled by default and not yet turned on in production (check the PR description for phrasing like "flip to true once the secret is loaded"). Ask the user whether it will be switched on at the deploy before excluding it.
- Affects only a narrow internal/admin audience outside PRIIS's own user base (e.g. permissions on the documentation website's own admin tooling, not the PRIIS product itself).

Flag these in the draft as excluded with a one-line reason instead of silently dropping them, so the user can override if the judgment call was wrong.

**New automated/background jobs need explicit confirmation.** A scheduled process (an auto-reminder job, an auto-closure job, a nightly cleanup) can merge cleanly, close its work item, and still be deliberately held back from running in production pending more monitoring or testing — with nothing in the PR text signaling that, because there's no user-facing config flag to describe. Unlike a disabled OIDC provider or a non-prod-only role, this case is **not detectable from the PR description alone**. For any work item whose shipped behavior is a background job that runs unattended and affects data, notifications, or ticket state at scale, ask the user to confirm it is actually enabled and running in production before including it in the draft — don't infer this from a `Completed` PR status.

**Pure technical/refactor work.** If a User Story's own title and description describe an internal refactor, domain/database separation, or similar with no end-user-visible behavior change, exclude the whole item — even when the linked PR's description mentions an incidental bug fix uncovered along the way. Don't invent a vague "performance/stability" filler bullet for it; the historical release notes never use generic under-the-hood lines like that. If the incidental fix looks genuinely user-visible and worth surfacing on its own, flag it for the user with the `[Avviker från user story — kontrollera]` annotation from Step 5 and let them decide — default expectation is that they'll say exclude it.

---

## Step 4 — Place each item

Every included item appears **exactly once** in the notes. Decide where:

1. **Find the audience.** User stories are written around personas (Lena/Hadya/Samir, Faisal/Ludvig, Amalia, Kaj, Ines), and one persona usually corresponds to several PRIIS roles. Look up the `SystemAction` the PR mentions (or the endpoint's `Policy(...)`) in `source/GR.PRIIS.Library/Common/Users/AccessRules/Roles/*AccessRules.cs` in GR.PRIIS.Backend and note the roles that are the feature's real users. Roles that only hold the permission incidentally can be left out. If unsure, list the candidate roles in the draft and let the user prune.
2. **Pick 2–3 Höjdpunkter.** The features users will notice most after the update: a new page, a new way of working, something many roles meet. These go only under `## Höjdpunkter`, not again in a role section.
3. **Bug fixes and small polish** (a calendar that no longer covers its field, a page moved to the right address, sort order corrected) go to `## Mindre förbättringar och rättningar`. Exception: a fix that restored a core feature that was completely non-functional for a role may go in that role's section instead. Use this sparingly.
4. **Everything else** goes in the section of its primary audience:
   - Reaches (nearly) every user regardless of role → `## För alla`. Don't use För alla just because two or three roles are involved.
   - Otherwise → the `## För <Roll>` section of the main users. When a feature also reaches a role from another section, mention it in the sentence (`Gäller även Lokal inköpssamordnare.`) instead of repeating the bullet.
5. Within a section, put the most notable item first.

---

## Step 5 — Write user-friendly Swedish descriptions

Draft the user-facing Swedish copy for Höjdpunkter, role sections, and Mindre förbättringar.
Follow [Swedish Language Guide & Templates](references/release-notes-swedish-template.md) for section layout, Swedish grammar conventions, screenshot placeholders, and output examples.

## Step 6 — Compare with the previous releases, then show draft and confirm

Before showing the draft, compare it with the two releases fetched in Step 2b and revise it where it departs from them:
- **Terms.** Use the same names for the same roles, screens, tabs, reports and concepts. If an earlier release says "matchningsförfrågan", "Rapport Matchningsärenden" or "Handläggare", don't introduce a synonym or a shortened form.
- **Wording.** For releases in the role-grouped format, match their bold names, sentence length and level of detail per bullet.
- **Overlap.** Remove or rephrase any item that one of them already announced.
- **Headings.** Check every `##` heading against **The format**: exact section names, allowed role names, fixed order, no empty sections.

Mention briefly in the draft message what you adjusted after the comparison, so the user can see what came from the previous releases.

Print the full draft release notes.

Annotations added in Step 5 (`[Avviker från user story — kontrollera]` and `[Inga kopplade PR — baserat på user story-titel]`) are visible in the draft — they are review aids for the user, not part of the final text.

Then ask the user:
1. Does the content look correct? Pay attention to any annotated bullets — do they accurately describe what was shipped?
2. Are the Höjdpunkter the right ones, and is each item in the right section?
3. Any items to add, remove, or rephrase?
4. Do you want to add screenshots to the Höjdpunkter? (They are added in the wiki editor after publishing.)
5. What version number should this be published under? (skip if already provided as an argument)
6. Is the deploy date correct? (It is the Monday after the sprint ends. It can differ around holidays or a postponed deploy.)

**Do not publish until the user has confirmed. Strip all annotations from the final content before calling Step 7.**

---

## Step 7 — Publish to wiki

Once confirmed, call `mcp__azure-devops__wiki_upsert_page` with:
- **wiki ID:** `3d10e9b3-ed20-4e70-8ff5-6457aa76eefc`
- **path:** `/Startsida/Versionsnyheter/{version}` — the page name must be exactly the version number
- **content:** the confirmed markdown (first heading must also be exactly the version number, per wiki rules)

The build only picks up direct subpages of `/Startsida/Versionsnyheter` whose first heading equals the page name. Drafts or format proposals that must not reach users belong under `Så skriver du versionsnyheter`, which the build skips.

Report the resulting wiki page URL on success.

---

## Fallback when the azure-devops MCP server is unavailable

The Azure CLI (`az` with the `azure-devops` extension, defaults `organization=https://dev.azure.com/grutbildning`, `project=PRIIS`) can do every step:

| Step | Command |
|---|---|
| Iterations | `az boards iteration team list --team "PRIIS Team" --project PRIIS` |
| Sprint items | `az devops invoke --area work --resource workitems --route-parameters project=PRIIS team="PRIIS Team" iterationId=<guid> --api-version 7.1-preview` |
| Work item + relations | `az boards work-item show --id <id> --expand relations` |
| PR | `az repos pr show --id <prId>` |
| Wiki page | `az devops invoke --area wiki --resource pages --route-parameters project=PRIIS wikiIdentifier=<wikiId> --query-parameters "path=<path>" includeContent=true --api-version 7.1 --out-file <file>` |
| Publish | `az devops wiki page create` / `update --wiki <wikiId> --path <path> --file-path <file> --encoding utf-8` |

Encoding pitfalls on Windows PowerShell: `az` writes cp1252 to the console, so set `[Console]::OutputEncoding = [Text.Encoding]::GetEncoding(1252)` before capturing its output, or Swedish characters are mangled. Characters outside cp1252 (→, …) are dropped from console output, so verify a published page by reading it back with `--out-file`, never from the console. `az.cmd` cuts arguments at newlines and breaks on `&`, so pass long text via `--file-path`.

---
