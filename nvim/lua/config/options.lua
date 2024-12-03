vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.have_nerd_font = true

local options = {
  relativenumber = true,
  showmode = false,
  mouse = "a",
  fileencoding = "utf-8",
  shiftwidth = 2,
  tabstop = 2,
  autoindent = false,
  smartindent = true,
  cursorlineopt = "both",

  -- TODO: Fix a Lua-script to handle the vertical cursor-column later
  cursorcolumn = false,
}

for option, value in pairs(options) do
  vim.opt[option] = value
end
