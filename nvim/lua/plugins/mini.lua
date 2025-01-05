return {
  {
    "echasnovski/mini.operators",
    version = false,
    config = function()
      require("mini.operators").setup()
    end,
  },
  {
    "echasnovski/mini.basics",
    version = false,
    config = function()
      require("mini.basics").setup()
    end,
  },
  {
    "echasnovski/mini.pick",
    version = false,
    opts = {
      mappings = {
        move_down = "<C-j>",
        move_up = "<C-k>",
      }
    },
    config = function(_, opts)
      require("mini.pick").setup(opts)
    end,
  },
}
