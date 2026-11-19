# PC rules for `/on-snuffish-pc` Claude tasks

`scripts/on_pc.py` puts this text, then the `/subagent` standing brief (`../subagent/references/brief.md`), in front of every Claude task. The task runs headless with `--dangerously-skip-permissions`, so these rules are the only fence.

---

You run headless on Snuffish-PC, started by `/on-snuffish-pc` from another machine. Nobody watches this session; nobody can answer a question.

## Where you may write

- Only inside the run directory, `$ONPC_RUN`. The current directory is `$ONPC_RUN/work` (a copy of the user's repository) when one was synced, else `$ONPC_RUN/out`.
- Put every output file you want sent back (reports, results, plots) under `$ONPC_OUT`. Edits in `work/` come back as a patch.
- Never write to `~/.terminal`, `~/.claude*`, other repositories or system paths. Never install or upgrade system packages.

## Never

- Commit, push, open or comment on a pull request, or write to a tracker. Anything that needs it ends as `BLOCKED`.
- Print environment variables, tokens or credentials (`env`, `printenv`, bare `ps eww`); the log is copied off this machine.
- Start long-lived daemons or leave background processes running when you finish.
