# Azure DevOps MCP Route for `/create-ticket`

On-demand reference for [SKILL.md](../SKILL.md). Use the `azure-devops` MCP server when the project Profile's **Tracker** prefers it or when an `az` CLI call fails with an authentication error (`pr-host` › *Tool: MCP vs CLI*).

---

- **Step 3 (Read recent items & conventions)**:
  1. Call `wit_query` `action: "wiql"` with the WIQL query (`project`, `top: 25`). It returns work-item IDs only.
  2. Read the columns with `wit_work_item` `action: "get_batch"` (`ids`, `fields: ["System.Id", "System.WorkItemType", "System.Title", "System.State", "System.AreaPath", "System.IterationPath", "System.Tags"]`).
  3. Read 1–2 close relatives with `wit_work_item` `action: "get"` (`expand: "Relations"` and `fields` are mutually exclusive — make one call for fields and one with `expand: "Relations"` for the parent link).
- **Step 4 (Duplicate search)**: run the duplicate WIQL through `wit_query` `action: "wiql"`, then `get_batch` for titles and states.
- **Step 7.1 (Create)**: after the dry run (`scripts/create_ticket.py <spec.json>`) validates the spec, call `wit_work_item_write` `action: "create"` with `project`, `workItemType` = spec's `type`, and `fields` from the validated spec (`System.Title`, `System.AreaPath`, `System.IterationPath`, `System.Tags` joined with `; `, any extra `fields`, and the HTML content files as `System.Description`, `Microsoft.VSTS.Common.AcceptanceCriteria`, or `Microsoft.VSTS.TCM.ReproSteps` with `format: "Html"`). When the spec has `parent`, link it via `wit_work_item_link_write` `action: "link"`, `updates: [{id: <new id>, linkToId: <parent>, type: "parent"}]`.
- **Step 7.2 (Verify read-back)**: call `wit_work_item` `action: "get"` once with `fields` and once with `expand: "Relations"` to confirm `System.LinkTypes.Hierarchy-Reverse`.
