local map = require("utils").map

map("n", "<leader>sr", function()
  local currentBuffer = vim.api.nvim_get_current_buf()
  local currentFile = vim.api.nvim_buf_get_name(currentBuffer)

  vim.cmd("source " .. currentFile)
  vim.notify("Sourced file: " .. currentFile, vim.log.levels.INFO, { title = "Sourced" })
end, { desc = "Source Current File" })

-- Regex replaces
map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })
map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })

-- Regex deletes
map("n", "DD", "<Esc>:g//d<Left><Left>", { noremap = true, desc = "Regex delete (global)" })
map("x", "DD", "<Esc>:'<,'>g//d<Left><Left>", { noremap = true, desc = "Regex delete (selection)" })

map("n", "+", "<C-a>", { silent = true, desc = "Increment integer" })
map("n", "-", "<C-x>", { silent = true, desc = "Decrement integer" })

map("n", "<leader>a", "ggVG", { desc = "Select all" })

map("v", "<Tab>", "=", { silent = true, desc = "Auto-indent" })

map("n", "<F1>", "<cmd>TransparentToggle<cr>", { noremap = true, silent = true })

map("x", "g/", "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection" })

map("n", "<Up><Up>", ":<Up>", { desc = "Goto previous command" })

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

-- Go to start or end of line easier
map("nx", "H", "^")
map("nx", "L", "g_")

-- Move cursor left/right in insert-mode
map("ci", "<C-a>", "<Home>")
map("ci", "<C-d>", "<End>")

map("n", "<LocalLeader>x", ":substitutes*\\%#\\u*/\\r/e <bar> normal! ==^<cr>", { desc = "Split line", silent = true })

-- Delete without yanking
map("n", "cW", '"_ciw')
map("n", "yW", "yiw")

map("n", "DD", "dd")

