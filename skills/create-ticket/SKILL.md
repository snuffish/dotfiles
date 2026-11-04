---
name: create-ticket
description: "Drafts and files tracker work items (Azure DevOps user stories, tasks, bugs, or GitHub issues) derived from review findings, plans, or PR discussions. Mirrors target tracker field conventions, checks for duplicates, formats acceptance criteria, and records the created ID into the source artifact."
argument-hint: "[draft] [<source>]"
---

# Skill: `/create-ticket` — File a Tracker Ticket from Agreed Context

Turns an agreed follow-up, decision, or defect into one well-formed ticket in the team's tracker, matching the project's conventions, checking for duplicates, and recording the new ID back in the source artifact.

---

## Invariants

1. **Outward write discipline**: follow `outward-writes` (*Explicit request & draft mode*, *Denied write is final*, *Auth error vs denial*, *Read back*). `/create-ticket draft` (or a standing draft-only rule) stops at the *Draft preview*.
2. **File only what the source says**: restructure and translate into the tracker's language without adding unverified claims or estimates.
3. **No side effects beyond the one ticket**: never assign, set a sprint, change state, set priority, or link to a PR/commit unless explicitly asked. Set a parent link only when the request/source names the parent or the type (`Task`) requires one.
4. **Do not modify the working tree**: write payload files to `<scratchpad>/ticket-<slug>/` and update at most the one ID record line in the source artifact (*Step 8*).

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact — updates at most one record line in the source artifact (rule 3)
- `../_modules/pr-host.md`
- `../_modules/outward-writes.md`

---

## 1. When to Use

| Situation | Use instead |
|---|---|
| Commenting on an existing PR or thread | [`/pr-post-comments`](../pr-post-comments/SKILL.md) |
| Writing or refreshing a PR description | [`/pr-summary`](../pr-summary/SKILL.md) |
| The follow-up still needs research before filing | [`/investigate`](../investigate/SKILL.md) |
| Implementing the ticket | [`/implement-feature`](../implement-feature/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1 — Resolve the source and the scope

1. **Source**: in order — user selection/reference (`@file#L185-225`), named artifact section, quoted PR thread/decision, or latest conversation context. Read the enclosing section for context.
2. **One ticket per request**: if the source holds multiple independent follow-ups, ask once which to file.
3. **Extract without inventing**: *why* (problem + decision origin PR `!id` / thread `#id` / date), *what* (proposed solution/sketch), *prerequisites*, *open questions / spike*, *risks*, and testable *acceptance criteria*.

### Step 2 — Resolve the tracker & tool

- Resolve the tracker (`<org-url>` and `<project>` on Azure DevOps; `<owner>/<name>` on GitHub) and choose the MCP vs. CLI route per `pr-host` › *Organization URL* and *Tool: MCP vs CLI*.
- When using the `azure-devops` MCP server, follow [azure-devops-mcp.md](references/azure-devops-mcp.md) for Steps 3, 4, and 7.
- Apply any project profile or workflow skill rules (e.g. `implement-feature-<project>-profile` language/type conventions) ahead of inferred defaults.

### Step 3 — Copy the tracker's conventions

Inspect the last ~25 items and 1–2 close relatives before drafting:

```bash
# Azure DevOps
az boards query --org <org-url> --project <project> --wiql "
  SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AreaPath],[System.IterationPath],[System.Tags]
  FROM WorkItems WHERE [System.TeamProject]='<project>' AND [System.ChangedDate] >= @Today-60
  ORDER BY [System.ChangedDate] DESC" \
  --query '[].{id:id,t:fields."System.WorkItemType",title:fields."System.Title",s:fields."System.State",a:fields."System.AreaPath",i:fields."System.IterationPath",tags:fields."System.Tags"}' -o table
az boards work-item show --org <org-url> --id <id> --expand relations -o json

# GitHub
gh issue list --repo <owner>/<name> --state all --limit 25 --json number,title,labels,state
gh label list --repo <owner>/<name>
```

Derive from recent relatives: **Type** (*User Story*, *Bug*, or *Task* under a parent story), **Title** pattern and language, **Area**, **Iteration** (always the backlog root/node, never the active sprint unless asked), **Tags/labels** (existing project tags only), **Description format**, and **Parent** (ask when a Task has no named parent). Name the mirrored relative in the preview (`Placed like #31103`).

### Step 4 — Search for duplicates

```bash
az boards query --org <org-url> --project <project> --wiql "
  SELECT [System.Id],[System.Title],[System.State] FROM WorkItems
  WHERE [System.TeamProject]='<project>' AND [System.State] NOT IN ('Closed','Removed','Done')
    AND ([System.Title] CONTAINS '<key term 1>' OR [System.Title] CONTAINS '<key term 2>')" -o table
gh issue list --repo <owner>/<name> --state open --search "<key terms>"
```

If an open item already covers the work, stop and show it.

### Step 5 — Write the content

- **Language**: match the tracker's language (*Step 3*), keeping code, paths, commands, and identifiers verbatim.
- **Format**:
  - **Azure DevOps (HTML)**: `description.html` (`System.Description`) and `acceptance.html` (`Microsoft.VSTS.Common.AcceptanceCriteria`); for a **Bug**, write `repro.html` (`Microsoft.VSTS.TCM.ReproSteps`) instead of `description_file` (`scripts/create_ticket.py` rejects `description_file` on Bugs). Use `<h3>`, `<p>`, `<ul><li>`, `<code>`, and `<pre>` (escaping `<`, `>`, `&` inside `<pre>`).
  - **GitHub (Markdown)**: `body.md` with description sections followed by `## Acceptance criteria` (`- [ ]` checkboxes).
- **Default sections** (include only those with content): **Background**, **Proposal**, **Prerequisites**, **Spike first / open questions**, **Risks**.
- **References**: tracker IDs (`!18722`, `#110956`) and remote URLs only — never local paths, scratchpad paths, or internal finding numbers.

### Step 6 — Spec, dry run, preview

1. Write the content files and `spec.json` in `<scratchpad>/ticket-<slug>/` (see [`scripts/create_ticket.py`](scripts/create_ticket.py) docstring).
2. Run the dry-run validator: `python3 -I <skill-dir>/scripts/create_ticket.py <scratchpad>/ticket-<slug>/spec.json`.
3. In draft mode (or under a standing draft-only rule), stop here and print the *Draft preview*.

### Step 7 — Create, verify, or hand over

1. **Create**: run `python3 -I <skill-dir>/scripts/create_ticket.py <scratchpad>/ticket-<slug>/spec.json --create` (or the MCP route in [azure-devops-mcp.md](references/azure-devops-mcp.md)).
2. **Verify (`outward-writes` › *Read back*)**: read back the created item (`az boards work-item show --org <org-url> --id <id> --expand relations` / `gh issue view <n>`) to confirm type, title, state, area, iteration, tags, non-empty description/AC/repro, and parent relation.
3. **If denied or blocked**: follow `outward-writes` › *Denied write is final* and *Auth error vs denial*, hand over `python3 -I /<skill-dir>/scripts/create_ticket.py /<scratchpad>/ticket-<slug>/spec.json --create`, and ask for the created ID.

### Step 8 — Record the id

When the source is a artifact in the artifact dir, update the single checklist/follow-up line with the created ID, URL, and date (`- [x] Follow-up story created: #31201 (2026-10-19)`, or `drafted, not yet created`), and re-emit the `artifact-protocol` › *Chat link block* if line numbers shifted.

---

## 3. Output Format & Deliverables

### Draft preview
````markdown
**Draft — nothing created yet.** Reply "create" to file it, or tell me what to change.

**<Type>** · **<Title>**
Area `<area>` · Iteration `<iteration>` · Tags <tags or none> · Parent <#id or none>
Placed like #<relative> (<why>). Duplicate search: <no open match | #id "<title>" (state)>.

**Description / Repro Steps**
<rendered content>

**Acceptance criteria**
- …

Content files: `/<scratchpad>/ticket-<slug>/`
````

### After creating
One line with the created ID and URL, verified placement (type, area, iteration, parent), fields left unset (assignee, sprint, priority), and the updated source artifact line.

---

## 4. Verification & Validation

- Conventions mirrored a named recent relative, and duplicate search ran with distinctive terms.
- No local/scratchpad paths or internal labels appear in the ticket; no priority, sprint, or assignee was set unasked.
- Created item was read back and verified, and the source artifact line records the ID.
