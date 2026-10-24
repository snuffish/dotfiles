# Release Notes Swedish Language Guide & Templates

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
