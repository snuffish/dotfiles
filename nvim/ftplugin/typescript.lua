-- vim.api.nvim_create_autocmd("BufEnter", {
--   pattern = "*",
--   callback = function()
--     vim.api.nvim_set_keymap("n", "<leader>cq", "<cmd>Outline<CR>", { noremap = true, silent = true })
--   end,
-- })
--
-- vim.api.nvim_create_autocmd("BufLeave", {
--   pattern = "*",
--   callback = function()
--     vim.api.nvim_del_keymap("n", "<leader>cq")
--   end,
-- })
