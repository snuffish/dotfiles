---
name: source-command-backend-release-notes
description: "[Project: GR.PRIIS.Backend] Generate and publish Swedish release notes to the PRIIS wiki from closed user stories and bugs in a sprint. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# source-command-release-notes

Use this skill when the user asks to run the migrated source command `release-notes`.

## Command Template

# /release-notes — Versionsnyheter

Generate consumer-facing Swedish release notes from a sprint's closed work items and publish them to the PRIIS wiki.

**Usage:**
```
/release-notes [version] [sprint]
/release-notes 2.3.0 Sprint 41
/release-notes Sprint 41
/release-notes 2.3.0
/release-notes
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

## Step 1 — Resolve sprint

Call `mcp__azure-devops__work_list_team_iterations` for team `PRIIS Team` in project `PRIIS`.

- If a sprint argument was given: match by name (e.g. `Sprint 41`) or number (e.g. `41` → `Sprint 41`).
- If no sprint argument: use the iteration where `timeFrame == current`.

Report the resolved sprint name and date range before continuing.

---

## Step 2 — Fetch template (always fresh)

Call `mcp__azure-devops__wiki_get_page_content` with:
- wiki ID: `3d10e9b3-ed20-4e70-8ff5-6457aa76eefc`
- path: `/Startsida/Versionsnyheter/Så skriver du versionsnyheter/Mall för ny versionsnyhet`

Use the returned template as the authoritative structure for the release notes. Never assume the template — always fetch it.

---

## Step 3 — Fetch and process work items

1. Call `mcp__azure-devops__wit_get_work_items_for_iteration` for the resolved iteration path.
2. Collect all work item IDs and batch-fetch full details via `mcp__azure-devops__wit_get_work_items_batch_by_ids`, requesting fields: `System.WorkItemType`, `System.Title`, `System.State`, `System.Parent`, `System.Tags`.
3. Filter to **done states only**: `Closed` and `Ready for test`.
4. Separate by work item type:
   - **User Story** → classify in Step 4a
   - **Bug** → apply inclusion rule below, then classify in Step 4b
   - **Task** → retain for now (needed to find linked PRs in Step 3b); exclude from release note sections

---

## Step 3b — Fetch linked PRs for each work item

For each **User Story** and each **included Bug** (after applying the bug inclusion rule below):

1. Call `mcp__azure-devops__wit_get_work_item` with `expand: "relations"` to fetch the full relations list.
2. From the relations, extract two things:
   - **Child task IDs** — relations whose `url` is a work item link and whose `rel` type indicates a child (`System.LinkTypes.Hierarchy-Forward`). Alternatively, match tasks already collected in Step 3 whose `System.Parent` equals this story's ID.
   - **Directly linked PR IDs** — relations where `rel == "ArtifactLink"` and the `url` matches the pattern `vstfs:///Git/PullRequestId/{repoGuid}/{prId}`. Extract both `repoGuid` and the numeric `prId`.
3. For each child **Task** ID identified, call `mcp__azure-devops__wit_get_work_item` with `expand: "relations"` and extract linked PR IDs using the same `vstfs:///Git/PullRequestId/{repoGuid}/{prId}` pattern.
4. Deduplicate PR IDs across the story and all its child tasks.
5. For each unique PR, call `mcp__azure-devops__repo_get_pull_request_by_id` with:
   - `pullRequestId` = the extracted numeric PR ID
   - `repositoryId` = the extracted `repoGuid` (use the GUID directly)
   - `project` = `PRIIS`
   - Collect: `title`, `description`, `status`. **Only use PRs with status `Completed`** — abandoned or active PRs were not shipped.
6. Store the resulting PR list keyed by parent work item ID (story or bug). Log a one-line summary per work item: `#<id> "<title>" → N PR(s) found`.

---

**Bug inclusion rule:**

| Condition | Include? |
|-----------|----------|
| Tagged `Hotfix` | ❌ No — already deployed separately |
| No parent | ✅ Yes |
| Parent is Feature | ✅ Yes |
| Parent is User Story | ❌ No — covered by the story |

Check `System.Tags` first — if the value contains `Hotfix` (case-insensitive), exclude the bug regardless of parent. For bugs that pass the tag check and have a `System.Parent` set, call `mcp__azure-devops__wit_get_work_item` on the parent ID and inspect `System.WorkItemType`.

---

## Step 4a — Classify User Stories

For each closed User Story, assign it to one of two sections based on its title:

- **Det här är nytt** — introduces functionality users couldn't do before (new screens, new flows, entirely new capabilities, new integrations).
- **Förbättringar** — refines or extends something that already exists (better filtering, smarter forms, more fields, UX polish, performance, notifications).

When in doubt, prefer **Förbättringar**.

---

## Step 4b — Classify Bugs

All included bugs default to **Rättningar**.

Exception: if a bug fix restored a core feature that was completely non-functional, you may elevate it to **Förbättringar**. Use this sparingly — the vast majority of bug fixes belong in Rättningar.

---

## Step 5 — Write user-friendly Swedish descriptions

**Source priority for each work item:**

1. **Completed PRs** (collected in Step 3b) — these reflect what was actually merged and shipped. Read the PR `title` and `description` and base the bullet primarily on that information.
2. **User story title** — use as fallback when no completed PRs are linked, or when all PR titles are too technical to derive a user-facing sentence from.

Additional rules when using PR data:
- If a work item has one or more PRs and their content **diverges noticeably** from the user story title, **prefer the PR** and append a review annotation to that bullet in the draft: `[Avviker från user story — kontrollera]`
- If no PRs were found for a work item, write from the user story title as usual and append: `[Inga kopplade PR — baserat på user story-titel]`
- Remove all annotations before publishing (Step 7) — they are for the review step only.

---

Write one bullet per work item. Rules:

- **User perspective only** — describe what the user can now do or what works better, not what was changed in code.
- **Starter phrases:** `Du kan nu…`, `Det är nu möjligt att…`, `Listan visar nu…`, `Det går nu att…`, `Systemet skickar nu…`
- **For Rättningar:** name the symptom and confirm it is fixed. Example: `Komboboxen för "Välj aktiv roll" saknade kryssruta för att rensa — det är nu åtgärdat.`
- **Forbidden words:** backend, frontend, API, endpoint, databas, migrering, refaktorering, komponent, hook, query, deployment. Replace with plain Swedish.
- Length: one to two sentences per bullet. Concrete and specific.
- Swedish throughout.

**Sammanfattning** (required — without it no teaser appears on the PRIIS start page):
- 2–4 sentences.
- Describe the most notable theme(s) of this release from the user's viewpoint.
- What will they notice the most when they log in after the update?

---

## Step 6 — Show draft and confirm

Print the full draft release notes using the template structure fetched in Step 2.

Annotations added in Step 5 (`[Avviker från user story — kontrollera]` and `[Inga kopplade PR — baserat på user story-titel]`) are visible in the draft — they are review aids for the user, not part of the final text.

Then ask the user:
1. Does the content look correct? Pay attention to any annotated bullets — do they accurately describe what was shipped?
2. Any items to add, remove, or rephrase?
3. What version number should this be published under? (skip if already provided as an argument)

**Do not publish until the user has confirmed. Strip all annotations from the final content before calling Step 7.**

---

## Step 7 — Publish to wiki

Once confirmed, call `mcp__azure-devops__wiki_create_or_update_page` with:
- **wiki ID:** `3d10e9b3-ed20-4e70-8ff5-6457aa76eefc`
- **path:** `/Startsida/Versionsnyheter/{version}` — the page name must be exactly the version number
- **content:** the confirmed markdown (first heading must also be exactly the version number, per wiki rules)

Report the resulting wiki page URL on success.

---

## Output example

```markdown
# 2.3.0

## Sammanfattning
I version 2.3.0 har vi fokuserat på att göra matchningsprocessen smidigare och snabbare.
Du hittar nu fler möjligheter att följa upp ärenden och få rätt information i rätt tid.

## Det här är nytt
- Du kan nu begära ändringar i verksamhetsuppgifter direkt via ett registerärende, utan att
  behöva kontakta administratören separat.
- Prisändringar kan nu schemaläggas med ett framtida startdatum, så att rätt pris tillämpas
  automatiskt när ändringen träder i kraft.

## Förbättringar
- Adressfältet föreslår nu adresser automatiskt när du skriver, vilket minskar risken för
  felstavningar och sparar tid.
- Felmeddelanden i steg-för-steg-formulären visas nu direkt i formuläret i stället för som
  en separat notis.

## Rättningar
- Tid i utskickade e-postmeddelanden visades ibland i fel tidszon — detta är nu åtgärdat.
- Sökfältet för namn fungerade inte alltid korrekt vid mellanslag — det fungerar nu som förväntat.
```
