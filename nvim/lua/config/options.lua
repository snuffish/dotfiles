local globals = {
  mapleader = " ",
  maplocalleader = " ",
  have_nerd_font = true,
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

  -- TODO: Fix a Lua-script to handle the vertical cursor-column later
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
