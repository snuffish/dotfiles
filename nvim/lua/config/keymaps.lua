require("config.remaps")

vim.utils.map("n", "<leader><leader>x", "<cmd>source %<CR>", { noremap = true })
vim.utils.map("n", "<leader>x", ":.lua<CR>", { noremap = true })
vim.utils.map("v", "<leader>x", ":<CR>", { noremap = true })

-- Tmux navigation
vim.api.nvim_set_keymap("", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "Window left" })
vim.api.nvim_set_keymap("", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { desc = "Window right" })
vim.api.nvim_set_keymap("", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { desc = "Window down" })
vim.api.nvim_set_keymap("", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { desc = "Window up" })

local treewalker_mappings = {
  ["K"] = "Up",
  ["J"] = "Down",
  ["L"] = "Right",
  ["H"] = "Left",
}

for key, direction in pairs(treewalker_mappings) do
  vim.utils.map(
    "n",
    string.format("<C-M-%s>", key),
    "<cmd>Treewalker " .. direction .. "<cr>zz",
    { noremap = true, silent = true }
  )
end

vim.utils.map("n", "<leader>rl", "<cmd>Treewalker SwapRight<CR>", { desc = "SwapRight", noremap = true })
vim.utils.map("n", "<leader>rh", "<cmd>Treewalker SwapLeft<CR>", { desc = "SwapLeft", noremap = true })
vim.utils.map("n", "<leader>rj", "<cmd>Treewalker SwapDown<CR>", { desc = "SwapDown", noremap = true })
vim.utils.map("n", "<leader>rk", "<cmd>Treewalker SwapUp<CR>", { desc = "SwapUp", noremap = true })

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
vim.utils.map("ic", "<C-a>", "<Home>", { silent = true, noremap = true })
vim.utils.map("ic", "<C-e>", "<End>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("i", "<C-h>", "<Left>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("i", "<C-l>", "<Right>", { silent = true, noremap = true })

-- Mini.Surround mapping
vim.api.nvim_set_keymap("n", ";;", ";a_", { desc = "Add row surrounding" })
vim.api.nvim_set_keymap("v", ";;", ";a", { desc = "Add surrounding" })

vim.utils.map("n", ";w", function()
  vim.cmd("normal! viw")
  vim.utils.trigger_keys(";;")
end, { desc = "Add surrounding on <cword>", noremap = true, silent = true })

-- vim.utils.map("n", "<C-f>", function()
--   local jump2d = require("mini.jump2d")
--   jump2d.start(jump2d.builtin_opts.line_start)
--   vim.utils.trigger_keys("zz")
-- end, { noremap = true })
