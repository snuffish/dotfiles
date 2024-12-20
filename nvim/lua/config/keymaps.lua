require("config.remaps")

vim.utils.nvim_map('n', '<leader>yf', ':let @+ = expand("%:p")<CR>', { desc = "Yank filepath to system clipboard", noremap = true, silent = true })

vim.utils.map("n", "<localleader>a", function()
  local pattern = "%s %l %r"
  vim.o.statuscolumn = vim.o.statuscolumn ~= pattern and pattern or ""
end, { desc = "Toggle `Absolute linenumbers`" })

vim.utils.map("n", "<leader>a", "ggVG", { desc = "Select all text", silent = true })
vim.utils.map("n", "<A-Up><A-Up>", ":<Up>", { desc = "Previous command", noremap = true, silent = true })
vim.utils.map("x", { "/", "g/" }, "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection" })

-- Move cursor left/right in insert-mode
vim.utils.map("ci", "<A-a>", "<Home>")
vim.utils.map("ci", "<A-d>", "<End>")

-- Regex replaces
vim.utils.map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })
vim.utils.map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })

-- Regex deletes
vim.utils.map("n", "DD", "<Esc>:%s//<Left>", { noremap = true, desc = "Regex delete (selection)" })
vim.utils.map("x", "DD", "<Esc>:'<,'>s//<Left>", { noremap = true, desc = "Regex delete (selection)" })

-- Mini.Surround mapping
vim.utils.nvim_map("", "ys", "gza", { desc = "Add surrounding" })
vim.utils.nvim_map("", "yss", "ys_", { desc = "Add surrounding (whole row)" })
vim.utils.nvim_map("", "yS", "ys$", { desc = "Add surround (from cursor to line-end)" })
vim.utils.nvim_map("vx", "S", "ys", { desc = "Add surrounding" })
vim.utils.nvim_map("", "ds", "gzd", { desc = "Delete surrounding" })
vim.utils.nvim_map("", "cs", "gzc", { desc = "Change surrounding" })






-- local function map_text_object(key)
--   vim.api.nvim_set_keymap("n", "<C-i>" .. key, string.format("vi%s%si", key, vim.keycode("<Esc>")), { desc = "Prepennd after " .. key })
--   vim.api.nvim_set_keymap("n", "<C-e>" .. key, string.format("vi%so%sa", key, vim.keycode("<Esc>")), { desc = "Apend after " .. key })
-- end

-- map_text_object("q")
-- map_text_object("d")

-- vim.api.nvim_set_keymap("o", "iw", "iw", { noremap = true, desc = "Inside word" })
-- vim.api.nvim_set_keymap("o", "aw", "aw", { noremap = true, desc = "Around word" })

-- vim.utils.map("n", "<Char-00b4>", "<cmd>echo 55555  <CR>")



