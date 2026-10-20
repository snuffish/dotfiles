# Snuffish dotfiles

Personal dotfiles: modular Bash setup, Neovim (LazyVim), tmux, WezTerm, Ghostty and IdeaVim configs, plus Claude Code agent skills.

## What's inside

| Path | Description |
| --- | --- |
| `__init__.bash`, `*.bash` | Bash entry point and modules (aliases, git, docker, dotnet, azure, pulumi, fzf, network, iot/esp32, …) |
| `utils/`, `installer/` | Helper scripts and tool installers |
| `nvim/` | Neovim config based on LazyVim |
| `tmux/` | tmux config and plugins |
| `wezterm/` | WezTerm config |
| `ghostty.bash` | Ghostty helpers |
| `.ideavimrc` | IdeaVim (JetBrains) config |
| `vscode/` | VS Code settings and keybindings |
| `autohotkey/` | AutoHotkey scripts for Windows |
| `skills/` | Claude Code agent skills |
| `claude/`, `claude.bash` | Claude Code statusline and `cm-sync` (claude-mem sync between devices) |
| `docs/`, `GLOSSARY.md` | ADRs and agent docs |

## Setup

Run this in the terminal: `echo "source ~/.terminal/__init__.bash" >> ~/.bash_profile`

### Symbol links

Create symlinks for configurations of applications

```bash
# NeoVIM
mkdir -p ~/.config && ln -sf ~/.terminal/nvim ~/.config/nvim

# Tmux
ln -sf ~/.terminal/tmux/tmux.conf ~/.tmux.conf

# WezTerm
mkdir -p ~/.config/wezterm && ln -sf ~/.terminal/wezterm/wezterm.lua ~/.wezterm.lua

# Claude Code statusline (also set "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" } in ~/.claude/settings.json)
mkdir -p ~/.claude && ln -sf ~/.terminal/claude/statusline.sh ~/.claude/statusline.sh
```

## claude-mem sync

`cm-sync` keeps [claude-mem](https://github.com/thedotmack/claude-mem) memory the same on every computer, through the private repo cloned at `~/.terminal/memory` (`snuffish/claude-memory`). Memory never goes into this public repo.

On a new machine, after the setup above:

```bash
cm-sync setup   # checks bun/node/git, the plugin and worker, clones the memory repo, turns on redaction, names the device
cm-sync sync    # pull, import other devices, export this one, commit and push
```

| Command | Does |
| --- | --- |
| `cm-sync sync` | Pull → import → export → commit only this device's folder → push |
| `cm-sync import` | Pull the memory repo, then import other devices' rows and apply their deletions (`--no-pull` to skip the pull, `--full` after a database reset) |
| `cm-sync export` | Write this device's rows to `claude-mem/devices/<device-id>/` (`--with-prompts` to include raw prompts) |
| `cm-sync status` | Worker, redaction, counts per device, last push |
| `cm-sync hooks` | Print Claude Code hooks that import on session start and sync on session end |
| `cm-sync refile <session-id> <project>` | Move a session's observations and summaries to another project (claude-mem files a session under the folder it started in) |

How it works:

- Each device publishes only the rows it created, as JSON Lines, and imports the others through the claude-mem worker (`POST /api/import`), so search and vector indexes stay correct. Nothing writes to `claude-mem.db` directly.
- Deleting a row on the device that created it publishes a tombstone, and the other devices delete their copy on the next import.
- Export refuses to run while claude-mem redaction is off, skips `sensitive` observations, and aborts when a row looks like a secret (`--exclude-flagged` keeps those rows local). Local state lives in `~/.local/state/cm-sync/`.
- Tests: `python3 -I -m unittest discover -s ~/.terminal/claude -p 'test_*.py'`

If a secret reaches a commit anyway, deleting the row is not enough: rewrite the memory repo's history and re-clone it on every device.

```bash
git -C ~/.terminal/memory filter-repo --path claude-mem/devices/<device-id>/<file> --invert-paths
git -C ~/.terminal/memory push --force
```
