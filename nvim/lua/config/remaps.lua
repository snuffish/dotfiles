local map = require("config.utils").map

map("nxv", ";", ":", { noremap = true })
map("nxv", ";;", ":<C-f>", { noremap = true })
map("n", { "<PageUp>", "<C-u>zz" }, "<C-u>zz", { desc = "Jump up 1/2-screen" })
map("n", { "<PageDown>", "<C-d>zz" }, "<C-d>zz", { desc = "Jump down 1/2-screen" })

map("n", "{", "{zz")
map("n", "}", "}zz")

map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

map("n", "G", "Gzz")
map("n", "GG", "Gzzo<CR>", { desc = "Goto last line and add 2 new lines" })

map("x", "$", "g_")

-- Delete without yanking
map("n", "x", '"_x', { silent = true, desc = "Delete char (No yanking)" })
map("n", "X", '"_X', { silent = true, desc = "Delete char (No yanking)" })
map("n", "cc", '"_cc', { silent = true, desc = "Change line (No yanking)" })
map("n", "d0", '"_g^d$', { silent = true, desc = "Delete line without whitespace (No yanking)" })

map("n", "DW", '"_db', { silent = true, desc = "Delete words backwards [inclusive] (No yanking)" })
map("n", "DE", '"_dB', { silent = true, desc = "Delete WORDS backwards [exclusive] (No yanking)" })
map("n", "CW", '"_T=<Space>cw', { silent = true, desc = "Change the rhs assignment of a declaration (No yanking)" })
