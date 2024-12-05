return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects"
  },
  config = function()
    require("nvim-treesitter.configs").setup({
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
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          -- init_selection = "<Enter>",
          node_incremental = "<CR>",
          node_decremental = "<BS>",
          scope_incremental = false,
        },
      },
    })
  end,
}
