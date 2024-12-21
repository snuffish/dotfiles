require("config.remaps")

vim.utils.map("i", {"jk", "kj"}, "<Esc>")

vim.api.nvim_set_keymap(
  "n",
  "<leader>yf",
  ':let @+ = expand("%:p")<CR>',
  { desc = "Yank filepath to system clipboard", noremap = true, silent = true }
)

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
vim.api.nvim_set_keymap("", "yS", "ys$", { desc = "Add surround (from cursor to line-end)" })
vim.api.nvim_set_keymap("v", "S", "ys", { desc = "Add surrounding" })
vim.api.nvim_set_keymap("x", "S", "ys", { desc = "Add surrounding" })
vim.api.nvim_set_keymap("", "ds", "gzd", { desc = "Delete surrounding" })
vim.api.nvim_set_keymap("", "cs", "gzc", { desc = "Change surrounding" })

-- Flash and navigation mappings
vim.utils.map("i", { "<Tab>", "<S-Tab>" }, "<Esc>l", { silent = true, desc = "Exit insert mode" })
vim.utils.map("nx", "<Tab>", "<cmd>TSTextobjectGotoNextEnd @parameter.inner<CR>", { silent = true, desc = "Exit insert mode" })
vim.utils.map("nx", "<S-Tab>", "<cmd>TSTextobjectGotoPreviousStart @parameter.inner<CR>", { silent = true, desc = "Exit insert mode" })

vim.api.nvim_set_keymap("", "s", "gfs", { desc = "Flash Jump (forward)" })
vim.api.nvim_set_keymap("", "S", "gfS", { desc = "Flash Jump (backward)" })
vim.api.nvim_set_keymap("", "yl", "ygfl", { desc = "Flash Yank Remote Line (upwards)" })
vim.api.nvim_set_keymap("", "yL", "ygfL", { desc = "Flash Yank Remote Line (downwards)" })
vim.api.nvim_set_keymap("", "yt", "ygft", { desc = "Flash TreeSitter Yank Search" })

