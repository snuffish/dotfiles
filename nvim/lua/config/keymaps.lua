require("config.remaps")

-- Tmux navigation
vim.api.nvim_set_keymap("", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "Window left" })
vim.api.nvim_set_keymap("", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { desc = "Window right" })
vim.api.nvim_set_keymap("", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { desc = "Window down" })
vim.api.nvim_set_keymap("", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { desc = "Window up" })

-- Treewalker mapping
local Direction = {
  UP = "Up",
  DOWN = "Down",
  RIGHT = "Right",
  LEFT = "Left",
}

local treewalker_mappings = {
  ["K"] = Direction.UP,
  ["J"] = Direction.DOWN,
  ["L"] = Direction.RIGHT,
  ["H"] = Direction.LEFT,
}

for key, direction in pairs(treewalker_mappings) do
  vim.api.nvim_set_keymap(
    "",
    string.format("<M-S-%s>", key),
    "<cmd>Treewalker " .. direction .. "<cr>zz",
    { noremap = true, silent = true }
  )

  vim.api.nvim_set_keymap(
    "",
    "<cmd>Treewalker Swap" .. direction .. "<cr>zz",
    string.format("<M-C-%s>", key),
    { noremap = true, silent = true }
  )
end

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

vim.utils.map("n", "<leader>a", vim.utils.trigger_keys_fn("vag"), { noremap = true, silent = true, desc = "Select all text" })
vim.utils.map(
  "n",
  "<M-Up><M-Up>",
  vim.utils.trigger_keys_fn(":<Up>"),
  { desc = "Previous command", noremap = true, silent = true }
)
vim.utils.map("x", { "/", "g/" }, "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection (backward)" })
vim.utils.map("x", { "?", "g?" }, "<esc>?\\%V", { silent = false, desc = "Search Inside Visual Selection (forward)" })

-- Move cursor left/right in insert-mode
vim.utils.map("ic", "<C-a>", "<Home>", { silent = true, noremap = true })
vim.utils.map("ic", "<C-e>", "<End>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("i", "<C-h>", "<Left>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("i", "<C-l>", "<Right>", { silent = true, noremap = true })

-- Mini.Surround mapping
vim.api.nvim_set_keymap("n", ";;", ";a_", { desc = "Add row surrounding" })
vim.api.nvim_set_keymap("v", ";;", ";a", { desc = "Add surrounding" })

vim.utils.map('n', ';w', function()
  vim.cmd('normal! viw')
  vim.utils.trigger_keys(";;")
end, { desc = "Add surrounding on <cword>", noremap = true, silent = true })
