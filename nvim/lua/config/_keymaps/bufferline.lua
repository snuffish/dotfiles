local set = require("utils").set

set("n", "<Tab>", "<cmd>BufferLineCycleNext<cr>", { noremap = true, silent = true })
set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", { noremap = true, silent = true })
set("n", "<leader>bq", "<cmd>BufferLineCloseOthers<cr>", { silent = true, desc = "Close all other buffers" })
set("n", "<leader>bn", "<cmd>enew<cr>", { silent = true, desc = "Create new empty buffer" })
