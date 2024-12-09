local colors = {
  blue = "#65D1FF",
  green = "#3EFFDC",
  violet = "#FF61EF",
  yellow = "#FFDA7B",
  red = "#FF4A4A",
  fg = "#c3ccdc",
  bg = "#112638",
  inactive_bg = "#2c3043",
}

local theme = {
  normal = {
    a = { bg = colors.blue, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  insert = {
    a = { bg = colors.green, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  visual = {
    a = { bg = colors.violet, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  command = {
    a = { bg = colors.yellow, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  replace = {
    a = { bg = colors.red, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  inactive = {
    a = { bg = colors.inactive_bg, fg = colors.semilightgray, gui = "bold" },
    b = { bg = colors.inactive_bg, fg = colors.semilightgray },
    c = { bg = colors.inactive_bg, fg = colors.semilightgray },
  },
}

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    theme, colors
  },
  config = function(_, opts)
    local lualine = require("lualine")
    local lazy_status = require("lazy.status") -- to configure lazy pending updates count

    local navic = require("nvim-navic")

    require("lspconfig").clangd.setup({
      on_attach = function(client, bufnr)
        navic.attach(client, bufnr)
      end,
    })

    require("transparent").clear_prefix("lualine")
    require("transparent").clear_prefix("BufferLine")
    require("transparent").clear_prefix("NeoTree")

    -- configure lualine with modified theme
    lualine.setup(opts)
  end,
}
