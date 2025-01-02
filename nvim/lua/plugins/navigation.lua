return {
  {
    "yamatsum/nvim-cursorline",
    config = function()
      require("nvim-cursorline").setup({
        cursorline = {
          enable = true,
          timeout = 1000,
          number = false,
        },
        cursorword = {
          enable = true,
          min_length = 1,
          hl = { underline = true },
        },
      })
    end,
  },
  {
    "aaronik/treewalker.nvim",
    opts = {
      highlight = true, -- Whether to briefly highlight the node after jumping to it
      highlight_duration = 250, -- How long should above highlight last (in ms)
    },
  },
  {
    "echasnovski/mini.cursorword",
    version = false,
    config = function()
      require("mini.cursorword").setup()
    end,
  },
  {
    "echasnovski/mini.jump2d",
    version = false,
    opts = {
      mappings = {
        start_jumping = "<CR>"
      },
    },
    config = function(_, opts)
      require("mini.jump2d").setup(opts)
    end,
  },
}
