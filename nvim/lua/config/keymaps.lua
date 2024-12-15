require("config.remaps")

local map = require("config.utils").map

local toggle_absolute_lineNr = function()
  -- if vim.wo.relativenumber then
  --   vim.wo.relativenumber = false
  --   vim.wo.number = true
  -- else
  --   vim.wo.relativenumber = true
  --   vim.wo.number = false
  -- end
  vim.o.statuscolumn = "%s %l %r"
end

map("n", "<localleader>a", function()
  toggle_absolute_lineNr()
end)

map("n", "<leader>a", "ggVG", { desc = "Select all text", silent = true })
map("n", "<A-Up><A-Up>", ":<Up>", { desc = "Previous command", noremap = true, silent = true })
map("x", { "/", "g/" }, "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection" })

-- Move cursor left/right in insert-mode
map("ci", "<C-a>", "<Home>")
map("ci", "<C-d>", "<End>")

vim.api.nvim_set_keymap("n", "<localleader>z", "<leader>uz", { desc = "Toggle 'Zen Mode'" })

-- Explorers
vim.api.nvim_set_keymap("n", "<leader>E", "<cmd>Neotree reveal<CR>", { noremap = true, desc = "Neotree" })
vim.api.nvim_set_keymap(
  "n",
  "<leader>e",
  "<cmd>lua require('oil').toggle_float()<CR>",
  { noremap = true, desc = "Oil Explorer" }
)

-- Mini.Surround mapping
vim.api.nvim_set_keymap("n", "sa", "gza", { desc = "Add surrounding" })
vim.api.nvim_set_keymap("n", "ds", "gzd", { desc = "Delete surrounding" })
vim.api.nvim_set_keymap("n", "cs", "gzc", { desc = "Change surrounding" })

-- Regex replaces
map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })
map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })

-- Regex deletes
map("n", "DD", "<Esc>:%s//<Left>", { noremap = true, desc = "Regex delete (selection)" })
map("x", "DD", "<Esc>:'<,'>s//<Left>", { noremap = true, desc = "Regex delete (selection)" })
