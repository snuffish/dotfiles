local map = require("config.utils").map

vim.api.nvim_del_keymap("",'<leader>l')
require("which-key").add({
  { "<leader>ll", "<cmd>Lazy<CR>", desc = "Open Lazy"}
})

map("n", { "<PageUp>", "<C-u>zz" }, "<C-u>zz", { desc = "Jump up 1/2-screen" })
map("n", { "<PageDown>", "<C-d>zz" }, "<C-d>zz", { desc = "Jump down 1/2-screen" })

map("n", "{", "{zz")
map("n", "}", "}zz")

map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

map("n", "G", "Gzz")
map("n", "GG", "Gzzo<CR>", { desc = "Goto last line and add 2 new lines" })

-- Do not include white space characters when using $ in visual mode,
map("x", "$", "g_")

map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
map("n", "^", "g^")
map("n", "0", "g0")

-- Go to start or end of line easier
map("nx", "H", "g^")
map("nx", "L", "g_")

-- Delete without yanking
map("n", "x", '"_x', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
map("n", "X", '"_X', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
map("n", "cc", '"_cc', { noremap = true, silent = true, desc = "Change line (No yanking)" })
map("n", "d0", '"_g^d$', { noremap = true, silent = true, desc = "Delete line without whitespace (No yanking)" })

map("n", "DW", '"_db', { noremap = true, silent = true, desc = "Delete words backwards [inclusive] (No yanking)" })
map("n", "DE", '"_dB', { noremap = true, silent = true, desc = "Delete WORDS backwards [exclusive] (No yanking)" })
map("n", "CW", '"_T=<Space>cw', { noremap = true, silent = true, desc = "Change the rhs assignment of a declaration (No yanking)" })
