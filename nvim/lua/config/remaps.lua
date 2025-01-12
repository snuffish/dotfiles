-- Remap q to Q to prevent accidently pressing the recording key
vim.utils.map("n", "q", "<nop>", { noremap = true, silent = true })
vim.utils.map("n", "<C-q>", "q", { desc = "Start/Stop Macro recording", noremap = true, silent = true })

vim.api.nvim_set_keymap("", "m", "%", { silent = true })
vim.api.nvim_set_keymap("", "M", "%", { silent = true })

vim.utils.map("n", { "<C-u>", "<PageUp>" }, "<C-u>zz", { desc = "Jump up 1/2-screen", noremap = true })
vim.utils.map("n", { "<C-d>", "<PageDown>" }, "<C-d>zz", { desc = "Jump down 1/2-screen", noremap = true })
vim.utils.map("n", "{", "{zz")
vim.utils.map("n", "}", "}zz")

vim.utils.map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
vim.utils.map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

vim.utils.map("n", "G", "Gzz")
vim.utils.map("n", "GG", vim.utils.trigger_keys_fn("G2goGzzi"), { desc = "Goto last line and add 2 new lines" })

vim.utils.map("n", "gg", "gg")
vim.utils.map("n", "ggg", vim.utils.trigger_keys_fn("gg2gOggi"), { desc = "Goto first line and add 2 new lines" })

-- Do not include white space characters when using $ in visual mode,
vim.utils.map("x", "$", "g_")

vim.utils.map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
vim.utils.map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
vim.utils.map("n", "0", "g0")

-- Amplify hjkl
vim.utils.map("nx", "J", "5jzz")
vim.utils.map("nx", "K", "5kzz")
vim.api.nvim_set_keymap("", "H", "[b", {})
vim.api.nvim_set_keymap("", "L", "]b", {})

-- Delete without yanking
vim.utils.map("n", "xp", "xph")
vim.utils.map("n", "XP", "Xp")
vim.utils.map("n", "x", '"_x', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
vim.utils.map("n", "X", '"_X', { noremap = true, silent = true, desc = "Delete char (No yanking)" })

vim.utils.map("i", ";;", "<C-o>")
vim.utils.map("i", ";a", "<End>")
vim.utils.map("i", ";o", "<C-o>o")
vim.utils.map("i", ";O", "<C-o>O")

vim.utils.map("n", "DD", '"_d^', { noremap = true, silent = true, desc = "Delete characters from cursor to first whitespace (No yanking)" })
vim.utils.map("n", "CC", '"_c^', { noremap = true, silent = true, desc = "Change character from cursor to first whitespace (No yanking)" })

vim.utils.map(
  "n",
  "d0",
  '"_g^d$',
  { noremap = true, silent = true, desc = "Delete from cursor to white non-whitespace character" }
)
