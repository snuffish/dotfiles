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
vim.utils.map("ic", "<C-a>", "<Home>", { silent = true, noremap = true })
vim.utils.map("ic", "<C-e>", "<End>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("i", "<C-h>", "<Left>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("i", "<C-l>", "<Right>", { silent = true, noremap = true })

-- Mini.Surround mapping
local sr_key = vim.g.map_surround_leader

local surround_mappings = {
  { key = "a", desc = "Add surrounding" },
  { key = "d", desc = "Delete surrounding" },
  { key = "f", desc = "Find Right surrounding" },
  { key = "F", desc = "Find Left surrounding" },
  { key = "h", desc = "Highlight surrounding" },
  { key = "n", desc = "Update `MiniSurround.config.n_lines`" },
}

for _, mapping in ipairs(surround_mappings) do
  local key = mapping.key
  local desc = mapping.desc

  vim.api.nvim_set_keymap("", sr_key .. key, ";" .. key, { desc = desc })
end

vim.api.nvim_set_keymap("n", string.rep(sr_key, 2), ";a_", { desc = "Add row surrounding" })
vim.api.nvim_set_keymap("v", string.rep(sr_key, 2), ";a", { desc = "Add surrounding" })

-- TreeWalker mapping
local Direction = {
  UP = "Up",
  DOWN = "Down",
  RIGHT = "Right",
  LEFT = "Left",
}

local treewalker_mappikngs = {
  ["k"] = Direction.UP,
  ["j"] = Direction.DOWN,
  ["l"] = Direction.RIGHT,
  ["h"] = Direction.LEFT,
}

for _, m in ipairs({ "n", "v" }) do
  for key, direction in pairs(treewalker_mappikngs) do
    vim.api.nvim_set_keymap(
      m,
      string.format("<C-%s>", key),
      "<cmd>Treewalker " .. direction .. "<cr>zz",
      { noremap = true, silent = true }
    )
    vim.api.nvim_set_keymap(
      m,
      string.format("<M-C-%s>", key),
      "<cmd>Treewalker Swap" .. direction .. "<cr>zz",
      { noremap = true, silent = true }
    )
  end
end
