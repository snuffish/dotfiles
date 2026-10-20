---
name: artifacts
description: Discovers, inspects and targets workspace artifacts across hosts, models and sessions — lists recent plans, reviews, investigations and other root-level artifacts in one table, lets the user pick one, then summarizes it and offers the next step. Trigger on /artifacts, "show my recent plans", "which artifacts exist?", "target an artifact".
---

# Skill: `/artifacts` — Artifact Explorer

Enables the user to inspect, list, and target recent artifacts generated across current and recent sessions.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`
- `../_modules/artifact-protocol.md`: reads every artifact the protocol describes; writes none

---

## When to Use
- The user issues `/artifacts`.
- The user asks: *"Show my recent plans"*, *"Which artifacts exist?"*, or *"Target an artifact"*.

## Discovery Protocol

### Step 1: Scan Workspace-Root Artifacts
`/artifacts` is the one skill that reads **across** hosts, models, and suffixes to show the user everything:
```bash
ls -lt *.md
```
Parse filenames into:
- **Host**: `claude`, `antigravity`, or `(standalone)`
- **AI Model**: e.g. `gemini-3.8-flash`, `sonnet-3.7`, `gemini-2.5-pro`, `sonnet-3.5`
- **Base Type**: `implementation_plan`, `code_review`, `pr_feedback_review`, `investigation`, etc.
- **Suffix / Topic**: The trailing identifier (e.g. `category-demand-statistics`, `18176-verksamhetsobjekt`, `begar-prefix`)

### Step 2: Scan Legacy Conversation Artifacts (Antigravity Only)
1. Check active conversation: `<appDataDir>/brain/<current-conversation-id>/` (excluding hidden `.system_generated/` and `scratch/`).
2. Check past conversations from `<conversation_history>` (top 5–10) in `<appDataDir>/brain/<past-id>/`.

---

## Presenting & Selecting Artifacts

Present discovered artifacts in a structured table:

```markdown
# 📂 Recent Artifacts

| # | Artifact | Host · Model | Topic / Suffix | Summary / Goal | Link |
|---|---|---|---|---|---|
| 1 | `antigravity-gemini-3.8-flash-code_review-category-demand-statistics.md` | Antigravity · Gemini 3.8 Flash | `category-demand-statistics` | Category demand statistics code review | [view](file://<workspace-root>/antigravity-gemini-3.8-flash-code_review-category-demand-statistics.md) |
| 2 | `claude-sonnet-3.7-code_review-18176-verksamhetsobjekt.md` | Claude Code · Sonnet 3.7 | `18176-verksamhetsobjekt` | PR #18176 code review | [view](claude-sonnet-3.7-code_review-18176-verksamhetsobjekt.md) |
| 3 | `antigravity-gemini-3.8-flash-implementation_plan-begar-prefix.md` | Antigravity · Gemini 3.8 Flash | `begar-prefix` | Begär-prefix refactor plan | [view](file://<workspace-root>/antigravity-gemini-3.8-flash-implementation_plan-begar-prefix.md) |
| 4 | `claude-sonnet-3.7-walkthrough-29982-verksamhetsobjekt.md` | Claude Code · Sonnet 3.7 | `29982-verksamhetsobjekt` | Verification results | [view](claude-sonnet-3.7-walkthrough-29982-verksamhetsobjekt.md) |
```

### Interactive Targeting
- If multiple options exist, let the user pick one: under Antigravity with `ask_question`, under Claude Code with `AskUserQuestion`, otherwise with a numbered list.

---

## Actions on Targeted Artifact

Once an artifact is selected:
1. **Summarize**: Concise status, open questions, and proposed changes.
2. **Next Steps**:
   - **Review**: *"Run `/plan-review <suffix>` to conduct a strict read-only audit of this plan."*
   - **Proceed**: *"Type `/proceed` to begin implementing this plan."*
   - **Refine / Edit**: *"Tell me what modifications you'd like to make to the plan."*
   - **View Details**: Provide a clickable direct link to open the file in the IDE.
