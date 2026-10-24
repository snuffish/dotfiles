---
name: code-documentation
description: Use this skill when the user requests to generate, create, or improve documentation for code, APIs, libraries, repositories, or software projects. Supports README generation, API reference documentation, inline code comments, architecture documentation, changelog generation, and developer guides. Trigger on requests like "document this code", "create a README", "generate API docs", "write developer guide", or when analyzing codebases for documentation purposes.
---

# Code Documentation Skill

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact at the workspace root — documentation is written into the repository where the user asks (README, `docs/`, inline comments)

- Confirm the destination before writing.

---

## Overview

This skill generates professional, comprehensive documentation for software projects, codebases, libraries, and APIs. It follows industry best practices from projects like React, Django, Stripe, and Kubernetes to produce documentation that is accurate, well-structured, and useful for both new contributors and experienced developers.

The output ranges from single-file READMEs to multi-document developer guides, always matched to the project's complexity and the user's needs.

## Core Capabilities

- Generate comprehensive README.md files with badges, installation, usage, and API reference
- Create API reference documentation from source code analysis
- Produce architecture and design documentation with diagrams
- Write developer onboarding and contribution guides
- Generate changelogs from commit history or release notes
- Create inline code documentation following language-specific conventions
- Support JSDoc, docstrings, GoDoc, Javadoc, and Rustdoc formats
- Adapt documentation style to the project's language and ecosystem

## Documentation Workflow

### Phase 1: Codebase Analysis

Before writing any documentation, thoroughly understand the codebase.

#### Step 1.1: Project Discovery

Identify the project fundamentals:

| Field | How to Determine |
|-------|-----------------|
| **Language(s)** | Check file extensions, `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc. |
| **Framework** | Look at dependencies for known frameworks (React, Django, Express, Spring, etc.) |
| **Build System** | Check for `Makefile`, `CMakeLists.txt`, `webpack.config.js`, `build.gradle`, etc. |
| **Package Manager** | npm/yarn/pnpm, pip/uv/poetry, cargo, go modules, etc. |
| **Project Structure** | Map out the directory tree to understand the architecture |
| **Entry Points** | Find main files, CLI entry points, exported modules |
| **Existing Docs** | Check for existing README, docs/, wiki, or inline documentation |

#### Step 1.2: Code Structure Analysis

Explore the repository itself. Use the code index when one exists (e.g. a `.codegraph/` directory), the host's file-read and search tools otherwise:

```bash
# Directory structure, ignoring build output and dependencies
git -C <repo-root> ls-files | sed 's|/[^/]*$||' | sort -u | head -100

# Key manifests: read whichever exist (package.json, pyproject.toml, *.csproj, go.mod, Cargo.toml)

# Public API surfaces
git -C <repo-root> grep -n "^export "             -- '*.ts' '*.tsx'
git -C <repo-root> grep -n "^def \|^class "       -- '*.py'
git -C <repo-root> grep -n "^\s*public "          -- '*.cs'
git -C <repo-root> grep -n "^func [A-Z]"          -- '*.go'
```

#### Step 1.3: Identify Documentation Scope

Based on analysis, determine what documentation to produce:

| Project Size | Recommended Documentation |
|-------------|--------------------------|
| **Single file / script** | Inline comments + usage header |
| **Small library** | README with API reference |
| **Medium project** | README + API docs + examples |
| **Large project** | README + Architecture + API + Contributing + Changelog |

### Phase 2: Documentation Generation

Generate the required documentation types using the templates and conventions in `references/`:

- **README Documentation:** Follow [README Template](references/readme-template.md) for standard layout (features, quick start, installation, usage, configuration, contributing).
- **API Reference Documentation:** Follow [API Reference Template](references/api-reference-template.md) for public interfaces, parameters, returns, exceptions, and usage examples.
- **Architecture Documentation:** Follow [Architecture Template](references/architecture-template.md) for system diagrams, component overviews, data flows, and design decisions.
- **Inline Code Documentation:** Follow [Inline Code Documentation Patterns](references/inline-code-doc-patterns.md) for language-appropriate docstrings (JSDoc, XML doc comments, Python docstrings, Go doc comments).

### Phase 3: Quality Assurance

#### Step 3.1: Documentation Completeness Check

Verify the documentation covers:

- [ ] **What it is** — Clear project description that a newcomer can understand
- [ ] **Why it exists** — Problem it solves and value proposition
- [ ] **How to install** — Copy-paste-ready installation commands
- [ ] **How to use** — At least one minimal working example
- [ ] **API surface** — All public functions, classes, and types documented
- [ ] **Configuration** — All environment variables, config files, and options
- [ ] **Error handling** — Common errors and how to resolve them
- [ ] **Contributing** — How to set up dev environment and submit changes

#### Step 3.2: Quality Standards

| Standard | Check |
|----------|-------|
| **Accuracy** | Every code example must actually work with the described API |
| **Completeness** | No public API surface left undocumented |
| **Consistency** | Same formatting and structure throughout |
| **Freshness** | Documentation matches the current code, not an older version |
| **Accessibility** | No jargon without explanation, acronyms defined on first use |
| **Examples** | Every complex concept has at least one practical example |

#### Step 3.3: Cross-reference Validation

Ensure:
- All mentioned file paths exist in the project
- All referenced functions and classes exist in the code
- All code examples use the correct function signatures
- Version numbers match the project's actual version
- All links (internal and external) are valid

## Documentation Style Guide

### Writing Principles

1. **Lead with the "why"** — Before explaining how something works, explain why it exists
2. **Progressive disclosure** — Start simple, add complexity gradually
3. **Show, don't tell** — Prefer code examples over lengthy explanations
4. **Active voice** — "The function returns X" not "X is returned by the function"
5. **Present tense** — "The server starts on port 8080" not "The server will start on port 8080"
6. **Second person** — "You can configure..." not "Users can configure..."

### Formatting Rules

- Use ATX-style headers (`#`, `##`, `###`)
- Use fenced code blocks with language specification (` ```python `, ` ```bash `)
- Use tables for structured information (parameters, options, configuration)
- Use admonitions for important notes, warnings, and tips
- Keep line length readable (wrap prose at ~80-100 characters in source)
- Use `code formatting` for function names, file paths, variable names, and CLI commands

### Language-Specific Conventions

| Language | Doc Format | Style Guide |
|----------|-----------|-------------|
| Python | Google-style docstrings | PEP 257 |
| TypeScript/JavaScript | TSDoc / JSDoc | TypeDoc conventions |
| Go | GoDoc comments | Effective Go |
| Rust | Rustdoc (`///`) | Rust API Guidelines |
| Java | Javadoc | Oracle Javadoc Guide |
| C# | XML doc comments (`///`, `<summary>`) | .NET documentation comments guide; slim, per the workspace rulebook |
| C/C++ | Doxygen | Doxygen manual |

## Output Handling

After generation:

- Write documentation into the repository where it belongs (`README.md` at the root, `docs/` for guides and architecture, comments next to the code), following the repo's existing layout
- For multi-file documentation, mirror the project's directory structure
- Link every file you created or changed in the chat response, using the host's link format (`artifact-protocol` › *Host-Specific Link Formats*)
- Offer to iterate on specific sections or adjust the level of detail
- Suggest additional documentation that might be valuable

## Notes

- Always analyze the actual code before writing documentation — never guess at API signatures or behavior
- When existing documentation exists, preserve its structure unless the user explicitly asks for a rewrite
- For large codebases, prioritize documenting the public API surface and key abstractions first
- Documentation should be written in the same language as the project's existing docs; default to English if none exist
- When generating changelogs, use the [Keep a Changelog](https://keepachangelog.com/) format
- For third-party integrations or dependencies, check facts against their official docs at the version in use ([`/verify-assumptions`](../verify-assumptions/SKILL.md) does this systematically)
