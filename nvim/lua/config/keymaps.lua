require("config.globals")
require("config.remaps")

vim.api.nvim_set_keymap(
  "n",
  "<leader>yf",
  ':let @+ = expand("%:p")<CR>',
  { desc = "Yank filepath to system clipboard", noremap = true, silent = true }
)

vim.utils.map("n", "<localleader>a", function()
  local pattern = "%s %l %r"
  vim.o.statuscolumn = vim.o.statuscolumn ~= pattern and pattern or "%!v:lua.require'snacks.statuscolumn'.get()"
end, { desc = "Toggle `Absolute linenumbers`" })

vim.utils.map("n", "<leader>a", "ggVG", { desc = "Select all text", silent = true })
vim.utils.map(
  "n",
  "<M-Up><M-Up>",
  vim.utils.trigger_keys_fn(":<Up>"),
  { desc = "Previous command", noremap = true, silent = true }
)
vim.utils.map("x", { "/", "g/" }, "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection (backward)" })
vim.utils.map("x", { "?", "g?" }, "<esc>?\\%V", { silent = false, desc = "Search Inside Visual Selection (forward)" })

-- Move cursor left/right in insert-mode
vim.utils.map("ic", "<C-a>", "<Home>")
vim.utils.map("ic", "<C-d>", "<End>")

-- Regex replaces
-- vim.utils.map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })
-- vim.utils.map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })

-- Regex deletes
-- vim.utils.map("n", "DD", "<Esc>:%s//<Left>", { noremap = true, desc = "Regex delete (selection)" })
-- vim.utils.map("x", "DD", "<Esc>:'<,'>s//<Left>", { noremap = true, desc = "Regex delete (selection)" })

-- Mini.Surround mapping
vim.api.nvim_set_keymap("", ";;", ";a_", { desc = "Add row surrounding" })
vim.api.nvim_set_keymap("v", ";;", ";a", { desc = "Add surrounding" })

-- Flash.nvim mapping
local flash_line = function(forward)
  return function()
    require("flash").remote({
      search = {
        mode = "search",
        max_length = 0,
        forward = forward,
        wrap = false,
        multi_window = false,
      },
      label = {
        after = { 0, 0 },
      },
      pattern = "^",
      labels = "abcdefghijklmnopqrstuvwxyz",
    })
  end
end
-- vim.utils.map("o", "l", flash_line(false))
-- vim.utils.map("o", "L", flash_line(true))

-- Tab navigation
vim.utils.map("n", { "<Tab>l", "<Tab><Tab>" }, "<cmd>BufferLineCycleNext<CR>", { noremap = true, silent = true })
vim.utils.map(
  "n",
  { "<Tab>h", "<Tab><S-Tab>", "<S-Tab><S-Tab>" },
  "<cmd>BufferLineCyclePrev<CR>",
  { noremap = true, silent = true }
)

-- Treewalker mappings
local Direction = {
  UP = "Up",
  DOWN = "Down",
  RIGHT = "Right",
  LEFT = "Left",
}

local function treewalker(direction)
  return function()
    vim.cmd("Treewalker " .. direction)
    vim.utils.trigger_keys("zz")
  end
end

local mappings = {
  ["<C-k>"] = Direction.UP,
  ["<C-j>"] = Direction.DOWN,
  ["<C-l>"] = Direction.RIGHT,
  ["<C-h>"] = Direction.LEFT,
}

for key, direction in pairs(mappings) do
  vim.utils.map("nv", key, treewalker(direction), { noremap = true, silent = true })
end

-- Window navigation
-- vim.utils.map("n", "<C-M-h>", "<C-w>h", { noremap = true, silent = true })
-- vim.utils.map("n", "<C-M-j>", "<C-w>j", { noremap = true, silent = true })
-- vim.utils.map("n", "<C-M-l>", "<C-w>l", { noremap = true, silent = true })
-- vim.utils.map("n", "<C-M-k>", "<C-w>k", { noremap = true, silent = true })

-- Text-Object Shortcut Custom pending-states mapping
-- local symbols = { "q", "b", "t", "[", "]", "<", ">", "(", ")", "{", "}" }
-- local symbols = { "q", "[", "]", "<", ">", "(", ")" }
-- for _, s in ipairs(symbols) do
--   vim.api.nvim_set_keymap("o", "l" .. s, "il" .. s, { silent = true })
--   vim.api.nvim_set_keymap("o", "l" .. string.upper(s), "al" .. s, { silent = true })
--
--   vim.api.nvim_set_keymap("o", "n" .. s, "in" .. s, { silent = true })
--   vim.api.nvim_set_keymap("o", "n" .. string.upper(s), "an" .. s, { silent = true })
--
--   vim.api.nvim_set_keymap("o", s, "i" .. s, { silent = true })
--   -- vim.api.nvim_set_keymap("o", string.upper(s), "a" .. s, { silent = true })
-- end

-- vim.utils.map("n", "<M-i>q", function()
--   vim.utils.trigger_keys("vinq<Esc>i")
-- end, { noremap = true, silent = true })

-- local function enter_pending_mode()
--   local key = vim.fn.getchar()
--   if key == vim.fn.char2nr("q") then
--     vim.utils.trigger_keys("vinq<Esc>i")
--   end
-- end
--
-- -- Map <M-i> to enter the pending mode
-- vim.utils.map("n", "<M-i>", enter_pending_mode, { noremap = true, silent = true })
