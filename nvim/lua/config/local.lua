-- THESE KEYMAPS IS ONLY FOR THE CURRENT ACTIVE BUFFER

local map = require("utils").map

map("n", { "<LocalLeader>a", "<leader>a" }, "ggVG", { desc = "Select all" })
map("n", "<LocalLeader>x", ":substitutes*\\%#\\u*/\\r/e <bar> normal! ==^<cr>", { desc = "Split line", silent = true })
