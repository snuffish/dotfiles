# skills-claims.json: claim schema

`skills/skills-claims.json` inside `<registry>` is `{"version": 1, "root": "..", "claims": [ ... ]}`. All `source.file` paths are relative to the `~/.terminal` repo root (above `skills/`). [`scripts/check_skill_drift.py`](../scripts/check_skill_drift.py) reads it.

The file is written with `json.dumps(data, indent=2) + "\n"` (ASCII-escaped, trailing newline); the checker fails with a `format` row when it is not.

## What counts as a claim

Anything the text says exists or has a specific value that could become false when the registry, dotfiles, or a target project repo changes:

| Kind | Examples |
|---|---|
| `path` | `skills/_modules/core.md`, `claude/statusline.sh`, `backend/source/GR.PRIIS.Library/Feature/`, or a glob that must match something |
| `doc_link` | `[ADR-0002](../../../docs/adr/0002-module-paths-relative-to-real-skill-folder.md)` or `` `core` › *The `/proceed` gate* `` |
| `symbol` | Types, methods, functions, constants, enum members, hooks, and test IDs the text says exist (`ExtendedEndpoint`, `publish_new_artifact`, `EnumMetadataCache.GetDisplayName`, `ApiWebFactory.CreateClientAsNoAccessUserAsync`) |
| `port`, `url` | `5033`, `http://127.0.0.1:5033` (check the port in config/skills; external URLs are `manual`) |
| `config_key`, `env_var` | `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_MEM_DISABLE_FILE_CONTEXT`, `InactivitySuggestionReminderMinDays` |
| `npm_script`, `cli_command` | `npm run organize-imports`, `python3 -I <registry>/sync-skills/sync_skills.py`; one claim per checkable dependency (executable, npm script, script file, flag) |
| `package` | npm or NuGet packages and versions |
| `mcp_tool` | `mcp__azure-devops__repo_pull_request`, `mcp__codegraph__codegraph_search` |
| `skill_ref` | Another skill by name (`code-review`, `priis-backend-testing`, `priis-ship`) |
| `count` | "44 skills total — 39 general + 5 under `Projects/GR.PRIIS/` — plus 8 Modules" |
| `other` | Any other checkable statement about the codebase or configuration |

Skip placeholders (`<id>`, `<prefix>`, `{Domain}`), code a sample invents (`Foo`, `CreateFooRequest`), style advice, and third-party library behaviour that isn't about this codebase. One claim per `(kind, value)` per source file; list repeats in `also_lines`.

## Claim object

```json
{
  "id": "<file>:<line>:<kind>:<value>",
  "source": {"file": "skills/Projects/GR.PRIIS/priis-backend-dry/SKILL.md", "line": 22, "also_lines": [44]},
  "kind": "path",
  "value": "backend/source/GR.PRIIS.API/Features/Reports/Register/ExportRegisterEndpoint.cs",
  "quote": "follow the AddChangedByIds + temporal fallback exemplar (ExportRegisterEndpoint.cs:413)",
  "context": " ChangedBy temporal fallback exemplar",
  "verify": {
    "method": "path_exists",
    "path": "backend/source/GR.PRIIS.API/Features/Reports/Register/ExportRegisterEndpoint.cs",
    "base": "project:GR.PRIIS",
    "type": "file"
  }
}
```

`id` must be unique (cut at 200 characters). The checker finds the line again by `quote`, so the quote must be copied verbatim from the line; whitespace differences are ignored.

## `base` roots

| `base` value | Resolves against | Missing workspace behaviour |
|---|---|---|
| `"repo"` (default) | `~/.terminal` repository root | n/a |
| `"file_dir"` | Directory of `source.file` inside `~/.terminal` | n/a |
| `"project:<Project>"` (e.g. `"project:GR.PRIIS"`) | Target git repository discovered from `skills/Projects/<Project>/.workspaces` (plus its parent workspace folder for workspace-root files like `CLAUDE.md`) | Marks the claim `SKIP` (never `FAIL`) when the workspace is not on this machine |

## `verify` methods

| Method | Fields | Passes when |
|---|---|---|
| `path_exists` | `path`, `base` (`repo`, `file_dir`, `project:<Project>`), optional `type` (`file`/`dir`) | git tracks that file, or a file under that dir |
| `glob_exists` | `glob`, `base`, optional `min` (default 1) | the glob matches at least `min` tracked files (`**`, `*`, `?`, `{a,b}`) |
| `link_resolves` | `href` as written, `base` (default `"file_dir"`) | the target exists and its `#anchor` matches a GitHub heading slug or `<a id="...">` |
| `heading_pointer` | `target` (Module/skill name or path), `heading`, optional `base` | `target` resolves to a markdown file and `heading` matches a section heading or bold anchor (`**…**`) in it (or its linked `references/*.md`) |
| `grep` | `pattern` (Python regex, compiled with `re.MULTILINE` only, no DOTALL: use `[\s\S]` or `(?:.*\n)` to span lines), `paths` (globs), `base`, `expect` (`present`/`absent`) | the regex is found (or not) in the matching files |
| `count` | `glob`, or `pattern` + `paths`; `base`, `expected`, optional `op` (`eq`/`gte`/`lte`) | the number of files or regex matches satisfies `op` |
| `npm_script` | `package_dir`, `script`, optional `base` | the script is in that `package.json` |
| `skill_exists` | `name`, optional `base` (`repo` or `project:<Project>`) | `skills/<name>/SKILL.md` (or `.claude/skills/<name>/SKILL.md` in `project:<Project>`) exists |
| `executable` | `name` | the binary is on `PATH` (`WARN` only) |
| `mcp_tool` | `server`, `tool` | with `--mcp`, the configured server lists the tool (`WARN` only) |
| `manual` | `reason` | never checked (`SKIP`) |

## Built-in auto-scan (`--no-auto` to skip)

In addition to `skills/skills-claims.json`, `check_skill_drift.py` automatically scans every markdown file in `skills/**/*.md`, `claude/AGENTS.md`, `GLOSSARY.md`, and `docs/adr/*.md`:
- Every relative `[label](href)` and `[label](href#anchor)` outside code fences is checked via `link_resolves`.
- Every `` `<target>` › *Heading* `` and `[label](href) › *Heading*` pointer outside code fences is checked via `heading_pointer`.
- Every covered `SKILL.md` and top-level `skills/_modules/*.md` file with zero claims in `skills/skills-claims.json` emits a `WARN` (`FAIL` under `--strict`).

## Good targets

- **Symbols in `~/.terminal`:** grep for the function, constant, or key in `skills/**/scripts/*.py`, `skills/sync-skills/sync_skills.py`, `claude/*.py`, `claude/*.sh`, or `claude/settings.json`.
- **Symbols in `GR.PRIIS` (`base: "project:GR.PRIIS"`):** grep for the definition (`class ExtendedEndpoint\b`, `GetDisplayName\b`, `AddChangedByIds\b`, `WriteTitle\b`) in `backend/**/*.cs` or `frontend/source/priis-web/src/**/*.ts*`.
- **Generated files:** grep the generator config or `.gitignore` entry; never the generated file itself.
