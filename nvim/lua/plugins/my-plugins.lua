return {
  {
    "snuffish/utils.nvim",
    dir = "~/.config/nvim/custom-plugins/utils",
  },
  {
    "snuffish/plugin-search.nvim",
    event = "VeryLazy",
    dir = "~/.config/nvim/custom-plugins/search-plugins",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/oil.nvim",
    },
    keys = {
      {
        "<leader>lp",
        "<cmd>SearchPlugin<CR>",
        desc = "Search Plugins",
      },
    },
  },
}
