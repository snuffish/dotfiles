-- vim.api.nvim_del_keymap("",'<leader>l')
-- require("which-key").add({
--   { "<leader>ll", "<cmd>Lazy<CR>", desc = "Open Lazy"}
-- })

-- vim.utils.map("i", "<ESC>", "<nop>")

-- Remap q to Q to prevent accidently pressing the recording key
vim.utils.map("n", "q", "<nop>", { noremap = true, silent = true })
vim.utils.map("n", "Q", "q", { noremap = true, silent = true })

vim.utils.map("n", vim.g.capslock_key, "i", { noremap = true, silent = true, desc = "Enter insert mode" })
vim.utils.map("i", vim.g.capslock_key, "<Esc>", { noremap = true, silent = true, desc = "Exit insert mode" })

vim.utils.map("nvx", "m", "%")

vim.utils.map("n", { "<PageUp>", "<C-u>zz" }, "<C-u>zz", { desc = "Jump up 1/2-screen" })
vim.utils.map("n", { "<PageDown>", "<C-d>zz" }, "<C-d>zz", { desc = "Jump down 1/2-screen" })

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

-- Amplify jk
vim.utils.map("nx", "J", "5jzz")
vim.utils.map("nx", "K", "5kzz")

-- Go to start or end of line easier
vim.utils.map("nx", "H", "g^")
vim.utils.map("nx", "L", "g_")

-- Delete without yanking
vim.utils.map("n", "x", '"_x', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
vim.utils.map("n", "X", '"_X', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
vim.utils.map("n", "cc", '"_cc', { noremap = true, silent = true, desc = "Change line (No yanking)" })
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

vim.keymap.del({ "n", "s" }, ">")
-- vim.utils.map("nx", ">", "]")
vim.api.nvim_set_keymap("n", ">", "]", { noremap = false })

vim.keymap.del({ "n", "s" }, "<")
vim.api.nvim_set_keymap("n", "<", "[", { noremap = false })
-- vim.utils.map("nx", "<", "[")
