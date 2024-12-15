return {
  "ThePrimeagen/refactoring.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  lazy = false,
  keys = function()
    return {
      {
        "<leader>rr",
        function() require('telescope').extensions.refactoring.refactors() end,
        desc = "Refactor",
        mode = { "n", "v" }
      },
      {
        "<leader>rc",
        function() require('refactoring').debug.cleanup({}) end,
        desc = "[Log] Cleanup"
      },
      {
        "<leader>rv",
        function() require('refactoring').debug.print_var() end,
        desc = "[Log] Print"
      },
      {
        "<leader>rp",
        function() require('refactoring').debug.printf({below = false}) end,
        desc = "[Log] Printf"
      }
    }
  end,
  config = function()
    require("telescope").load_extension("refactoring")
    require("refactoring").setup({})

    require('utils').add_which_key({
      "<leader>r",
      icon = { icon = " ", color = "grey" },
      desc = "Refactor",
    })
  end
}
