-- Remap q to Q to prevent accidently pressing the recording key
vim.utils.map("n", "q", "<nop>", { noremap = true, silent = true })
vim.utils.map("n", "<C-A-q>", "q", { desc = "Start/Stop Macro recording", noremap = true, silent = true })

vim.utils.map("n", "m", "<nop>", { noremap = true, silent = true })
vim.utils.map("n", "gM", "m", { desc = "Add marks", noremap = true, silent = true })

vim.utils.map("n", "<leader>n", "<nop>", { noremap = true, silent = true })
vim.utils.map(
  "n",
  "<leader>nn",
  "<cmd>lua Snacks.notifier.show_history()<CR>",
  { noremap = true, silent = true, desc = "Notifications" }
)

vim.api.nvim_set_keymap("", "\\", "<localleader>", { silent = true })

vim.api.nvim_set_keymap("", "m", "%", { silent = true })
vim.api.nvim_set_keymap("", "M", "V%", { silent = true })

vim.api.nvim_set_keymap("", "U", "<C-R>", { silent = true })

vim.utils.map("n", { "<C-u>", "<PageUp>" }, "<C-u>zz", { desc = "Jump up 1/2-screen", noremap = true })
vim.utils.map("n", { "<C-d>", "<PageDown>" }, "<C-d>zz", { desc = "Jump down 1/2-screen", noremap = true })
vim.utils.map("n", "}", "}zz")
vim.utils.map("n", "{", "{zz")
vim.utils.map("n", ")", ")zz")
vim.utils.map("n", "(", "(zz")

vim.utils.map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
vim.utils.map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

vim.utils.map("n", "G", "Gzz")
vim.utils.map(
  "n",
  { "GO", "GG" },
  vim.utils.trigger_keys_fn("G2goGzzi"),
  { desc = "Goto last line and add 2 new lines" }
)

vim.utils.map("n", "gg", "gg_")
vim.utils.map(
  "n",
  { "ggo", "ggg" },
  vim.utils.trigger_keys_fn("gg2gOggi"),
  { desc = "Goto first line and add 2 new lines" }
)

-- Do not include white space characters when using $ in visual mode,
vim.utils.map("x", "$", "g_")

vim.utils.map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
vim.utils.map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
vim.utils.map("n", "0", "g0")

-- Amplify hjkl
vim.utils.map("nx", "J", "5jzz", { noremap = true, silent = true })
vim.utils.map("nx", "K", "5kzz", { noremap = true, silent = true })

-- Delete without yanking
vim.utils.map("n", "xp", "xph")
vim.utils.map("n", "XP", "Xp")
vim.utils.map("n", "x", '"_x', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
vim.utils.map("n", "X", '"_X', { noremap = true, silent = true, desc = "Delete char (No yanking)" })

vim.utils.map("i", ";;", "<C-o>")
vim.utils.map("i", ";a", "<End>")
vim.utils.map("i", ";o", "<C-o>o")
vim.utils.map("i", ";O", "<C-o>O")

vim.utils.map(
  "n",
  "d0",
  '"_dg^',
  { noremap = true, silent = true, desc = "Delete from cursor to first white non-whitespace character" }
)

vim.utils.map(
  "n",
  "c0",
  '"_cg^',
  { noremap = true, silent = true, desc = "Change from cursor to first white non-whitespace character" }
)

vim.utils.map(
  "n",
  "y0",
  "y^",
  { noremap = true, silent = true, desc = "Delete from cursor to first white non-whitespace character" }
)

vim.utils.map(
  "n",
  "yy",
  vim.utils.trigger_keys_fn("gMyg^Y`y"),
  { noremap = true, silent = true, desc = "Yank row" }
)
