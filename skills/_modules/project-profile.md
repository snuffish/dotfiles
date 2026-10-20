# project-profile

How a Command finds, layers and applies a project's Profiles: discovery and naming, resolution order, the shared fields every base profile answers, what an override may touch, how to read content a team owns upstream, and how pointers into other skills are kept honest. Depends on no other Module. See [ADR-0003](../../docs/adr/0003-profile-resolution-is-a-module.md).

---

## Discovery

A project's facts come in two layers, both project-scoped skills under `Projects/<Project>/` and gated `[Project: …]` in their description:

| Layer | Name | Holds |
|---|---|---|
| **Base profile** | `<project>-profile` (e.g. `priis-profile`) | The *Shared fields* below, plus any project fact more than one Command needs |
| **Command profile** | `<command>-<project>-profile` (e.g. `code-review-priis-profile`) | Only the fields of that Command's own field table, plus its *Precedence overrides* |

When the workspace matches a profile's gate, load the base profile first, then the Command profile. A Command profile that exists without a base profile is a registry defect: say so and continue with what it has.

## Resolution order

Each Command keeps a table of the fields it needs and a fallback for each. Resolve every field once, at the start of the run, and stop at the first source that answers it:

1. **Command profile**: the authoritative, pre-verified answer for that Command.
2. **Base profile**: the project's shared facts.
3. **Workspace rulebooks**: `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` at the workspace root and in each repo, `.agents/rules/`, and any canonical rulebook they point to (e.g. `.github/copilot-instructions.md`), plus `CONTRIBUTING.md`.
4. **Project-scoped skills**: anything in the skill listing gated `[Project: …]` for this workspace.
5. **The repo itself**: `git remote get-url origin` for the host and tracker, CI YAML and `package.json` / `*.csproj` / `Makefile` for the real commands, the PR template under `docs/` or `.github/`.

When a field has no source and no safe fallback, it becomes an *Open Question* in the Command's output, not a guess.

## Shared fields

Every base profile answers these. A Command profile never restates them; it points to them by name ("see the `<project>-profile` skill › *Profile fields* › Tracker").

| Field | What to resolve | Fallback when nothing documents it |
|-------|-----------------|-----------------------------------|
| **Layout** | Single repo, or a workspace root holding several repos (each with its own `.git`); which repo is the API/producer and which the client/consumer | `find <root> -maxdepth 2 -name .git` |
| **Tracker** | Azure DevOps Boards, GitHub Issues, GitLab, Jira, or none; org/project URL; the CLI or MCP server (`az boards`, `gh issue`, `glab issue`) and whether it can read the discussion thread | Detect from the remote host; if no tracker, the user's description is the spec |
| **Pattern skills per layer** | Which skills to load for an endpoint, data access, UI, forms, data fetching, routing, tests, background jobs, realtime | The repo's rulebook sections on those topics |
| **Sibling chain** | The ordered list of layers a feature passes through in each repo, so one existing feature can be traced end to end | Derive it from one recent feature's commit (`git log --stat`) |
| **Contract touchpoints** | Anything shared between repos or with external consumers: generated API clients and their snapshot, shared enums/permission tables, event or hub names, locale rules | Workspace-root rulebook "contracts" section; else none known |
| **Known drift** | Documented places where the docs or scaffolds lag the code | None known: trust the code |
| **Report language** | The language of written output (artifacts, PR text, posted comments) and which product text is quoted verbatim | The language of the PR descriptions in the repo |
| **Worktree include list** | Gitignored local files a fresh worktree needs (`appsettings.local.json`, `.env.local`, local secrets) | None |
| **Dependency hydration** | The install command per repo for a fresh worktree, and whether dependency symlinking is allowed | Derive from the lockfiles present; symlinking off |
| **Shared local services** | Ports, local APIs and databases that concurrent worktrees share | None known |

## Restating

The Command repeats the resolved fields it relies on in its own output (a scope statement, a Review Context row, a plan's *Context & Goal*), so the user can correct a wrong one before it matters. Name the profiles that were loaded.

## Overrides

A profile may add project facts and override **conventions**: which skill wins for a layer, a project naming rule, a trailer policy, a report format addition the Command allows. It never relaxes a Command's **gates or invariants** (read-only rules, approval gates, no-install rules, snapshot isolation). When a profile tells the Command to use another skill's procedure, the Command's own steps still win wherever the two disagree, and the profile lists those conflicts under *Precedence overrides*.

## Upstream content

Some content a profile relies on is owned by a team in a product repo (a review checklist, a lessons catalog, a rulebook) and may also exist as a registry copy. Read it from the product repo's default branch, never from a registry copy, the reviewed head or the main checkout:

```bash
git -C <repo> fetch origin <default>                 # skip when this run already fetched it
git -C <repo> show origin/<default>:<path>           # read-only; independent of what is checked out
git -C <repo> rev-parse --short origin/<default>     # record this sha
```

- Record `<repo> origin/<default> @ <short-sha>` wherever the Command lists its sources.
- When the path does not exist on `origin/<default>`, fall back to the registry copy and say so in the same place.
- When the change being worked on modifies that content itself, apply the `origin/<default>` version and treat the modification as part of the change, not as the rule.

## Pointers

A profile that delegates to a section of another skill names the **exact heading text** (`### Pass A — Reuse and duplication (highest yield)`), the parts of that section that apply, and the parts that do not. When a listed heading cannot be found at read time, say so where the Command lists its sources and continue without that section. Never continue silently.
