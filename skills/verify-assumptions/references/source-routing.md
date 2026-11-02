# Source routing

Read in Step 3. Pass the rows for each group's domain to its sub-agent in Step 4.

| Domain | Authoritative source | Leads only, never evidence |
|---|---|---|
| Claude Code, Agent SDK, Claude API | The official docs (`code.claude.com/docs`, `docs.claude.com`); in Claude Code delegate to the `claude-code-guide` agent | Blog posts, forum answers, model memory |
| Libraries and frameworks | The official docs at the pinned version, then the package's source or type definitions (`node_modules/…`, the NuGet package, the GitHub tag) | Stack Overflow, tutorials |
| Platforms (Azure DevOps, GitHub, cloud services) | Official REST and CLI reference, `--help` output | Third-party wrappers |
| The codebase | The code itself at the current head (`core` › *Codebase investigation* › *Navigation*) | Comments, READMEs that may have drifted |
| This machine | The config files and read-only commands that show the real state (settings files, `env`, `--version`) | Assumed defaults |

For a product without a row above, take its official home from the package's own metadata (npm `homepage`/`repository`, NuGet `projectUrl`), not from search ranking.

When the docs are silent, the source code is the next authority. Note the gap: "undocumented but the source does X" is a weaker basis than a documented guarantee.

## Version match

The cited page must document the pinned major. Unversioned sites often show only the latest one (`react.dev` documents React 19; React 18 lives at `18.react.dev`). Docs for another major make the verdict at most **Partial**, unless the changelog shows no change in between.
