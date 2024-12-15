require("config.remaps")

local map = require("config.utils").map

map("n", "<leader>a", "ggVG", { desc = "Select all text", silent = true })
map("n", "<A-Up><A-Up>", ":<Up>", { desc = "Previous command", noremap = true, silent = true })
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
