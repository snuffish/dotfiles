# CLAUDE.local.md — Personal Configuration & Overrides

Detailed patterns and personal orchestrator skills live in the registered skills registry under `/Users/snuffish/.terminal/skills` (see `.agents/skills.json`).

- **Skill profiles:** When invoking `/implement-feature` or `/code-review`, also load `priis-profile` and then the matching `implement-feature-priis-profile` / `code-review-priis-profile`.
- **Repository skills precedence:** Team skills shipped in `.claude/skills/` are canonical for the monorepo; personal registry skills extend them.
- **Registry inventory:** `/Users/snuffish/.terminal/skills/README.md`.

## Every PR has a work item

Applies to every PR I create or draft from a session in this repo, however it was opened (`/commit`, `/pr-desc`, `priis-ship`, by hand). Check right after creating the PR and again when publishing it.

1. Check: `az repos pr work-item list --org <ado-org-url> --id <pr>`. A linked item → nothing to do.
2. None linked → ask me for the parent work item ID. Never guess it; that is the only question. If I answer that there is no work item (e.g. "no ado item, just /commit and /pr-desc"), skip steps 3–6 and do not ask again this session. `/pr-summary` is not a skill; it means `/pr-desc`.
3. Then create the ticket without asking further and report it: `az boards work-item create`, type Task, area `PRIIS`, iteration = the current sprint (the parent's iteration), assigned to me, title and description in English, description summarising the PR and naming it (`!<pr>`).
4. Link it to the parent (`az boards work-item relation add --relation-type parent`) and to the PR (`az repos pr work-item add`).
5. Set its state to match the PR: `Active` for a draft, `Pull Request` once published.
6. Add `Resolved: #<id>` to the PR description (pass `--draft <isDraft>` on the update so a draft stays a draft).

## Agent skills

Config for the personal Matt Pocock skills (`wayfinder`, `triage`, `to-tickets`, `to-spec`, …). Keep all of this out of team files.

### Issue tracker

Local markdown under `.scratch/<feature>/` (git-ignored), never Azure DevOps.

### Triage labels

Default five roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) as `Status:` lines.

### Domain docs

Single-context: root `GLOSSARY.md`, `frontend/GLOSSARY.md`, `docs/adr/`.