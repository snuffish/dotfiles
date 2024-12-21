return {
  { "tpope/vim-repeat", event = "VeryLazy" },
  -- {
  --   "ggandor/flit.nvim",
  --   enabled = true,
  --   keys = function()
  --     local ret = {}
  --     for _, key in ipairs({ "f", "F", "t", "T" }) do
  --       table.insert(ret, { key, mode = { "n", "x", "o" } })
  --     end
  --     return ret
  --   end,
  --   opts = { labeled_modes = "n" },
  --   config = function()
  --     require("flit").setup({
  --       keys = { f = "f", F = "F", t = "t", T = "T" },
  --       labeled_modes = "v",
  --       clever_repeat = true,
  --       multiline = true,
  --     })
  --   end,
  -- },
  {
    "folke/flash.nvim",
    enabled = true,
    event = "VeryLazy",
    opts = {},
    keys = {
      {
        "S",
        mode = { "n", "o", "x" },
        false,
      },
      {
        "s",
        mode = { "n", "o", "x" },
        false,
      },
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump({
            search = {
              mode = "fuzzy",
              forward = true,
              wrap = false,
              multi_window = false,
            },
          })
        end,
        desc = "Flash Jump",
      },
      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump({
            search = {
              mode = "fuzzy",
              forward = false,
              wrap = false,
              multi_window = false,
            },
          })
        end,
        desc = "Flash Jump",
      },
      {
        "<leader>fs",
        mode = { "n", "x", "o" },
        function()
          require("flash").toggle()
        end,
        desc = "Toggle Flash Search",
      },
      {
        "<localleader>ft",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },
      {
        "r",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
      {
        "l",
        mode = "o",
        function()
          require("flash").remote({
            search = { mode = "search", max_length = 0 },
            label = {
              after = { 0, 0 },
            },
            pattern = "^",
          })
        end,
        desc = "Remote Flash line",
      },
      {
        "R",
        mode = { "o", "x" },
        function()
          require("flash").treesitter_search()
        end,
        desc = "Treesitter Search",
      },
      {
        "<c-s>",
        mode = { "c" },
        function()
          require("flash").toggle()
        end,
        desc = "Toggle Flash Search",
      },
    },
  },
}
