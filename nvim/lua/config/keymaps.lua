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
vim.utils.map("ic", "<C-a>", "<Home>")
vim.utils.map("ic", "<C-d>", "<End>")

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

local function treewalker(direction)
  return function()
    vim.cmd("Treewalker " .. direction)
    vim.utils.trigger_keys("zz")
  end
end

local mappings = {
  ["<C-k>"] = Direction.UP,
  ["<C-j>"] = Direction.DOWN,
  ["<C-l>"] = Direction.RIGHT,
  ["<C-h>"] = Direction.LEFT,
}

for key, direction in pairs(mappings) do
  vim.utils.map("nv", key, treewalker(direction), { noremap = true, silent = true })
end
