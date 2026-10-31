# project-profile

How a Command finds, layers, and applies a project's Profiles: discovery, resolution order, shared fields, overrides, upstream team content, and pointers ([ADR-0003](../../docs/adr/0003-profile-resolution-is-a-module.md)). Depends on no other Module.

---

## Discovery

A project's facts live in two layers under `Projects/<Project>/`, both gated `[Project: …]` in their `description`:

| Layer | Name | Holds |
|---|---|---|
| **Base profile** | `<project>-profile` (e.g. `priis-profile`) | The *Shared fields* below, plus any project fact more than one Command needs |
| **Command profile** | `<command>-<project>-profile` (e.g. `code-review-priis-profile`) | Only the fields of that Command's own field table, plus its *Precedence overrides* |

When the workspace matches a profile's gate, load the base profile first, then the Command profile. Optional Command-specific fields (e.g. `Plan-review checks` for `/plan --review`) may live directly in the base profile when a separate Command profile is unnecessary.

## Resolution order

Resolve every needed field once at the start of the run, stopping at the first source that answers it:

1. **Command profile**: authoritative, pre-verified answer for that Command.
2. **Base profile**: the project's shared facts.
3. **Workspace rulebooks**: `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` at the workspace root and in each repo, `.agents/rules/`, any canonical rulebook they point to, and `CONTRIBUTING.md`.
4. **Project-scoped skills**: repo team skills (`.claude/skills/`) and registry skills gated `[Project: …]`.
5. **The repo itself**: `git remote get-url origin`, CI YAML, `package.json` / `*.csproj` / `Makefile`, and PR templates under `docs/` or `.github/`.

When a field has no source and no safe fallback, surface it as an *Open Question*, never a guess.

## Shared fields

Every base profile answers these. A Command profile never restates them; it points to them by name (`<project>-profile` › *Profile fields* › <Field>).

| Field | What to resolve | Fallback when nothing documents it |
|-------|-----------------|-----------------------------------|
| **Layout** | Single repo, or a workspace root holding several repos; which repo/folder is the API/producer and which the client/consumer | `find <root> -maxdepth 2 -name .git` |
| **Tracker** | Azure DevOps Boards, GitHub Issues, GitLab, Jira, or none; org/project URL; CLI or MCP server and whether it reads comments/relations | Detect from remote host; if none, the user's prompt is the spec |
| **PR tooling** | Which MCP server or CLI reads and writes PRs, threads, and labels (`azure-devops` MCP, `az repos`, `gh`, `glab`), and any per-operation override | Same host tool as **Tracker** |
| **References per layer** *(Pattern skills per layer)* | Which Reference skills to load for endpoints, data access, UI, forms, data fetching, routing, tests, background jobs, realtime | The repo's rulebook sections on those topics |
| **Sibling chain** | Ordered list of layers a feature passes through in each repo | Derive from one recent feature commit (`git log --stat`) |
| **Contract touchpoints** | Shared surfaces across repos or consumers: generated API clients/snapshots, shared enums/permissions, hub/event names, locale rules | Workspace rulebook "contracts" section; else none known |
| **Known drift** | Documented places where docs or scaffolds lag the code | None known: trust the code |
| **Report language** | Language of written output (artifacts, PR text, posted comments) and which domain terms stay verbatim | Language of recent PR descriptions |
| **Worktree include list** | Gitignored local files a fresh worktree needs (`appsettings.local.json`, `.env.local`) | None |
| **Dependency hydration** | Install command per repo for a fresh worktree, and whether dependency symlinking is allowed | Derive from lockfiles; symlinking off |
| **Shared local services** | Ports, local APIs, and databases shared across worktrees | None known |
| **Implementation mode** | Where code-editing Commands (`/proceed` included) make edits: `workspace` or `in place` | `git-worktrees` › *Modes* defaults |
| **PR labels** | Required PR labels, selection rule, and how to read/add them | None |

## Restating

Repeat the resolved fields you rely on in the Command's output (scope statement, Review Context row, or plan *Context & Goal*) and name the loaded profiles.

## Overrides

A profile may add project facts and override **conventions** (which skill wins for a layer, naming rules, trailer policy, report sections). It never relaxes a Command's **gates or invariants** (read-only rules, approval gates, snapshot isolation). Conflicts where the Command's steps win are listed under *Precedence overrides*.

## Upstream content

Read team-owned checklists, `_shared/*.md` conventions, and rulebooks from the product repo's default branch, never from a stale copy or the reviewed head:

```bash
git -C <repo> fetch origin <default>                 # skip when already fetched in this run
git -C <repo> show origin/<default>:<path>           # read-only; independent of checkout
git -C <repo> rev-parse --short origin/<default>     # record this sha
```

- Record `<repo> origin/<default> @ <short-sha>` in the Command's sources.
- Fall back to a registry copy only if the path is absent on `origin/<default>`, and say so.
- If the change under review modifies that upstream file itself, evaluate against `origin/<default>` and treat the edit as part of the change.

## Pointers

A profile that delegates to a section of another skill names the **exact heading text** (`### Pass A — Reuse and duplication (highest yield)`), what applies, and what does not. If a listed heading is missing at read time, report it in the Command's sources and continue without it — never silently.
