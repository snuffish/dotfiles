local map = require("config.utils").map

map("nxv", ";", ":", { noremap = true })
map("nxv", ";;", ":<C-f>", { noremap = true })
map("n", { "<PageUp>", "<C-u>zz" }, "<C-u>zz", { noremap = true, desc = "Jump up 1/2-screen" })
map("n", { "<PageDown>", "<C-d>zz" }, "<C-d>zz", { noremap = true, desc = "Jump down 1/2-screen" })

map("n", "{", "{zz", { noremap = true })
map("n", "}", "}zz", { noremap = true })

map("n", "n", "nzzzv", { noremap = true, desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { noremap = true, desc = "Previous search result (centered)" })

map("n", "G", "Gzz", { noremap = true })
map("n", "GG", "Gzzo<CR>", { desc = "Goto last line and add 2 new lines" })

map("x", "$", "g_", { noremap = true })

-- Delete without yanking
map("n", "x", '"_x', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
map("n", "X", '"_X', { noremap = true, silent = true, desc = "Delete char (No yanking)" })
map("n", "cc", '"_cc', { noremap = true, silent = true, desc = "Change line (No yanking)" })
map("n", "d0", '"_g^d$', { noremap = true, silent = true, desc = "Delete line without whitespace (No yanking)" })

map("n", "DW", '"_db', { noremap = true, silent = true, desc = "Delete words backwards [inclusive] (No yanking)" })
map("n", "DE", '"_dB', { noremap = true, silent = true, desc = "Delete WORDS backwards [exclusive] (No yanking)" })
map("n", "CW", '"_T=<Space>cw', { noremap = true,silent = true, desc = "Change the rhs assignment of a declaration (No yanking)" })
