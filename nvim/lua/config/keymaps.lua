require("config._keymaps.brackets")
require("config._keymaps.bufferline")
require("config._keymaps.amend")

local set = require("utils").set

set("n", "<Left>", '<cmd>echo "Use h to move!!"<CR>')
set("n", "<Right>", '<cmd>echo "Use l to move!!"<CR>')
set("n", "<Up>", '<cmd>echo "Use k to move!!"<CR>')
set("n", "<Down>", '<cmd>echo "Use j to move!!"<CR>')

set("i", { "jk", "kj" }, "<Esc>", { noremap = true, desc = "Exit insert mode" })

-- set("n", "<A-j>", "}zz", { noremap = true, silent = true })
-- set("n", "<A-k>", "{zz", { noremap = true, silent = true })

set("nv", "<C-p>", ":", { noremap = true, desc = "Enter command mode" })
set("i", "<C-p>", "<Esc>:", { noremap = true, desc = "Enter command mode" })

set("n", "R", "<Esc>:%s/", { noremap = true, desc = "Regex string replace" })

set("n", "n", "nzzzv", { desc = "Next search result (centered)" })
set("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

set("n", "+", "<C-a>", { silent = true, desc = "Increment integer" })
set("n", "-", "<C-x>", { silent = true, desc = "Decrement integer" })

set("n", "<leader>a", "ggVG", { desc = "Select all" })

-- Jump in editor
set("n", { "<PageUp>", "<C-u>" }, "<C-u>zz", { desc = "Jump up 1/2-screen" })
set("n", { "<PageDown>", "<C-d>" }, "<C-d>zz", { desc = "Jump down 1/2-screen" })

-- Visual mode selections with Shift + Arrow keys
set("n", "<S-k>", "Vk", { desc = "Select line above" })
set("n", "<S-j>", "Vj", { desc = "Select line below" })
set("n", "<S-h>", "vh", { desc = "Select character left" })
set("n", "<S-l>", "vl", { desc = "Select character right" })

set("v", "<Tab>", "=", { silent = true, desc = "Auto-indent" })

-- Delete without yanking
set("n", "DW", 'vb"_d', { silent = true, desc = "Delete words backwards (No yanking)" })
set("n", "x", '"_x', { silent = true, desc = "Delete char (No yanking)" })
set("n", "X", '"_X', { silent = true, desc = "Delete char (No yanking)" })

set("n", "<C-j>", "}", { noremap = true, silent = true })
set("n", "<C-k>", "{", { noremap = true, silent = true })

set("n", "<F1>", "<cmd>TransparentToggle<cr>", { noremap = true, silent = true })

set("n", "<leader>cb", "<cmd>Navbuddy<cr>", { noremap = true, silent = true })
