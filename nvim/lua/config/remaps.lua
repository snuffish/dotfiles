vim.keymap.del("n", "<leader>l")
-- vim.utils.map("n", "<leader>l", "<nop>", { silent = true })

-- vim.utils.map("nvxo", ",", vim.utils.trigger_keys_fn("<localleader>"), { nowait = true ,noremap = true})

-- Remap q to Q to prevent accidently pressing the recording key
vim.utils.map("n", "q", "<nop>", { noremap = true, silent = true })
vim.utils.map("n", "Q", "q", { noremap = true, silent = true })

vim.utils.map("oxn", { "m", "M" }, "%", { silent = true })

vim.utils.map("i", "<ESC>", "<nop>")
vim.utils.map("iv", vim.g.capslock_key, "<Esc>", { noremap = true, silent = true, desc = "Exit insert mode" })

vim.utils.map("n", "<C-u>", "<C-u>zz", { desc = "Jump up 1/2-screen", noremap = true })
vim.utils.map("n", "<C-d>", "<C-d>zz", { desc = "Jump down 1/2-screen", noremap = true })
vim.utils.map("n", "<PageDown>", "<C-d>", { noremap = true })
vim.utils.map("n", "<PageUp>", "<C-u>", { noremap = true })

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

-- Amplify jk
vim.utils.map("nx", "H", "5hzz")
vim.utils.map("nx", "J", "5jzz")
vim.utils.map("nx", "K", "5kzz")
vim.utils.map("nx", "L", "5lzz")

-- Delete without yanking
vim.utils.map("n", "xp", "xp")
vim.utils.map("n", "XP", "xp")
vim.utils.map("n", "x", '"_x', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
vim.utils.map("n", "X", '"_X', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
vim.utils.map("n", "cc", '"_cc', { noremap = true, silent = true, desc = "Change line (No yanking)" })

vim.utils.map("i", ";;", "<C-o>", { desc = "Normal mode single operation" })

vim.utils.map(
  "n",
  "d0",
  '"_g^d$',
  { noremap = true, silent = true, desc = "Delete line without whitespace (No yanking)" }
)

vim.utils.map(
  "n",
  "DW",
  '"_db',
  { noremap = true, silent = true, desc = "Delete words backwards [inclusive] (No yanking)" }
)

vim.utils.map(
  "n",
  "DE",
  '"_dB',
  { noremap = true, silent = true, desc = "Delete WORDS backwards [exclusive] (No yanking)" }
)

vim.utils.map(
  "n",
  "CW",
  '"_T=<Space>cw',
  { noremap = true, silent = true, desc = "Change the rhs assignment of a declaration (No yanking)" }
)

vim.utils.map("n", "<leader><leader>", "<cmd>Pick files<CR>")
