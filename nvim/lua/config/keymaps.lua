require("config.remaps")

vim.api.nvim_set_keymap("", "<localleader>z", "<leader>uz", { desc = "Toggle 'Zen Mode'" })
vim.api.nvim_set_keymap("", "<localleader>Z", "<leader>uZ", { desc = "Toggle 'Zoom Mode'" })

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
vim.api.nvim_set_keymap("", "ys", "gza", { desc = "Add surrounding" })
vim.api.nvim_set_keymap("", "yss", "ys_", { desc = "Add surrounding (whole row)" })
vim.api.nvim_set_keymap("", "ds", "gzd", { desc = "Delete surrounding" })
vim.api.nvim_set_keymap("", "cs", "gzc", { desc = "Change surrounding" })

local function map_text_object(key)
  vim.api.nvim_set_keymap("n", "<C-i>" .. key, string.format("vi%s%si", key, vim.keycode("<Esc>")), { desc = "Prepennd after " .. key })
  vim.api.nvim_set_keymap("n", "<C-e>" .. key, string.format("vi%so%sa", key, vim.keycode("<Esc>")), { desc = "Apend after " .. key })
end
map_text_object("q")
map_text_object("d")

local test = "dsadsadasdas"

vim.api.nvim_set_keymap("i", "<C-a>", string.format("vi%so%sa", key, vim.keycode("<Esc>")), { desc = "Apend after " .. key })

vim.api.nvim_set_keymap("", "cs", "gzc", {})

-- vim.api.nvim_set_keymap("", "hq", "gzhq", { desc = "Highlight surrounding" })

-- Mini.ai mapping
-- vim.api.nvim_set_keymap("n", "	q", "vinqi", {})
-- vim.api.nvim_set_keymap("v", "	q", "inq" .. vim.keycode("<Esc>") .. "i", {})

-- vim.utils.map("	n", "€kBn", function()
--   vim.utils.trigger_keys("viqo" .. vim.keycode("<Esc>") .. "a")
--   -- vim.cmd("stopinser t")
-- end)
-- vim.api.nvim_set_keymap("", "<C-i>", "viqo\\<Esc>i", { noremap = true, silent = true, desc = "Change surrounding" })

-- Insert/append into current text-objects
-- vim.utils.map("n", "<C-i>q", function()
--   vim.cmd("TSTextobjectGotoNextStart @parameter.inner")
-- end)

-- vim.utils.map("ni", "<C-e>q", function()
--   vim.cmd("TSTextobjectGotoNextEnd @parameter.inner")
--   vim.utils.trigger_keys("i")
-- end)

-- vim.utils.map("n", "<C-b>", function()
--   vim.cmd("TSTextobjectRepeatLast")
-- end)

