-- require("config._keymaps.brackets")
require("config._keymaps.bufferline")
require("config._keymaps.amend")

local map = require("utils").map

map("n", "<Left>", '<cmd>echo "Use h to move!!"<CR>')
map("n", "<Right>", '<cmd>echo "Use l to move!!"<CR>')
map("n", "<Up>", '<cmd>echo "Use k to move!!"<CR>')
map("n", "<Down>", '<cmd>echo "Use j to move!!"<CR>')

map("n", "<C-p>", ":")

map("i", { "jk", "kj", "lk", "kl", "hj", "jh" }, "<Esc>", { noremap = true, desc = "Exit insert mode" })

-- Regex replaces
map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })
map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })

-- Regex deletes
map("n", "DD", "<Esc>:g//d<Left><Left>", { noremap = true, desc = "Regex delete (global)" })
map("x", "DD", "<Esc>:'<,'>g//d<Left><Left>", { noremap = true, desc = "Regex delete (selection)" })

-- Scrolling
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

map("n", "+", "<C-a>", { silent = true, desc = "Increment integer" })
map("n", "-", "<C-x>", { silent = true, desc = "Decrement integer" })

map("n", "<leader>a", "ggVG", { desc = "Select all" })

-- Jump in editor
map("n", { "<PageUp>", "<C-u>" }, "<C-u>zz", { desc = "Jump up 1/2-screen" })
map("n", { "<PageDown>", "<C-d>" }, "<C-d>zz", { desc = "Jump down 1/2-screen" })

-- Visual mode selections with Shift + Arrow keys
map("n", "<S-k>", "Vk", { desc = "Select line above" })
map("n", "<S-j>", "Vj", { desc = "Select line below" })
map("n", "<S-h>", "vh", { desc = "Select character left" })
map("n", "<S-l>", "vl", { desc = "Select character right" })

map("n", "{", "{zz")
map("n", "}", "}zz")

map("v", "<Tab>", "=", { silent = true, desc = "Auto-indent" })

-- Yanking
map("n", "yy", "_yg_", { silent = true })
map("n", "Op", "O<Esc>p", { silent = true })
map("n", "op", "o<Esc>p", { silent = true })

-- Delete without yanking
map("n", "DW", 'vb"_d', { silent = true, desc = "Delete words backwards (No yanking)" })
map("n", "x", '"_x', { silent = true, desc = "Delete char (No yanking)" })
map("n", "X", '"_X', { silent = true, desc = "Delete char (No yanking)" })

map("n", "<F1>", "<cmd>TransparentToggle<cr>", { noremap = true, silent = true })

map("n", "<leader>cb", "<cmd>Navbuddy<cr>", { noremap = true, silent = true })

map("x", "g/", "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection" })

map("n", "dd", function()
  local is_empty_line = vim.api.nvim_get_current_line():match("^%s*$")
  if is_empty_line then
    return '"_dd'
  else
    return "dd"
  end
end, { noremap = true, expr = true, desc = "Don't Yank Empty Line to Clipboard" })

map("n", "<Up><Up>", ":<Up>", { desc = "Goto previous command" })
map("n", "GG", "Gzzo<CR>", { desc = "Goto last line and add 2 new lines" })

-- Window-pane navigation
map("n", "G", "Gzz")

map(
  "n",
  "<leader>wv",
  "<C-w>v<C-w>p<cmd>e #<CR><C-w>p",
  { noremap = true, silent = false, desc = "Vertical split (Orginal window navigate to AlternativeBuffer)" }
)

map(
  "n",
  "<leader>ws",
  "<C-w>s<C-w>p<cmd>e #<CR><C-w>p",
  { noremap = true, silent = false, desc = "Horizontal split (Orginal window navigate to AlternativeBuffer)" }
)

-- Tmux
map("n", "<C-l>", "<cmd>TmuxNavigateLeft<CR>", { noremap = true, silent = true, desc = "Goto right Tmux Window" })
map("n", "<C-k>", "<cmd>TmuxNavigateRight<CR>", { noremap = true, silent = true, desc = "Goto right Tmux Window" })
map("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { noremap = true, silent = true, desc = "Goto right Tmux Window" })
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { noremap = true, silent = true, desc = "Goto right Tmux Window" })

-- bookmarks
map({ "n", "v" }, "<leader>mm", "<cmd>BookmarksMark<cr>", { desc = "Mark current line into active BookmarkList." })
map({ "n", "v" }, "<leader>mo", "<cmd>BookmarksGoto<cr>", { desc = "Go to bookmark at current active BookmarkList" })
map({ "n", "v" }, "<leader>ma", "<cmd>BookmarksCommands<cr>", { desc = "Find and trigger a bookmark command." })
map({ "n", "v" }, "<leader>mg", "<cmd>BookmarksGotoRecent<cr>", { desc = "Go to latest visited/created Bookmark" })
