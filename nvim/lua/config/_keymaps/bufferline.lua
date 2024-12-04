local map = require("utils").map

map("n", "<Tab>", "<cmd>BufferLineCycleNext<cr>", { noremap = true, silent = true })
map("n", "<A-Tab>", "<cmd>BufferLineCyclePrev<cr>", { noremap = true, silent = true })
map("n", "<leader>bn", "<cmd>enew<cr>", { silent = true, desc = "Create new empty buffer" })
