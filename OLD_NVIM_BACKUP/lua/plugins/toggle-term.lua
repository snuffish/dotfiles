return {
  "akinsho/toggleterm.nvim",
  version = "*",
  opts = {},
  config = function(_, opts)
    require("toggleterm").setup(opts)
  end,
}
