return {
  {
    "snuffish/utils.nvim",
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
        "<leader>sP",
        "<cmd>SearchPlugin<CR>",
        desc = "Search Plugins",
      },
    },
  },
}
