return {
  "nvim-treesitter/nvim-treesitter",
  config = function()
    require("nvim-treesitter.configs").setup({
      sync_install = false,
      ensure_installed = {
        "html",
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          -- init_selection = "<Enter>",
          node_incremental = "<CR>",
          node_decremental = "<BS>",
        },
      },
    })
  end,
}
