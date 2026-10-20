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
| `claude/` | Claude Code statusline script |
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
