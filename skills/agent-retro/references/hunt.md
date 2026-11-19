# Where reviews miss issues

On-demand reference for [`SKILL.md`](../SKILL.md) Steps 3–4. A review spends its attention on product code. These areas get less, so the hunt starts here. Each entry names the check that proves or refutes an issue; the example is the case that taught it.

| Area | What slips through | Check |
|---|---|---|
| Tool defaults | A built-in default of a tool (bot, linter, formatter, CI task) applies after the repo's own config and overrides it. | Read the tool's docs and source at the version the repo pins (image tag, lockfile) for the order its config is merged in. Example: Renovate's `vulnerabilityAlerts` forced `rangeStrategy: update-lockfile` over a `packageRules` `bump`. |
| Other checks in CI | The change produces output that a different CI check rejects (pinned versions, generated files, manifests). | List the CI jobs that read the changed files and run the ones that can run locally against the change's output. |
| Readers of new output | The change adds output (a PR comment, a file, a log line) that another tool already reads and now misjudges, such as a bot comment a review filter counts as human. | For each new output, grep the repo for every reader of that kind of output and check its filter against the new author, path or format. |
| Cut or truncated text | Text is balanced (code fences, HTML tags, Markdown blocks) only on the path that cuts it, so uncut input arrives unbalanced. | Feed the function input that needs no cut and still has an open fence or tag. |
| Parsers of outside names | Tags, versions and package names are parsed in the shapes the tests build, not the ones the repo really uses. | Trace the parser with real values from this repo's dependencies. Example: `@vitejs/plugin-react-swc` is tagged `plugin-react-swc@4.3.3`, without its scope. |
| Error messages | One message names a single cause (rejected token, missing permission) for every failure, so the reader chases the wrong fix. | For each message, list the responses that reach it; each must prove the cause it names. |
| Diff weight | A moved or reformatted file inflates one area's line count, so review effort goes there and away from a smaller, riskier area. | Compare where the earlier review spent its findings with where the logic changed (`git diff --stat -M`). |
| Instructions | Skills, rules and agent docs changed in the PR state facts the code does not back. | Check each changed claim against the code at the pinned head, or with the project's drift checker. |
| Rules citing outside facts | A rule or skill cites how an outside tool behaves (a default, a tag format), and its drift claim checks a nearby fact instead (the package exists, not its tag shape). | Check the cited fact at the version the repo pins, then check that the claim's `verify` would fail if the fact changed. |

The examples are the cases that taught each row. A miss that fits no row is a Step 6 cause (*a hunt row this skill lacks*); its fix is a new row here, routed like any other fix.
