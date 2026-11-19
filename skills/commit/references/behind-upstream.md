# commit: integrate when the branch is behind its upstream

Read from `commit` Step 6 when the push is rejected as non-fast-forward (`fetch first`). Push again in the same mode Step 6 chose.

1. Note the incoming commits: `git -C <repo-root> fetch` then `git -C <repo-root> log --oneline HEAD..@{u}` (name them in the output).
2. `git -C <repo-root> pull --rebase --autostash`. This only replays this branch's unpushed commits onto `@{u}`; nothing already pushed is rewritten.
3. **Conflicts:** resolve them in place per [`/resolve-conflicts`](../../resolve-conflicts/SKILL.md) (rebase mode: Steps 1–6), then `git -C <repo-root> -c core.editor=true rebase --continue` until done. When a hunk's intent cannot be reconstructed with confidence, run `git -C <repo-root> rebase --abort`, confirm `HEAD` is back on the local commit, and stop with the conflicting files and the incoming commits.
4. **Re-run the `commit` Step 2 drift checker** when `git -C <repo-root> diff --name-only ORIG_HEAD HEAD` (or the incoming log) touches `skills/`, `.claude/`, `AGENTS.md` or the claims file. STALE fixes become their own follow-up commit (`fix(skills): …`), committed per `commit` Step 5.
5. Push again (plain `git -C <repo-root> push`). Rejected a second time for the same reason → repeat once from 1, then stop.

Output line, after the commit line:

```markdown
- Rebased onto <n> incoming commits (<conflicts resolved: files | clean>; drift re-run: <result>)
```
