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
      { "S", false, mode = { "n", "o", "x" } },
      { "s", false, mode = { "n", "o", "x" } },
      {
        "gfs",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump({
            search = {
              mode = "fuzzy",
              forward = true,
              wrap = false,
              multi_window = false,
            },
            labels = "abcdefghijklmnopqrstuvwxyz",
          })
        end,
        desc = "Flash Jump",
      },
      {
        "gfS",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump({
            search = {
              mode = "fuzzy",
              forward = false,
              wrap = false,
              multi_window = false,
            },
            labels = "abcdefghijklmnopqrstuvwxyz",
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
          require("flash").treesitter({
            search = { mode = "search", max_length = 0 },
            label = {
              after = { 0, 0 },
            },
            pattern = "^",
          })
        end,
        desc = "Flash Treesitter",
      },
      {
        "gfr",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
      {
        "gfl",
        mode = "o",
        function()
          require("flash").remote({
            search = {
              mode = "search",
              max_length = 0,
              forward = true,
              wrap = false,
              multi_window = false,
            },
            label = {
              after = { 0, 0 },
            },
            pattern = "^",
            labels = "abcdefghijklmnopqrstuvwxyz",
          })
        end,
        desc = "Remote Flash line",
      },
      {
        "gfL",
        mode = "o",
        function()
          require("flash").remote({
            search = {
              mode = "search",
              max_length = 0,
              forward = false,
              wrap = false,
              multi_window = false,
            },
            label = {
              after = { 0, 0 },
            },
            pattern = "^",
            labels = "abcdefghijklmnopqrstuvwxyz",
          })
        end,
        desc = "Remote Flash line",
      },
      {
        "gft",
        mode = { "o", "x" },
        function()
          require("flash").treesitter_search({
            search = {
              mode = "fuzzy",
              -- max_length = 0,
              -- forward = false,
              wrap = false,
              multi_window = false,
            },
            labels = "abcdefghijklmnopqrstuvwxyz",
          })
        end,
        desc = "Treesitter Search",
      },
    },
  },
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
  -- {
  --   "roobert/tabtree.nvim",
  --   config = function()
  --     require("tabtree").setup()
  --   end,
  -- },
}
