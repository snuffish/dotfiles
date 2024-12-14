return {
  "m4xshen/hardtime.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    cmdheight = 2,
    disabled_keys = {
      ["<Up>"] = {},
      ["<Space>"] = { "n", "x" },
    },
  },
  config = function()
    require("hardtime").setup()
  end,
}
