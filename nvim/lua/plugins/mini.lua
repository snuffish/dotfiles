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
    lazy = false,
    opts = {
      mappings = {
        move_down = "<C-j>",
        move_up = "<C-k>",
        choose = "<CR>",
        toggle_preview = "<C-p>",
        toggle_info = "<Tab>",
      },
    },
    keys = {
      { "<leader><leader>f", "<cmd>Pick files<CR>" },
    },
    config = function(_, opts)
      require("mini.pick").setup(opts)
    end,
  },
  -- {
  --   "echasnovski/mini.bracketed",
  --   version = false,
  --   config = function()
  --     require("mini.bracketed").setup()
  --   end,
  -- },
  {
    "echasnovski/mini.splitjoin",
    version = false,
    config = function()
      require("mini.splitjoin").setup()
    end
  },
}
