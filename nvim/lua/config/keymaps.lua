require("config.globals")
require("config.remaps")

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

vim.utils.map("n", "<leader>a", "ggVG", { desc = "Select all text", silent = true })
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
vim.api.nvim_set_keymap("", "öa", ";a", { desc = "Add surrounding" })
vim.api.nvim_set_keymap("", "öd", ";d", { desc = "Delete surrounding" })
vim.api.nvim_set_keymap("", "öf", ";f", { desc = "Find right surrounding" })
vim.api.nvim_set_keymap("", "öF", ";F", { desc = "Find left surrounding" })
vim.api.nvim_set_keymap("", "ör", ";r", { desc = "Replace surrounding" })
vim.api.nvim_set_keymap("n", "öö", ";a_", { desc = "Add row surrounding" })
vim.api.nvim_set_keymap("v", "öö", ";a", { desc = "Add surrounding" })

-- Tab navigation
vim.utils.map("n", { "<Tab>l", "<Tab><Tab>" }, "<cmd>BufferLineCycleNext<CR>", { noremap = true, silent = true })
vim.utils.map(
  "n",
  { "<Tab>h", "<Tab><S-Tab>", "<S-Tab><S-Tab>" },
  "<cmd>BufferLineCyclePrev<CR>",
  { noremap = true, silent = true }
)

-- Treewalker mappings
local Direction = {
  UP = "Up",
  DOWN = "Down",
  RIGHT = "Right",
  LEFT = "Left",
}

local mappings = {
  ["k"] = Direction.UP,
  ["j"] = Direction.DOWN,
  ["l"] = Direction.RIGHT,
  ["h"] = Direction.LEFT,
}

for key, direction in pairs(mappings) do
  local navMap = string.format("<C-%s>", key)
  local swapMap = string.format("<M-C-%s>", key)

  vim.api.nvim_set_keymap("", navMap, "<cmd>Treewalker " .. direction .. "<cr>zz", { noremap = true, silent = true })

  vim.keymap.set("n", swapMap, function()
    vim.cmd("Treewalker Swap" .. direction)
  end, { noremap = true, silent = true })
end

-- vim.keymap.set("n", "<C-S-j>", "<cmd>Treewalker SwapDown<cr>", { silent = true })
-- vim.keymap.set("n", "<C-S-k>", "<cmd>Treewalker SwapUp<cr>", { silent = true })
-- vim.keymap.set("n", "<C-S-l>", "<cmd>Treewalker SwapRight<CR>", { silent = true })
-- vim.keymap.set("n", "<C-S-h>", "<cmd>Treewalker SwapLeft<CR>", { silent = true })

-- Open compiler
vim.api.nvim_set_keymap("n", "<F6>", "<cmd>CompilerOpen<cr>", { noremap = true, silent = true })

-- Redo last selected option
vim.api.nvim_set_keymap(
  "n",
  "<S-F6>",
  "<cmd>CompilerStop<cr>" -- (Optional, to dispose all tasks before redo)
    .. "<cmd>CompilerRedo<cr>",
  { noremap = true, silent = true }
)

-- Toggle compiler results
vim.api.nvim_set_keymap("n", "<S-F7>", "<cmd>CompilerToggleResults<cr>", { noremap = true, silent = true })
