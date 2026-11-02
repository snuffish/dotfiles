# CLAUDE.local.md — Personal Configuration & Overrides

Detailed patterns and personal orchestrator skills live in the registered skills registry under `/Users/snuffish/.terminal/skills` (see `.agents/skills.json`).

- **Skill profiles:** When invoking `/implement-feature` or `/code-review`, also load `priis-profile` and then the matching `implement-feature-priis-profile` / `code-review-priis-profile`.
- **Repository skills precedence:** Team skills shipped in `.claude/skills/` are canonical for the monorepo; personal registry skills extend them.
- **Registry inventory:** `/Users/snuffish/.terminal/skills/README.md`.
