local map = require("config.utils").map

map("nxv", ";", ":", { noremap = true })
map("nxv", ";;", ":<C-f>", { noremap = true })
map("n", { "<PageUp>", "<C-u>zz" }, "<C-u>zz", { desc = "Jump up 1/2-screen" })
map("n", { "<PageDown>", "<C-d>zz" }, "<C-d>zz", { desc = "Jump down 1/2-screen" })

map("n", "{", "{zz")
map("n", "}", "}zz")

map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })
