# CLAUDE.local.md — Personal Configuration & Overrides

Detailed patterns and personal orchestrator skills live in the registered skills registry under `/Users/snuffish/.terminal/skills` (see `.agents/skills.json`).

- **Skill profiles:** When invoking `/implement-feature` or `/code-review`, also load `priis-profile` and then the matching `implement-feature-priis-profile` / `code-review-priis-profile`.
- **Repository skills precedence:** Team skills shipped in `.claude/skills/` are canonical for the monorepo; personal registry skills extend them.
- **Registry inventory:** `/Users/snuffish/.terminal/skills/README.md`.

## Agent skills

Config for the personal Matt Pocock skills (`wayfinder`, `triage`, `to-tickets`, `to-spec`, …). Docs live in `.agents/docs/` (git-ignored); keep all of this out of team files.

### Issue tracker

Local markdown under `.scratch/<feature>/` (git-ignored), never Azure DevOps. See `.agents/docs/issue-tracker.md`.

### Triage labels

Default five roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) as `Status:` lines. See `.agents/docs/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md`, `frontend/GLOSSARY.md`, `docs/adr/`. See `.agents/docs/domain.md`.
