# Snuffish dotfiles

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
```
