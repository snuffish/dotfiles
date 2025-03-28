require("config.remaps")

vim.utils.map("n", "<F1>", ":", { noremap = true, silent = true })

vim.utils.map("n", "<leader>x", ":.lua<CR>", { noremap = true })
vim.utils.map("v", "<leader>x", ":<CR>", { noremap = true })

-- Tmux navigation
vim.api.nvim_set_keymap("", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "Window left" })
vim.api.nvim_set_keymap("", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { desc = "Window right" })
vim.api.nvim_set_keymap("", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { desc = "Window down" })
vim.api.nvim_set_keymap("", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { desc = "Window up" })

vim.api.nvim_set_keymap(
  "n",
  "<leader>yf",
  ':let @+ = expand("%:p")<CR>',
  { desc = "Yank filepath to system clipboard", noremap = true, silent = true }
)

vim.utils.map("n", "<localleader>a", function()
  local pattern = "%s %l %r"
  vim.o.statuscolumn = vim.o.statuscolumn ~= pattern and pattern or "%!v:lua.require'snacks.statuscolumn'.get()"
end, { desc = "Toggle `Absolute linenumbers`" })

vim.utils.map(
  "n",
  "<M-Up><M-Up>",
  vim.utils.trigger_keys_fn(":<Up>"),
  { desc = "Previous command", noremap = true, silent = true }
)

-- Move cursor left/right in insert-mode
-- vim.utils.map("ic", "<C-a>", "<Home>", { silent = true, noremap = true })
vim.utils.map("ic", "<C-a>", "<Esc>g^i", { silent = true, noremap = true })
vim.utils.map("ic", "<C-e>", "<End>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("i", "<C-h>", "<Left>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("i", "<C-l>", "<Right>", { silent = true, noremap = true })

vim.utils.map("n", "DM", "V%d", { noremap = true, desc = "Visual-Line delete match" })

vim.utils.map("n", "S", function()
  local jump2d = require("mini.jump2d")
  jump2d.start(jump2d.builtin_opts.line_start)
  vim.utils.trigger_keys("zz")
end, { silent = true })
