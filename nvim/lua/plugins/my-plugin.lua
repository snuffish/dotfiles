return {
  "plugin-search.nvim",
  dir = "~/.config/nvim/custom-plugins/search-plugins",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "stevearc/oil.nvim"
  },
  keys = {
    {
      "<leader>lp",
      "<cmd>SearchPlugin<CR>",
      desc = "Search Plugins"
    }
  }
  -- dev = true
}
