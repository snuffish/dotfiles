require("config.remaps")
require("config.dap")

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
vim.utils.map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })
vim.utils.map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })

-- Regex deletes
vim.utils.map("n", "DD", "<Esc>:%s//<Left>", { noremap = true, desc = "Regex delete (selection)" })
vim.utils.map("x", "DD", "<Esc>:'<,'>s//<Left>", { noremap = true, desc = "Regex delete (selection)" })

-- Mini.Surround mapping
vim.api.nvim_set_keymap("", ";;", ";a_", { desc = "Add row surrounding" })

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
vim.utils.map("o", "l", flash_line(false))
vim.utils.map("o", "L", flash_line(true))

-- Navigation
vim.utils.map("i", { "<Tab>", "<S-Tab>" }, "<Esc>l", { silent = true, desc = "Exit insert mode" })
vim.utils.map("nx", "<Tab>", "<cmd>TSTextobjectGotoNextEnd @parameter.inner<CR>", { silent = true })
vim.utils.map("nx", "<S-Tab>", "<cmd>TSTextobjectGotoPreviousStart @parameter.inner<CR>", { silent = true })

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
vim.utils.map("n", "<C-M-H>", "<C-w>h", { silent = true })
vim.utils.map("n", "<C-M-J>", "<C-w>j", { silent = true })
vim.utils.map("n", "<C-M-K>", "<C-w>k", { silent = true })
vim.utils.map("n", "<C-M-L>", "<C-w>l", { silent = true })

-- Tab navigation
vim.utils.map("n", "<Tab>l", "<cmd>BufferLineCycleNext<CR>", { noremap = true, silent = true })
vim.utils.map("n", "<Tab>h", "<cmd>BufferLineCyclePrev<CR>", { noremap = true, silent = true })

-- vim.utils.map("n", "<C-n>", function()
--   require("flash").jump({
--      pattern = vim.fn.expand("<cword>")
--   })
-- end)
