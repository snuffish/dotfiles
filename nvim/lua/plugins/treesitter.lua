return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  opts = {
    sync_install = false,
    ensure_installed = {
      "html",
      "javascript",
      "typescript",
      "tsx",
      "json",
      "css",
      "prisma",
      "bash",
      "lua",
      "vim",
      "markdown",
      "markdown_inline",
      "regex",
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "vv",
        node_incremental = "<CR>",
        node_decremental = "<BS>",
        scope_incremental = false
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  }
}
