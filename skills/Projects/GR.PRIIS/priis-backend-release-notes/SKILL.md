---
name: priis-backend-release-notes
description: "[Project: GR.PRIIS.Backend] Generate and publish Swedish release notes to the PRIIS wiki from closed user stories and bugs in a sprint. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# priis-backend-release-notes

Use this skill when the user asks to run `/priis-backend-release-notes`.

## Modules

Read these before step 1:
- `~/.terminal/skills/_modules/core.md`
- `~/.terminal/skills/_modules/artifact-protocol.md`: writes no artifact — the draft is shown in chat and published to the PRIIS wiki only after the user confirms it

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

Write with the two previous releases from Step 2b open as the model for terms, phrasing and tone. Where they and the rules below disagree, follow the published releases, and point out the conflict to the user.

**Source priority for each work item:**

1. **Completed PRs** (collected in Step 3b) — these reflect what was actually merged and shipped. Read the PR `title` and `description` and base the text primarily on that information.
2. **User story title** — use as fallback when no completed PRs are linked, or when all PR titles are too technical to derive a user-facing sentence from.

Additional rules when using PR data:
- If a work item has one or more PRs and their content **diverges noticeably** from the user story title, **prefer the PR** and append a review annotation to that bullet in the draft: `[Avviker från user story — kontrollera]`
- If no PRs were found for a work item, write from the user story title as usual and append: `[Inga kopplade PR — baserat på user story-titel]`
- Remove all annotations before publishing (Step 7) — they are for the review step only.

---

**Höjdpunkter** — each one is:

```markdown
### Global sökning
Klicka på "Sök…" i sidhuvudet eller tryck Ctrl+K för att söka bland verksamheter, matchningsärenden, användare och avtalsmallar. Innan du har skrivit något visas dina senast öppnade poster under "Senast visade".
```

- A short name (2–5 words) as the `###` heading, then 2–3 sentences: what it is, who uses it, and where it is found.
- Here the role may be the sentence subject (`Kontaktperson väljer nu…`), since the section isn't role-specific.
- For a first version of an insight or statistics feature, one sentence on its value is welcome. Say what the user can conclude from it, e.g. `Detta ger en fingervisning om vad som efterfrågas relativt vad verksamheten har`. Only mention possible future extensions when the user story or the user says so; never invent a roadmap.
- **Screenshots** make highlights much easier to take in. The team adds them in the wiki editor; the build downloads wiki attachments and shows them in PRIIS. Don't invent image links. In Step 6, ask whether the user wants to add a screenshot to each highlight, and if so leave the image line to them: `![Kort beskrivning av bilden](/.attachments/<filnamn>.png)` under the paragraph.

**Role sections and För alla** — one bullet per item:

```markdown
- **Pris per artikel** – Klicka på totalpriset i ett matchningsförslag eller i fliken "Översikt" för att se priset per artikel, delområde och avtalsnummer. Gäller även Lokal inköpssamordnare.
```

- Start with a bold name of 1–4 words, then an en dash (` – `), then **one** sentence (a short second sentence only when it is needed to say where the feature is or who else gets it).
- The role is already in the heading, so don't open with `Registeradministratör kan nu…` under `## För Registeradministratör`. Describe the feature: what it does and where it is.
- Leave detail out: default values, every column name, every status. If a support article on docs.priis.se exists, link it inline once: `[läs mer](https://docs.priis.se/...)`. Only use a URL you already have from context — never invent one.

**Mindre förbättringar och rättningar** — one short line per item, without a bold name:

```markdown
- Avtalsnummer sorteras nu i nummerordning, så att 10630-14 kommer före 10630-133.
```

- Describe the outcome (what works now), not the bug. The old closing phrase `— det är nu åtgärdat.` is no longer needed in this section.
- The longer `Problemet som <vilka användare> upplevde med <vad>, … är nu åtgärdat.` form is still right when a problem hit many users and they should recognize it (see the example in Step 3c).
- Bug fixes go here, not in a separate Rättningar section.

**Rules for all text:**

- **User perspective only** — describe what the user can now do or what works better, not what was changed in code.
- **Quote exact UI text** — field labels, button text, tab names, statuses, category names — in quotation marks exactly as they appear in the product, e.g. `"Kräver åtgärd"`, `"Använd som mall"`, `"Relaterade ärenden"`. **Keep the product's casing.** PR descriptions often write labels in lowercase prose ("påbörjad matchning"), while the UI shows "Påbörjad matchning". When a PR doesn't show the label verbatim, check the frontend's Swedish strings, or capitalise the first word as PRIIS labels do.
- **Name registerärenden by their category**, as it appears in the register ticket list (e.g. `ett dagligt Registerärende för kategorin "Daglig granskning av nya användare"`), not by a tab or internal feature name inside the ticket. State what the handler does with it in terms of the outcome (`granskas och vid behov korrigeras`), not the mechanics (`kommenteras`).
- **Use the full PRIIS domain terms**: `matchningsförfrågan`, not just `förfrågan`; `matchningsärende`, not just `ärende`, when the type isn't obvious from context. House spelling is `istället` (not `i stället`).
- **Be concrete, not vague.** State the actual old→new values, thresholds or time intervals instead of settling for "tydligare" or "bättre" alone. Compare the too-vague "Filtret är förbättrat" against "Filtret "Visa" går nu att använda för att filtrera på flera svarsstatusar samtidigt".
- **Forbidden words:** backend, frontend, API, endpoint, databas, migrering, refaktorering, komponent, hook, query, deployment. Replace with plain Swedish.
- Swedish throughout.

**Date line** (directly under the `# {version}` heading, as in the template): the deploy date from Step 1, written in Swedish with the month spelled out in lowercase, e.g. `5 oktober 2026`.

**Write as of the deploy date.** Functionality that is switched on as part of that production deploy counts as available in this release. Examples are a federated login whose config flag is flipped at the deploy, or a background job that starts running at the deploy. Describe it in plain present tense ("kan nu…"), like everything else. When the user confirms in Step 3c that something will be enabled at the deploy, include it without any caveat in the text.

**Sammanfattning** (required — without it no teaser appears on the PRIIS start page):
- 3–5 sentences, opening `I version {version} …`.
- Name the release's most notable concrete features by how they'd appear in the product, not generic category descriptions ("en ny startsida", "en PDF-sammanfattning", not "förbättrad översikt"). These are usually the Höjdpunkter.
- What will users notice the most when they log in after the update?
- Name the roles the way the section headings do (e.g. `Handläggare och Placeringshandläggare`).
- Leave out items that only reach a narrow audience, such as a single municipality's new login option.
- Proofread the Swedish: write `hur efterfrågan ser ut`, not `vad efterfrågan ser ut`.

---

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

## Output example

```markdown
# 2.10.0
19 oktober 2026

## Sammanfattning
I version 2.10.0 finns en ny global sökning i sidhuvudet, där du snabbt hittar verksamheter, matchningsärenden, användare och avtalsmallar. Kontaktperson kan nu ange vilka rum, lägenheter eller familjehem verksamheten erbjuder när en matchningsförfrågan besvaras, och Handläggare och Placeringshandläggare ser de valda verksamhetsobjekten i matchningsärendet. Registeradministratör och Dataanalytiker får den nya statistiksidan "Verksamheternas mottaglighet", som visar platsläget per kategori.

## Höjdpunkter

### Global sökning
Klicka på "Sök…" i sidhuvudet eller tryck Ctrl+K för att söka bland verksamheter, matchningsärenden, användare och avtalsmallar. Innan du har skrivit något visas dina senast öppnade poster under "Senast visade".

### Verksamheternas mottaglighet
Registeradministratör och Dataanalytiker följer nu platsläget per kategori på den nya sidan "Verksamheternas mottaglighet" under "Statistik". Där syns hur många verksamheter som haft pausad mottaglighet eller svarat "Nej, vi har ingen ledig plats".

## För alla
- **Notifikationer** – Mer kompakta, med tidsfrister synliga även i PRIIS. Sidan "Notifikationer" visar om en notifikation är "Öppnad", "Läst" eller "Oläst".

## För Handläggare och Placeringshandläggare
- **Pris per artikel** – Klicka på totalpriset i ett matchningsförslag eller i fliken "Översikt" för att se priset per artikel, delområde och avtalsnummer. Gäller även Lokal inköpssamordnare.

## För Registeradministratör
- **IVO-impuls** – Ett nytt Registerärende för kategorin "IVO-impuls" skapas när IVO:s Placeringsstöd har ändrats. Fliken "IVO-ändringar" visar före och efter per verksamhet.

## Mindre förbättringar och rättningar
- Kalendern i datumfälten täcker inte längre själva fältet.
- Avtalsnummer sorteras nu i nummerordning, så att 10630-14 kommer före 10630-133.
```
