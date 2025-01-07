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
        move_down = "<M-j>",
        move_up = "<M-k>",
      },
    },
    config = function(_, opts)
      require("mini.pick").setup(opts)
    end,
  },
  {
    "echasnovski/mini.clue",
    version = false,
    config = function()
      local miniclue = require("mini.clue")


      miniclue.setup({
        window = {
          delay = 0,
          config = {
            anchor = "SW",
            row = "auto",
            col = "auto",
            border = "double",
          },
        },
        -- triggers = {
        --   { mode = "n", keys = "<M-i>" },
        -- },
        -- clues = {
        --   { mode = "n", keys = "<M-i>q", desc = "Quote" },
        -- },
        -- triggers = {
        --   { mode = "n", keys = "<C-W>" },
        --   { mode = "i", keys = "<C-x>" },
        -- },
        --
        -- clues = {
        --   { mode = "i", keys = "<C-x><C-f>", desc = "File names" },
        --   { mode = "i", keys = "<C-x><C-l>", desc = "Whole lines" },
        --   { mode = "i", keys = "<C-x><C-o>", desc = "Omni completion" },
        --   { mode = "i", keys = "<C-x><C-s>", desc = "Spelling suggestions" },
        --   { mode = "i", keys = "<C-x><C-u>", desc = "With 'completefunc'" },
        -- },
      })

      -- require("mini.clue").setup({
      --   triggers = {
      --     { mode = "n", keys = "<leader>ö" },
      --   },
      --   clues = {
      --     { mode = "n", keys = "<leader>öä", desc = "Test clue" },
      --   },
      -- })
    end,
  },
}
