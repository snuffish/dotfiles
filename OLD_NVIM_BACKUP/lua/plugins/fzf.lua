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
      "<leader>fb",
      "<cmd>FzfLua<CR>",
      desc = "FzfLua BuiltIn",
    },
  },
  config = function(_, opts)
    require("fzf-lua").setup(opts)

    require("utils").add_which_key({
      "<leader>fz",
      icon = { icon = " ", color = "blue" },
    })
  end,
}
