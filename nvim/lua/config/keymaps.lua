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
  vim.o.statuscolumn = vim.o.statuscolumn ~= pattern and pattern or ""
end, { desc = "Toggle `Absolute linenumbers`" })

vim.utils.map("n", "<leader>a", "ggVG", { desc = "Select all text", silent = true })
vim.utils.map(
  "n",
  "<A-Up><A-Up>",
  vim.utils.trigger_keys_fn(":<Up>"),
  { desc = "Previous command", noremap = true, silent = true }
)
vim.utils.map("x", { "/", "g/" }, "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection (backward)" })
vim.utils.map("x", { "?", "g?" }, "<esc>?\\%V", { silent = false, desc = "Search Inside Visual Selection (forward)" })

-- Move cursor left/right in insert-mode
vim.utils.map("i", "<A-a>", "<Home>")
vim.utils.map("i", "<A-d>", "<End>")

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
  ["<C-M-k>"] = Direction.UP,
  ["<C-M-j>"] = Direction.DOWN,
  ["<C-M-l>"] = Direction.RIGHT,
  ["<C-M-h>"] = Direction.LEFT,
}

for key, direction in pairs(mappings) do
  vim.utils.map("nv", key, treewalker(direction), { noremap = true, silent = true })
end

-- Window navigation
vim.utils.map("n", "<M-H>", "<C-w>h", { silent = true })
vim.utils.map("n", "<M-J>", "<C-w>j", { silent = true })
vim.utils.map("n", "<M-K>", "<C-w>k", { silent = true })
vim.utils.map("n", "<M-L>", "<C-w>l", { silent = true })

-- Text-Object Shortcut Custom pending-states mapping
-- local symbols = { "q", "b", "t", "[", "]", "<", ">", "(", ")", "{", "}" }
local symbols = { "q", "[", "]", "<", ">", "(", ")" }
for _, s in ipairs(symbols) do
  vim.api.nvim_set_keymap("o", "l" .. s, "il" .. s, { silent = true })
  vim.api.nvim_set_keymap("o", "l" .. string.upper(s), "al" .. s, { silent = true })

  vim.api.nvim_set_keymap("o", "n" .. s, "in" .. s, { silent = true })
  vim.api.nvim_set_keymap("o", "n" .. string.upper(s), "an" .. s, { silent = true })

  vim.api.nvim_set_keymap("o", s, "i" .. s, { silent = true })
  -- vim.api.nvim_set_keymap("o", string.upper(s), "a" .. s, { silent = true })
end
