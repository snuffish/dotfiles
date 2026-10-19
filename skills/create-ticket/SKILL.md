---
name: create-ticket
description: Drafts and files a tracker ticket (an Azure DevOps user story, task, bug or feature, or a GitHub issue) from what is already on the table, such as a section of a review or plan artifact, a selected block, a decision in a PR thread, or a pasted note. Reads the tracker's own recent items to copy its conventions (type, title language and style, area, backlog or sprint, tags, parent), searches for duplicates, writes the description and acceptance criteria in the tracker's format, dry-runs the exact create command, and files only on an explicit request. When the write is blocked, it hands over a ready-to-run command. It records the new id back into the source artifact. `/create-ticket draft` stops at the preview. Trigger on /create-ticket, "create a ticket / story / task / bug / issue for this", "file a work item", "make an ADO ticket", "open a GitHub issue for this", "turn this follow-up into a story".
---

# Skill: `/create-ticket` — File a Tracker Ticket from Agreed Context

Turns a follow-up, decision or defect that is already written down into one well-formed ticket in the team's tracker, placed and worded the way the team's own tickets are, without duplicates, and with the new id recorded where the follow-up came from.

---

## ⛔ Mandatory Invariants

> [!CAUTION]
> 1. **CREATE ONLY ON AN EXPLICIT REQUEST IN THE CURRENT MESSAGE.** "Create a ticket for this", "file it" or `/create-ticket` is that request. `/create-ticket draft` is not, and neither is a standing instruction (memory, `CLAUDE.md`) that says tickets are drafted for the user to file. In those cases stop at the *Draft preview*. Approval of one draft does not carry over to another.
> 2. **FILE ONLY WHAT THE SOURCE SAYS.** Restructure for the tracker, translate into the tracker's language, and add nothing of substance. No new requirements, estimates or claims. When a draft was shown, file it byte for byte, or show the changed version again.
> 3. **NO SIDE EFFECTS BEYOND THE ONE TICKET.** Never assign, set a sprint, change state, set priority, link to a PR or commit, or comment on other items unless that exact action is asked for. A parent link is set only when the request or the source names the parent. Linking a ticket to a PR changes the PR.
> 4. **A DENIED WRITE IS FINAL FOR THIS TURN.** If the permission system blocks the create, do not route around it (another CLI, a raw REST call, a script run through a test runner). Leave the spec and content files in place, hand over the exact command (*Step 7*), and ask for the new id.
> 5. **DO NOT MODIFY CODE OR THE WORKING TREE.** The only local writes are the files in the scratchpad and the one line in the source artifact that records the id.

---

## Modules

Read these before step 1:
- `~/.terminal/skills/_modules/core.md`
- `~/.terminal/skills/_modules/artifact-protocol.md`: writes no artifact — updates at most one line in the source artifact

- **No artifact of its own.** It consumes an existing source (an artifact section, a selection, a thread, the conversation) and updates at most one line in the source artifact (*Step 8*).
- **Content files** (`spec.json`, `description.html`, `acceptance.html`, `repro.html` or `body.md`) live in the host's scratchpad, `<scratchpad>/ticket-<slug>/`, never in the repo or at the workspace root.

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/create-ticket [draft] [what]`.
- The user asks to "create a ticket / story / task / bug / issue for this", "file a work item", "make an ADO ticket", or "open a GitHub issue".
- A review, plan or feedback artifact has a follow-up item ("Follow-up story: …", "Path B, as a follow-up") and the user asks for it to be tracked.

| Situation | Use instead |
|---|---|
| Commenting on an existing PR or thread | [`/pr-post-comments`](../pr-post-comments/SKILL.md) |
| Writing or refreshing a PR description | [`pr-summary`](../pr-summary/SKILL.md) |
| The follow-up still needs research before anyone can write it down | [`/investigate`](../investigate/SKILL.md) first |
| Implementing the ticket | [`/implement-feature`](../implement-feature/SKILL.md) |

---

## 2. Core Protocol & Workflow

### Step 1 — Resolve the source and the scope

1. **Source.** In this order: the lines the user selected or referenced (`@file#L185-225`, an IDE selection), the artifact section the request names, the PR thread or decision quoted, and the latest relevant part of the conversation. Read the whole section, not only the selected lines: the scope often sits in the paragraph above (a "Decision:" line, the threads it depends on).
2. **One ticket per request.** If the source holds several independent follow-ups, ask once which ones, and whether they become separate tickets or one story with tasks.
3. **Extract**, without inventing:
   - **why:** the problem, or the decision that created the follow-up, and where it was taken (PR !id, thread #id, date);
   - **what:** the proposed solution, sketch or options;
   - **prerequisites:** what must land first, such as blocking threads or other tickets;
   - **open questions or spike:** what is unverified;
   - **risks:** security, cost and the like, when the source names them;
   - **acceptance criteria:** the source's own "done when" points; otherwise derive testable bullets from the *what*, one per observable outcome.

### Step 2 — Resolve the tracker

- **Azure DevOps:** the repo's `origin` (`dev.azure.com/<org>/<project>/_git/<repo>`, or the legacy `<org>.visualstudio.com`), or the tracker the workspace rulebook names. Always pass `--org https://dev.azure.com/<org>`. The legacy host fails authentication even when `az` is signed in.
- **GitHub:** `gh repo view --json nameWithOwner`, or the repo the request names.
- In a multi-repo workspace the ticket goes to the project that owns the work. A ticket spanning repos is one ticket in the shared project, not one per repo, unless the team files per repo (*Step 3* shows which).
- A project profile or workflow skill (for example `implement-feature-<project>-profile`, `<project>-workflow`) can state ticket rules, such as implementing-ID rules or "tasks are English, stories Swedish". Those rules win over what *Step 3* infers.

### Step 3 — Copy the tracker's conventions

Read before writing. Tickets that look like the team's own get triaged; foreign-looking ones get rewritten or ignored.

```bash
# Azure DevOps: the last ~25 items touched in the project
az boards query --org https://dev.azure.com/<org> --project <project> --wiql "
  SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AreaPath],[System.IterationPath],[System.Tags]
  FROM WorkItems WHERE [System.TeamProject]='<project>' AND [System.ChangedDate] >= @Today-60
  ORDER BY [System.ChangedDate] DESC" \
  --query '[].{id:id,t:fields."System.WorkItemType",title:fields."System.Title",s:fields."System.State",a:fields."System.AreaPath",i:fields."System.IterationPath",tags:fields."System.Tags"}' -o table
# Then one or two close relatives in full (description and acceptance-criteria format, parent):
az boards work-item show --org … --id <id> --expand relations -o json

# GitHub
gh issue list --repo <owner>/<name> --state all --limit 25 --json number,title,labels,state
gh label list --repo <owner>/<name>
```

Derive:

| Decide | From |
|---|---|
| **Type** | New capability, or follow-up work a team picks up → the type the project uses for that (often *User Story*). Defect → *Bug*. An implementation slice of an existing story → *Task* under that story, which needs a parent. Epics and features only when asked |
| **Title** | The language and pattern of recent items of that type: Swedish or English, persona phrasing ("Ludvig som Faisal …"), side prefixes on tasks ("Backend: …"), tags like `[SEC]` |
| **Area** | The area most recent items use, unless the work clearly belongs to another one |
| **Iteration** | Unscheduled follow-ups go where the project keeps its backlog: the iteration *root or backlog node* recent `New` items sit in, never the current sprint. A sprint is set only when asked |
| **Tags or labels** | Only tags the project already uses, matching the work (`Backend`/`Frontend` on tasks, security tags on security items). None is a valid answer |
| **Description format** | A close relative's section headings and language. When relatives have none (empty descriptions are common), use the default sections in *Step 5* |
| **Parent** | Only when the request or source names it, or the type requires one (a task). In the second case ask which, never guess |

Name the close relative you mirrored in the preview, for example "placed like #31103, a tooling story in the backlog".

### Step 4 — Search for duplicates

```bash
az boards query --org … --project <project> --wiql "
  SELECT [System.Id],[System.Title],[System.State] FROM WorkItems
  WHERE [System.TeamProject]='<project>' AND [System.State] NOT IN ('Closed','Removed','Done')
    AND ([System.Title] CONTAINS '<key term 1>' OR [System.Title] CONTAINS '<key term 2>')" -o table
gh issue list --repo <owner>/<name> --state open --search "<key terms>"
```

Use two or three distinctive terms from the title, not generic words. If an open item covers the same work, stop and show it. The user chooses between "create anyway" and "add to #id instead", and the second is out of this skill's scope unless asked.

### Step 5 — Write the content

- **Language:** the tracker's (*Step 3*), even when the source artifact is in another language. Keep code, paths, commands and identifiers verbatim.
- **Azure DevOps fields are HTML:** `System.Description` and `Microsoft.VSTS.Common.AcceptanceCriteria`; for a *Bug*, `Microsoft.VSTS.TCM.ReproSteps` (numbered steps, expected vs actual) instead of the description. Use `<h3>`, `<p>`, `<ul><li>`, `<code>`, and `<pre>` for code blocks. Escape `<`, `>` and `&` inside `<pre>`. **GitHub** issues are Markdown in one body: description sections, then `## Acceptance criteria` as a task list (`- [ ]`).
- **Default sections** (translated to the tracker's language), each only when the source has content for it:
  1. **Background:** why, and the decision with its place and date (PR !id, thread #id).
  2. **Proposal:** the solution or sketch; keep a source code sketch as a code block.
  3. **Prerequisites:** what must land first, by tracker id.
  4. **Spike first / open questions:** what is unverified.
  5. **Risks:** security, cost or rollout, when named.
- **Acceptance criteria:** testable, one observable outcome per bullet, no implementation steps disguised as criteria. Five to ten bullets is typical.
- **References:** tracker ids (`!18722`, `#110956`, `#31103`) and full tracker URLs only. Never local paths, scratchpad paths, links to local artifacts, or the agent's internal labels (finding numbers, "Path B").

### Step 6 — Spec, dry run, preview

1. Copy [`templates/create_ticket.py`](templates/create_ticket.py) into `<scratchpad>/ticket-<slug>/`. Write the content files and `spec.json` beside it (format in the script's docstring).
2. Run `python3 -I create_ticket.py spec.json`. It validates the spec, prints every field it will set, and runs nothing.
3. **Draft mode, or a standing draft-only instruction:** stop here and give the *Draft preview*.

### Step 7 — Create, verify, or hand over

1. **Create:** `python3 -I create_ticket.py spec.json --create`. It creates the item, adds the parent link when the spec has one, and prints the id and URL.
2. **Verify** by reading it back: type, title, state, area, iteration, tags, that the description and acceptance criteria are non-empty, and the parent relation.
   ```bash
   az boards work-item show --org … --id <id> --expand relations \
     --query '{t:fields."System.WorkItemType",title:fields."System.Title",s:fields."System.State",a:fields."System.AreaPath",i:fields."System.IterationPath",tags:fields."System.Tags",d:length(fields."System.Description"),ac:length(fields."Microsoft.VSTS.Common.AcceptanceCriteria"),parent:relations[?rel==`System.LinkTypes.Hierarchy-Reverse`].url}'
   gh issue view <n> --repo <owner>/<name> --json number,title,labels,url
   ```
3. **Denied** (the auto-mode classifier or a permission rule blocks the external write): say plainly that nothing was created and hand over the command with absolute paths:
   ```bash
   python3 -I /<scratchpad>/ticket-<slug>/create_ticket.py /<scratchpad>/ticket-<slug>/spec.json --create
   ```
   Mention that a permission rule for `az boards work-item create` / `gh issue create` lets the agent file next time, and ask the user to paste the printed id.

### Step 8 — Record the id

When the source is a workspace-root artifact, update the one line the ticket came from (the checklist item or the "follow-up story" sentence) with the id, the URL and the date, for example `- [x] Follow-up story created: #31201 (2026-10-19)`. When the ticket was only drafted or the write was denied, mark the line "drafted, not yet created". Never write scratchpad paths into the artifact. If artifact links were emitted earlier in the conversation and lines shifted, emit them again.

---

## 3. Output Format & Deliverables

Chat response, nothing else.

### Draft preview (draft mode, standing draft-only rule, or before a denied create)

````markdown
**Draft — nothing created yet.** Reply "create" to file it, or tell me what to change.

**<Type>** · **<Title>**
Area `<area>` · Iteration `<iteration>` · Tags <tags or none> · Parent <#id or none>
Placed like #<relative> (<why that one>). Duplicate search: <no open match | #id "<title>" (state)>.

**Description**
<readable rendering of the description: headings, bullets, code blocks>

**Acceptance criteria**
- …

Content files: `/<scratchpad>/ticket-<slug>/` (`description.html`, `acceptance.html`, `spec.json`)
````

### After creating

One line with the id and URL, the verified placement (type, area, iteration, parent), what was deliberately left unset (assignee, sprint, priority), and the artifact line that now records the id. After a denied create: the hand-over command from *Step 7*, plus the preview so the user knows what it will file.

---

## 4. Verification & Validation

- The conventions came from the tracker's own recent items, and the preview names the relative that was mirrored.
- The duplicate search ran with distinctive terms, and its result is in the preview.
- Every claim in the ticket traces to the source. Nothing was added, and code or identifiers are verbatim.
- No local or scratchpad path, artifact link or internal label appears in the ticket.
- Created: the read-back matches the spec (type, title, area, iteration, tags, parent), and the description and acceptance criteria are non-empty.
- No assignee, sprint, state, priority or PR link was set unless asked.
- Draft mode: no `--create` run and no tracker write in that turn.
- The source artifact's line records the id, or "drafted, not yet created".
