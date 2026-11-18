# CLAUDE.local.md — Personal Configuration & Overrides

Detailed patterns and personal orchestrator skills live in the registered skills registry under `/Users/snuffish/.terminal/skills` (see `.agents/skills.json`).

- **Skill profiles:** When invoking `/implement-feature` or `/code-review`, also load `priis-profile` and then the matching `implement-feature-priis-profile` / `code-review-priis-profile`.
- **Repository skills precedence:** Team skills shipped in `.claude/skills/` are canonical for the monorepo; personal registry skills extend them.
- **Registry inventory:** `/Users/snuffish/.terminal/skills/README.md`.

## Every PR has a work item

Applies to every PR I create or draft from a session in this repo, however it was opened (`/commit`, `/pr-desc`, `priis-ship`, by hand). Check right after creating the PR and again when publishing it.

1. Check: `az repos pr work-item list --org <ado-org-url> --id <pr>`. A linked item → nothing to do.
2. None linked → ask me for the parent work item ID. Never guess it; that is the only question. If I answer that there is no work item (e.g. "no ado item, just /commit and /pr-desc"), skip steps 3–6 and do not ask again this session. `/pr-summary` is not a skill; it means `/pr-desc`.
   - **Skill-gap PRs** (a `skill-gaps.md` *Fix it* PR, `priis-skill-gap`, any `Chore:` fixing a skill): don't ask. The parent is the active sprint's skill-gaps User Story:
     ```bash
     az boards query --org <ado-org-url> --project PRIIS --wiql "SELECT [System.Id] FROM WorkItems WHERE [System.WorkItemType] = 'User Story' AND [System.Title] CONTAINS 'skill-gaps' AND [System.IterationPath] = @CurrentIteration('[PRIIS]\\PRIIS Team')" -o json
     ```
     Exactly one hit → use it (Sprint 51: 31551). None or several → ask.
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
## Environment facts (don't rediscover)

- Local test user Lena (`lena@priis.se`) has the CaseworkerGuided role, which lacks `SystemAction.ListOperations`, so `GET /operations` returns 403 for her (`backend/source/GR.PRIIS.Library/Common/Users/AccessRules/Roles/CaseworkerGuidedAccessRules.cs`). Say so immediately rather than retrying.
- The container registry `indra3acr` is in a different tenant than GR; GR tokens fail with `unknown tenantId`. Local AcrPull is not needed for normal work: note it once and move on, never block on it or repeat "still blocked".
- Before giving an `az` or shell command to copy, double-check the tenant IDs and that there are no trailing commas.
- When I ask for a specific model (Sonnet/Opus) for a subagent or lens, pin the full model ID (e.g. `claude-sonnet-5-5`) and verify it ran on that model: count every `model` value in the agent's output, since the first one is the parent's.
