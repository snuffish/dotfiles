return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    { "borderless_full" },
    winopts = {
      fullscreen = false,
      preview = {
        default = "bat",
      },
    },
  },
  keys = {
    {
      "<leader>fz",
      "<cmd>FzfLua<CR>",
      desc = "FzfLua BuiltIn",
    },
  },
  config = function(_, opts)
    require("fzf-lua").setup(opts)
  end,
}
