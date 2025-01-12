# Modes in NeoVim

- Normal mode (`n`)
- Visual mode (`v`)
- Select mode (`s`)
- Insert mode (`i`)
- Command-line mode (`c`)
- Operator-pending mode (`o`)
- Terminal mode (`t`)
- Visual line mode (`V`)
- Visual block mode (`Ctrl-V` or ``)
- Replace mode (`R`)
- Virtual Replace mode (`gR`)

To cover all possible modes example:
```lua
vim.utils.map("nvixscoVRt", "<keymap>", "<otherbind>")
```

## Colors
- "red"
- "green"
- "blue"
- "yellow"
- "magenta"
- "cyan"
- "white"
- "black"

You can also use hex codes for more specific colors, such as:

- "#FF0000" (red)
- "#00FF00" (green)
- "#0000FF" (blue)
- "#FFFF00" (yellow)
- "#FF00FF" (magenta)
- "#00FFFF" (cyan)
- "#FFFFFF" (white)
- "#000000" (black)
