return {
  {
    "MunifTanjim/nui.nvim",
    lazy = true,
  },
  {
    "hat0uma/csvview.nvim",
    config = function()
      require("csvview").setup({
        view = {
          display_mode = "highlight",
        },
      })
    end,
  },
  {
    "stevearc/dressing.nvim",
    opts = {
      select = {
        backend = { "telescope" },
        fzf = {
          window = {
            width = 0.5,
            height = 0.4,
          },
        },
      },
    },
  },
  { "nvim-focus/focus.nvim", version = false },
  { "nvim-lua/popup.nvim" },
  { "xiyaowong/transparent.nvim" },
  { "SmiteshP/nvim-navic", requires = "neovim/nvim-lspconfig" },
}
