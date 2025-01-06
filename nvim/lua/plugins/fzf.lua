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
      on_create = function()
        vim.keymap.set("t", "<M-j>", "<Down>", { silent = true, buffer = true })
        vim.keymap.set("t", "<M-k>", "<Up>", { silent = true, buffer = true })
      end,
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
