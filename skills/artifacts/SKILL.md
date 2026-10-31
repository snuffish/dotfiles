---
name: artifacts
description: "Discovers, lists, and targets workspace artifacts across hosts and sessions."
disable-model-invocation: true
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

## Discovery Protocol

### Step 1: Scan Workspace-Root Artifacts
`/artifacts` reads **across** hosts, models, and suffixes at the workspace root (`*.md`, plus `*-export-*.html` and `*-export-*.txt`):
```bash
ls -lt *.md *-export-*.html *-export-*.txt 2>/dev/null
```
1. Parse each filename into **Host** (`claude`, `antigravity`, or `(standalone)`), **AI Model**, **Base Type** (see `_modules/references/artifact-catalog.md`), and **Suffix / Topic**.
2. Group revisions (`<name>.md`, `<name>-2.md`, …) into families per `artifact-protocol` › _Claim_ › _Readers & family selection_, and order by the `created` timestamp in each file's `<!-- artifact-owner: … -->` marker (falling back to mtime when absent).

---

## Presenting & Selecting Artifacts

Present discovered artifact families in a structured table, formatting every `[view]` link for the **current host** per `artifact-protocol` › *Host-Specific Link Formats* (`file://<workspace-root>/<file>` in Antigravity, `<file>` in the Claude Code IDE extension, `antigravity-ide://file/<workspace-root>/<file>` in the Claude Code terminal CLI):

```markdown
# 📂 Recent Artifacts

| # | Artifact (latest revision) | Host · Model | Topic / Suffix | Summary / Goal | Link |
|---|---|---|---|---|---|
| 1 | `<prefix>-code_review-<suffix>.md` | <Host · Model> | `<suffix>` | <Summary> | [view](<host-link>) |
```

If multiple options exist, let the user pick one (`ask_question` in Antigravity, `AskUserQuestion` in Claude Code, or a numbered list).

---

## Actions on Targeted Artifact

Once an artifact is selected:
1. **Summarize**: concise status, open questions, and proposed changes or findings, plus its `artifact-protocol` › _Chat link block_.
2. **Next Steps**:
   - **Review**: *"Run `/plan --review <suffix>` to conduct a strict read-only audit of this plan."*
   - **Proceed**: *"Type `/proceed` to begin implementing this plan."*
   - **Refine / Edit**: *"Tell me what modifications you'd like to make"* (if the artifact belongs to another session, the user naming it authorizes updating it per `artifact-protocol` › *Ownership* rule 3; otherwise `/plan` writes a new revision via *Claim*).
