local map = require("utils").map

map("n", "<Left>", '<cmd>echo "Use h to move!!"<CR>')
map("n", "<Right>", '<cmd>echo "Use l to move!!"<CR>')
map("n", "<Up>", '<cmd>echo "Use k to move!!"<CR>')
map("n", "<Down>", '<cmd>echo "Use j to move!!"<CR>')

map("n", "<leader>w", ":w<CR>", { noremap = true, silent = true, desc = "Save file" })

map("nxv", ";", ":", { noremap = true })
map("nxv", ";;", ":<C-f>", { noremap = true })
map("tn", "qq", "<cmd>q<CR>", { noremap = true })

map("n", "{", "{zz")
map("n", "}", "}zz")

-- Scrolling
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

-- Jump in editor
map("n", { "<PageUp>", "<C-u>" }, "<C-u>zz", { desc = "Jump up 1/2-screen" })
map("n", { "<PageDown>", "<C-d>" }, "<C-d>zz", { desc = "Jump down 1/2-screen" })

-- Window-pane navigation
map("n", "G", "Gzz")
map("n", "GG", "Gzzo<CR>", { desc = "Goto last line and add 2 new lines" })

-- Delete without yanking
map("n", "x", '"_x', { silent = true, desc = "Delete char (No yanking)" })
map("n", "X", '"_X', { silent = true, desc = "Delete char (No yanking)" })
map("n", "cc", '"_cc', { silent = true, desc = "Change line (No yanking)" })
map("n", "d0", '"_g^d$', { silent = true, desc = "Delete line without whitespace (No yanking)" })

map("n", "dd", function()
  local is_empty_line = vim.api.nvim_get_current_line():match("^%s*$")
  if is_empty_line then
    return '"_dd'
  else
    return "dd"
  end
end, { noremap = true, expr = true, desc = "Don't Yank Empty Line to Clipboard" })
map("n",  'DW' , '"_db', { silent = true, desc = "Delete words backwards [inclusive] (No yanking)" })
map("n",  'DE' , '"_dB', { silent = true, desc = "Delete words backwards [exclusive] (No yanking)" })
-- Do not include white space characters when using $ in visual mode,
map("x", "$", "g_")


map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
map("n", "^", "g^")
map("n", "0", "g0")

-- Go to start or end of line easier
map("nx", "H", "g^")
map("nx", "L", "g_")

-- map("i", "<A-Right>", "g_")
-- map("i", "<A-Left>", "_")
