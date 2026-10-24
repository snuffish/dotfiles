# Team Skills and Personal Skills reside across a hard ownership seam

The skills ecosystem has two distinct ownership domains: **Personal Skills** in the user's Registry (`~/.terminal/skills/`, `~/.agents/skills/`) and **Team Skills** committed to product repositories (`<repo>/.claude/skills/`).

Personal Skills provide general-purpose developer engines (`code-review`, `implement-feature`, `plan`, `grilling`), generic language references (`modern-csharp`), and project-specific adapters (Profiles like `code-review-priis-profile`). Team Skills (`priis-backend-review`, `priis-fullstack-review`, `priis-backend-modern-csharp`, `priis-backend-workflow`, `priis-ship`) are shared assets owned by the engineering team; they must remain self-contained so team members who clone the repository have full workflow and convention guidance without depending on any personal dotfiles or external registries.

Personal Commands and Profiles interface with Team Skills strictly across a read-only seam: they read conventions and checklists from the repository's `origin/<default>`, but never attempt to delete, replace, or collapse Team Skills into the Personal Registry.

## Considered Options

- **Collapse Team Skills into the Personal Registry.** Rejected: team members do not have the personal registry installed; deleting or bypassing repo-committed skills breaks the developer experience for everyone else on the team.
- **Duplicate all personal workflows inside every product repo.** Rejected: creates maintenance overhead and drift across different client codebases.
- **Treat repo skills as overrides and personal skills as fallbacks.** Followed, but with strict ownership discipline: personal profiles adapt personal engines to the repo's declared conventions, leaving the repo's own orchestrators (like `priis-fullstack-review`) intact for team use.

## Consequences

- Architecture audits and refactoring skills (`improve-codebase-architecture`) must recognize the ownership seam and never propose deleting or absorbing Team Skills into Personal Skills.
- `priis-fullstack-review`, `priis-backend-review`, and `priis-frontend-review` remain permanent team skills in `GR.PRIIS/.claude/skills/`.
- `priis-backend-modern-csharp` remains in the product repo as the team's self-contained standard, while `priis-profile` in the Personal Registry notes this overlap to avoid redundant guidance in personal sessions.
- Enhancements to team workflows (such as a unified `priis-verify` path-detecting dispatcher) must be made directly within the team repository's `.claude/skills/` as team assets, preserving backward compatibility with existing specialized entry points (`priis-backend-verify`, `priis-frontend-verify`).
