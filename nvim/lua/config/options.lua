local globals = {
  mapleader = " ",
  maplocalleader = "\\",
  have_nerd_font = true,
  auto_save = false,
  lazyvim_picker = "fzf",
  snacks_animate = false,
  lazyvim_cmp = "auto",
  ai_cmp = true,
  trouble_lualine = true,
  autoformat = false,
}

local options = {
  number = true,
  numberwidth = 4,
  relativenumber = true,
  mouse = "a",
  fileencoding = "utf-8",
  shiftwidth = 2,
  autoindent = false,
  cursorlineopt = "both",
  showtabline = 2,
  scrolloff = 8,
  timeoutlen = 300,
}

for option, value in pairs(globals) do
  vim.g[option] = value
end

for option, value in pairs(options) do
  vim.opt[option] = value
end
