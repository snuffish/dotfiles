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
vim.utils.map("nvixscoVRt", "<keymap>", "<otherkeymap>")
```
