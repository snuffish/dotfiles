## Agent skills

### Issue tracker

Issues are tracked as GitHub Issues on snuffish/dotfiles via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage labels are used as-is: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Skills registry

Local skill registry is in `skills/`. Run `python3 -I skills/sync-skills/sync_skills.py` to lint and sync loader symlinks. See `skills/README.md`.
