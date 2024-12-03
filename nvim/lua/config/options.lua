vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.have_nerd_font = true

local options = {
  relativenumber = true,
  showmode = false,
  mouse = "a",
}

for option, value in pairs(options) do
  vim.opt[option] = value
end
