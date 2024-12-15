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

map("n", "dd", function()
  local is_empty_line = vim.api.nvim_get_current_line():match("^%s*$")
  if is_empty_line then
    return '"_dd'
  else
    return "dd"
  end
end, { expr = true, desc = "Don't Yank Empty Line to Clipboard" })

-- Delete without yanking
map("n", "x", '"_x', { silent = true, desc = "Delete char (No yanking)" })
map("n", "X", '"_X', { silent = true, desc = "Delete char (No yanking)" })
map("n", "cc", '"_cc', { silent = true, desc = "Change line (No yanking)" })
map("n", "d0", '"_g^d$', { silent = true, desc = "Delete line without whitespace (No yanking)" })

map("n", "DW", '"_db', { silent = true, desc = "Delete words backwards [inclusive] (No yanking)" })
map("n", "DE", '"_dB', { silent = true, desc = "Delete WORDS backwards [exclusive] (No yanking)" })
map("n", "CW", '"_T=<Space>cw', { silent = true, desc = "Change the rhs assignment of a declaration (No yanking)" })

-- Do not include white space characters when using $ in visual mode,
map("x", "$", "g_")

map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
map("n", "^", "g^")
map("n", "0", "g0")

-- Go to start or end of line easier
map("nx", "H", "g^")
map("nx", "L", "g_")

map("vx", "<S-Space>", "l")
map("vx", "<BS>", "h")

map(
  "n",
  "<C-w>v",
  "<C-w>v<C-w>p<cmd>e #<CR><C-w>p",
  { noremap = true, silent = false, desc = "Vertical split (Orginal window navigate to AlternativeBuffer)" }
)

map(
  "n",
  "<C-w>s",
  "<C-w>s<C-w>p<cmd>e #<CR><C-w>p",
  { noremap = true, silent = false, desc = "Horizontal split (Orginal window navigate to AlternativeBuffer)" }
)

vim.api.nvim_set_keymap("", "<leader>sr", "<cmd>FzfLua resume<CR>", { desc = "Resume search", noremap = true, silent = true })
vim.api.nvim_set_keymap("", "<leader>sR", "<cmd>GrugFar<CR>", { desc = "Ripgrep search", noremap = true, silent = true })

vim.api.nvim_set_keymap("", "<leader>qd", "<cmd>lua Snacks.dashboard()", { desc = "Goto Dashboard", noremap = true, silent = true })
require('which-key').add({
  ["<leader>qd"] = { "<cmd>lua Snacks.dashboard()<CR>", "Open Snacks Dashboard" }
})

-- require('utils').add_which_key({
--   "<leader>qd", "<cmd>lua Snacks.dashboard()"
-- })

-- local show_leader_keys = function()
--   require("which-key").show({
--     keys = "<leader>",
--   })
-- end
--
-- map("nxo", " ", show_leader_keys)
-- map("nxo", "<leader>", show_leader_keys)
