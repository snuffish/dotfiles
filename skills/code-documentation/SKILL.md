---
name: code-documentation
description: "Use this skill when the user requests to generate, create, or improve documentation for code, APIs, libraries, repositories, or software projects. Supports README generation, API reference documentation, inline code comments, and architecture documentation. Trigger on requests like \"document this code\", \"create a README\", \"generate API docs\", \"document architecture\", or when analyzing codebases for documentation purposes."
argument-hint: "[<target-path | scope>]"
---

# Code Documentation Skill

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact in the artifact dir (`artifact-protocol`) — documentation is written into the repository where the user asks (`README.md`, `docs/`, inline comments); confirm the destination before writing

On-demand references (`references/`):
- [`references/readme-template.md`](references/readme-template.md) — README layout (features, quick start, installation, usage, configuration, contributing)
- [`references/api-reference-template.md`](references/api-reference-template.md) — public interfaces, parameters, returns, exceptions, and examples
- [`references/architecture-template.md`](references/architecture-template.md) — system diagrams, component overviews, data flows, and design decisions
- [`references/inline-code-doc-patterns.md`](references/inline-code-doc-patterns.md) — language docstrings (JSDoc, XML doc comments, Python docstrings, Go doc comments)
- [`references/style-guide.md`](references/style-guide.md) — writing principles, formatting rules, and language-specific conventions

---

## Documentation Workflow

### Phase 1: Codebase Analysis

Establish a concrete structural inventory before generating documentation:
- **Phase 1 Exit Bound:** Record: (1) primary language & framework manifests, (2) all exported entry points/routes via grep/AST, (3) existing doc files.

#### Step 1.1: Project Discovery

| Field | How to Determine |
|-------|-----------------|
| **Language(s) & Framework** | Check file extensions and manifests (`package.json`, `pyproject.toml`, `*.csproj`, `go.mod`, `Cargo.toml`) |
| **Build & Package Manager** | Check `Makefile`, `vite.config.*`, `npm`/`pnpm`, `uv`/`poetry`, `dotnet`, `cargo`, `go` |
| **Project Structure & Entry Points** | Map directory tree, main files, CLI entry points, and exported modules |
| **Existing Docs** | Check existing `README.md`, `docs/`, ADRs, or inline documentation |

#### Step 1.2: Code Structure Analysis

Follow `core` › *Codebase investigation* › *Navigation* (`.codegraph/` lean commands where indexed, or `git ls-files` and `git grep` on exported/public surfaces).

#### Step 1.3: Identify Documentation Scope

| Project Size | Recommended Documentation |
|-------------|--------------------------|
| **Single file / script** | Inline comments + usage header |
| **Small library** | README with API reference |
| **Medium project** | README + API docs + examples |
| **Large project** | README + Architecture + API + Contributing |

### Phase 2: Documentation Generation

Generate the required documentation types using the templates in `references/` and [`references/style-guide.md`](references/style-guide.md):
- **README Documentation:** [`references/readme-template.md`](references/readme-template.md)
- **API Reference Documentation:** [`references/api-reference-template.md`](references/api-reference-template.md)
- **Architecture Documentation:** [`references/architecture-template.md`](references/architecture-template.md)
- **Inline Code Documentation:** [`references/inline-code-doc-patterns.md`](references/inline-code-doc-patterns.md); for C# XML doc comments (`/// <summary>`), follow [`modern-csharp`](../modern-csharp/SKILL.md) › *12. Comments and XML Documentation* (slim, present-tense responsibility, no history or cross-ref archaeology).

### Phase 3: Quality Assurance

1. **Completeness Check**: verify coverage of **What it is**, **Why it exists**, **How to install**, **How to use** (minimal working example), **API surface**, **Configuration**, **Error handling**, and **Contributing**.
2. **Quality & Cross-Reference Validation**: verify every mentioned file path, symbol, signature, version number, and link against the current code (for third-party version facts, check official docs per [`/verify-assumptions`](../verify-assumptions/SKILL.md)). Preserve existing doc structure unless asked for a rewrite, and match the language of the project's existing docs (defaulting to English).

## Output Handling

- Write documentation into the repository where it belongs (`README.md` at the root, `docs/` for architecture, comments next to the code).
- Link every created or changed file in chat using `artifact-protocol` › *Host-Specific Link Formats*, and offer to iterate on specific sections.
