-- On loaded
LazyVim.on_load("which-key.nvim", function()
  require("config.remaps")
end)

local map = require("utils").map

-- Existing keymap
map("n", {
  "<leader>sr",
  "<localleader>sr"
}, function()
  local currentBuffer = vim.api.nvim_get_current_buf()
  local currentFile = vim.api.nvim_buf_get_name(currentBuffer)

  vim.cmd("source " .. currentFile)
  vim.notify("Sourced file: " .. currentFile, vim.log.levels.INFO, { title = "Sourced" })
end, { desc = "Source Current File" })

-- Regex replaces
map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })
map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })

-- Regex deletes
map("n", "DD", "<Esc>:%s//<Left>", { noremap = true, desc = "Regex delete (selection)" })
map("x", "DD", "<Esc>:'<,'>s//<Left>", { noremap = true, desc = "Regex delete (selection)" })

map("n", "+", "<C-a>", { noremap = true, silent = true, desc = "Increment integer" })
map("n", "-", "<C-x>", { noremap = true, silent = true, desc = "Decrement integer" })

map("v", "<Tab>", "=", { silent = true, desc = "Auto-indent" })

map("n", "<F1>", "<cmd>TransparentToggle<cr>", { noremap = true, silent = true })

map("x", { "/", "g/", }, "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection" })

map("n", "<A-Up><A-Up>", ":<Up>", { desc = "Goto previous command", noremap = true })

map(
  "n",
  "<leader>wv",
  "<C-w>v<C-w>p<cmd>e #<CR><C-w>p",
  { noremap = true, silent = false, desc = "Vertical split (Orginal window navigate to AlternativeBuffer)" }
)

map(
  "n",
  "<leader>ws",
  "<C-w>s<C-w>p<cmd>e #<CR><C-w>p",
  { noremap = true, silent = false, desc = "Horizontal split (Orginal window navigate to AlternativeBuffer)" }
)

-- Move cursor left/right in insert-mode
map("ci", "<C-a>", "<Home>")
map("ci", "<C-d>", "<End>")

-- Delete without yanking
map("n", "cW", '"_ciw')
map("n", "yW", '"_yiw')

-- Local
map("n", { "<localleader>a", "<leader>a" }, "ggVG", { desc = "Select all text" })
map("n", "gx", "i<CR><Esc>==", {  desc = "Split line", silent = true })

-- Define a macro to be stored in register 'a'
-- vim.cmd("let @a = 'viwsaq'")

-- Map a key to execute the macro stored in register 'a'
-- vim.api.nvim_set_keymap('n', 'saa', '@a', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', 'sab', "@a", { noremap = true, silent = true })

-- Wrap the cursors words position - (...)
map("n", "saq", function ()
  vim.cmd("let @z = 'viwsaq' | normal! @z")
end, { desc = "Wrap the cursors words position [quotes] \"`'...\"`'" })

-- Wrap the cursors words position - ()
map("n", "sab", function ()
  vim.cmd("let @z = 'viwsa(' | normal! @z")
end, { desc = "Wrap the cursors words position - (...)" })

-- Wrap the cursors words position - {...}
map("n", "saB", function ()
  vim.cmd("let @z = 'viwsa{' | normal! @z")
end, { desc = "Wrap the cursors words position - {...}" })

-- Wrap the cursors words position - [...]
map("n", "saa", function ()
  vim.cmd("let @z = 'viwsa[' | normal! @z")
end, { desc = "Wrap the cursors words position - [...]" })

map("n", "sat", function ()
  vim.cmd("let @z = 'sa_t' | normal! @z")
end, { desc = "Add new tag element and add cursor betweens its open/close tag (horizontally)"})

map("n", "saT", function ()
  vim.cmd("let @z = 'sa_t' | normal! @z")
  vim.cmd("let @z = \"i\\<CR>\\<CR>\\<Esc>k==a\" | normal! @z")
end, { desc = "Add new tag element and add cursor betweens its open/close tag (verticaly)"})

