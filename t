[1mdiff --git a/nvim/lua/config/_keymaps/brackets.lua b/nvim/lua/config/_keymaps/brackets.lua[m
[1mindex b52bceb..bb4574a 100644[m
[1m--- a/nvim/lua/config/_keymaps/brackets.lua[m
[1m+++ b/nvim/lua/config/_keymaps/brackets.lua[m
[36m@@ -1,8 +1,8 @@[m
 local map = require("../../utils").map[m
 [m
 -- Bracket-jump keymaps[m
[31m-map("nv", "Q", "<cmd>TSTextobjectGotoPreviousStart @parameter.inner<cr>zz")[m
[31m-map("nv", "q", "<cmd>TSTextobjectGotoNextEnd @parameter.inner<cr>zz")[m
[32m+[m[32m-- map("nv", "Q", "<cmd>TSTextobjectGotoPreviousStart @parameter.inner<cr>zz")[m
[32m+[m[32m-- map("nv", "q", "<cmd>TSTextobjectGotoNextEnd @parameter.inner<cr>zz")[m
 [m
 -- map("n", "<Tab-q>", "<cmd>TSTextobjectGotoPreviousStart @function.inner<cr>", { noremap = true })[m
 -- map("n", "kf", "<cmd>TSTextobjectGotoNextEnd @function<cr>", { noremap = true })[m
[1mdiff --git a/nvim/lua/config/keymaps.lua b/nvim/lua/config/keymaps.lua[m
[1mindex d43f599..a298c0b 100644[m
[1m--- a/nvim/lua/config/keymaps.lua[m
[1m+++ b/nvim/lua/config/keymaps.lua[m
[36m@@ -13,12 +13,15 @@[m [mmap("n", "<C-p>", ":")[m
 [m
 map("i", { "jk", "kj", "lk", "kl", "hj", "jh" }, "<Esc>", { noremap = true, desc = "Exit insert mode" })[m
 [m
[32m+[m[32m-- Regex replaces[m
 map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })[m
 map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })[m
 [m
[32m+[m[32m-- Regex deletes[m
 map("n", "DD", "<Esc>:g//d<Left><Left>", { noremap = true, desc = "Regex delete (global)" })[m
 map("x", "DD", "<Esc>:'<,'>g//d<Left><Left>", { noremap = true, desc = "Regex delete (selection)" })[m
 [m
[32m+[m[32m-- Scrolling[m
 map("n", "n", "nzzzv", { desc = "Next search result (centered)" })[m
 map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })[m
 [m
[36m@@ -39,6 +42,11 @@[m [mmap("n", "<S-l>", "vl", { desc = "Select character right" })[m
 [m
 map("v", "<Tab>", "=", { silent = true, desc = "Auto-indent" })[m
 [m
[32m+[m[32m-- Yanking[m
[32m+[m[32mmap("n", "yy", "_yg_", { silent = true })[m
[32m+[m[32mmap("n", "Op", "O<Esc>p", { silent = true })[m
[32m+[m[32mmap("n", "op", "o<Esc>p", { silent = true })[m
[32m+[m
 -- Delete without yanking[m
 map("n", "DW", 'vb"_d', { silent = true, desc = "Delete words backwards (No yanking)" })[m
 map("n", "x", '"_x', { silent = true, desc = "Delete char (No yanking)" })[m
[36m@@ -60,7 +68,6 @@[m [mmap("n", "dd", function()[m
 end, { noremap = true, expr = true, desc = "Don't Yank Empty Line to Clipboard" })[m
 [m
 map("n", "<Up><Up>", ":<Up>", { desc = "Goto previous command" })[m
[31m-[m
 map("n", "GG", "Gzzo<CR>", { desc = "Goto last line and add 2 new lines" })[m
 [m
 -- Window-pane navigation[m
[36m@@ -80,11 +87,7 @@[m [mmap([m
   { noremap = true, silent = false, desc = "Horizontal split (Orginal window navigate to AlternativeBuffer)" }[m
 )[m
 [m
[31m--- map("n", "<C-l>", "<C-w>l", { noremap = true, silent = false, desc = "Move to right window" })[m
[31m--- map("n", "<C-k>", "<C-w>k", { noremap = true, silent = false, desc = "Move to upper window" })[m
[31m--- map("n", "<C-j>", "<C-w>j", { noremap = true, silent = false, desc = "Move to bottom window" })[m
[31m--- map("n", "<C-h>", "<C-w>h", { noremap = true, silent = false, desc = "Move to left window" })[m
[31m-[m
[32m+[m[32m-- Tmux[m
 map("n", "<C-l>", "<cmd>TmuxNavigateLeft<CR>", { noremap = true, silent = true, desc = "Goto right Tmux Window" })[m
 map("n", "<C-k>", "<cmd>TmuxNavigateRight<CR>", { noremap = true, silent = true, desc = "Goto right Tmux Window" })[m
 map("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { noremap = true, silent = true, desc = "Goto right Tmux Window" })[m
[1mdiff --git a/nvim/lua/plugins/treesitter-nvim.lua b/nvim/lua/plugins/treesitter-nvim.lua[m
[1mindex c2648cf..70f0dbf 100644[m
[1m--- a/nvim/lua/plugins/treesitter-nvim.lua[m
[1m+++ b/nvim/lua/plugins/treesitter-nvim.lua[m
[36m@@ -1,5 +1,10 @@[m
 return {[m
   "nvim-treesitter/nvim-treesitter",[m
[32m+[m[32m  build = ":TSUpdate",[m
[32m+[m[32m  event = { "BufReadPre", "BufNewFile" },[m
[32m+[m[32m  dependencies = {[m
[32m+[m[32m    "nvim-treesitter/nvim-treesitter-textobjects"[m
[32m+[m[32m  },[m
   config = function()[m
     require("nvim-treesitter.configs").setup({[m
       sync_install = false,[m
[36m@@ -23,6 +28,7 @@[m [mreturn {[m
           -- init_selection = "<Enter>",[m
           node_incremental = "<CR>",[m
           node_decremental = "<BS>",[m
[32m+[m[32m          scope_incremental = false,[m
         },[m
       },[m
     })[m
