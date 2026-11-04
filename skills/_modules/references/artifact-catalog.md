# Canonical Artifact Catalog

On-demand reference for [artifact-protocol.md](../artifact-protocol.md). Every artifact filename uses `<prefix>-<base_artifact_name>-<suffix>.md` at the workspace root unless noted.

| Base Filename Pattern | Written / Managed By | Primary Purpose |
|---|---|---|
| `implementation_plan-<suffix>.md` | `/plan`, `/problem`, `/refine`, `/implement-feature` | Technical design, phase breakdown, task checklist, gating approval |
| `code_review-<suffix>.md` | `/code-review` | Code quality audit, severity findings (Critical/Important/Minor), diffs |
| `squashed_code_review-<suffix>.md` | `/squash-code-review` | Two or more code reviews of one change squashed into one verified review, with a reconciliation table and folded-in PR threads |
| `pr_feedback_review-<suffix>.md` | `/pr-feedback-review` | PR comment triage matrix, technical resolutions, draft responses |
| `pr_polish-<suffix>.md` | `/pr-polish` | PR-finishing run: verified findings with status, applied/reverted fix batches with build and test results, PR description and thread-reply drafts |
| `investigation-<suffix>.md` | `/investigate` | Pre-plan research: current-state map, prior art, constraints, options, confidence ledger |
| `explanation-<suffix>.md` | `/explain` | Deep architectural and code intent breakdown |
| `suggestion-<suffix>.md` | `/suggestion deep` | Ranked approaches with trade-offs, a recommendation and next steps |
| `assumption_check-<suffix>.md` | `/verify-assumptions` | Claim-by-claim verification against primary sources, verdicts and the decisions they affect |
| `what_am_i_missing-<suffix>.md` | `/what-am-I-missing`, `/implement-feature` | Blind spots, failure modes, invariant audits |
| `spec_verification-<suffix>.md` | `/spec-verification` | Requirement-by-requirement traceability against the work item, PR or plan |
| `manual_test_plan-<suffix>.md` | `/manual-testing` | Runnable manual test plan: setup, logins, test data, risk-ordered scenarios, regression watchlist |
| `conflict_resolution-<suffix>.md` | `/resolve-conflicts` | Per-hunk resolution record when a merge or rebase crosses the threshold for a written record |
| `expressive-<suffix>.md` | `/expressive` | Readability sweep findings and proposed declarative rewrites |
| `standup_recap-<suffix>.md` | `/standup-recap --file` | Daily standup speaker notes (Yesterday / Today / Blockers); the suffix is the recapped day |
| `walkthrough-<suffix>.md` | `/implement-feature` | Verification results, screenshots, completed summary |
| `organize_plan-<suffix>.md` | `/organize` | Directory/module structure refactoring proposal |
| `clean_report-<suffix>.md` | `/clean` | Multi-file dead-code pruning & sanitation report |
| `skills_sync_report-<suffix>.md` | `/sync-skills` | Registry discovery & loader synchronization audit |
| `prompt-<suffix>.md` | `/create-prompt` | Paste-ready prompt variants when written to disk |
| `skill_gap-<suffix>.md` | Any Command, per `core` › *Skill gaps* | One registry skill fact that proved wrong, with evidence, the proposed edit and an open/fixed status; written to `~/.terminal/skill-gaps/`, not the workspace root |
| `export-<suffix>.<ext>` | `/export-file` | Standalone copy of conversation content (`.md`, `.html` or `.txt`); written to the current working directory unless the user names a location |

*(Older unprefixed, un-modeled, or unsuffixed files written before the full convention are still recognized during scans).*
