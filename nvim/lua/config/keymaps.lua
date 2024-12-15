vim.keymap.set("n", "<leader>a", "ggVG", { desc = "Select all text", silent = true })
vim.keymap.set("n", "<A-Up><A-Up>", ":<Up>", { desc = "Previous command", noremap = true, silent = true })

-- Explorers
vim.api.nvim_set_keymap("n", "<leader>E", "<cmd>Neotree reveal<CR>", { desc = "Neotree" })
vim.api.nvim_set_keymap("n", "<leader>e", "<cmd>lua require('oil').toggle_float()<CR>", { desc = "Oil Explorer" })

-- Mini.Surround mapping
vim.api.nvim_set_keymap("n", "sa", "gza", { desc = "Add surrounding" })
vim.api.nvim_set_keymap("n", "ds", "gzd", { desc = "Delete surrounding" })
vim.api.nvim_set_keymap("n", "cs", "gzc", { desc = "Change surrounding" })
