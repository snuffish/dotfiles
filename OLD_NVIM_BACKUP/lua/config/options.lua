local globals = {
  mapleader = " ",
  maplocalleader = "\\",
  have_nerd_font = true,
  loaded_perl_provider = 0,
  loaded_python3_provider = 0,
  loaded_ruby_provider = 0,
  autoformat = false,
  lazyvim_picker = "fzf",
}

local options = {
  number = true,
  numberwidth = 4,
  relativenumber = true,
  showmode = false,
  mouse = "a",
  fileencoding = "utf-8",
  shiftwidth = 2,
  tabstop = 2,
  autoindent = false,
  smartindent = true,
  cursorlineopt = "both",
  showtabline = 2,
  scrolloff = 8,
  cursorcolumn = false,
}

-- Global properties
for option, value in pairs(globals) do
  vim.g[option] = value
end

-- Option properties
for option, value in pairs(options) do
  vim.opt[option] = value
end
