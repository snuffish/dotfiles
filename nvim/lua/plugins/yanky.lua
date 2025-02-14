return {
  "gbprod/yanky.nvim",
  event = "VeryLazy",
  dependencies = {
    { "kkharji/sqlite.lua" },
  },
  opts = {
    ring = { storage = "sqlite" },
    highlight = {
      on_put = true,
      on_yank = true,
      timer = 500,
    },
    textobj = {
      enabled = true,
    },
    preserve_cursor_position = {
      enabled = true,
    },
  },
  keys = {
    { "<leader>p", "<cmd>YankyRingHistory<CR>", desc = "Open Yank History" },
    { "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yank text" },
    { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put yanked text after cursor" },
    { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put yanked text before cursor" },
    { "gp", "<Plug>(YankyPutAfterFilter)", mode = { "n", "x" }, desc = "Put yanked text on line above" },
    { "gP", "<Plug>(YankyPutBeforeFilter)", mode = { "n", "x" }, desc = "Put yanked text on line below" },
    { "<c-p>", "<Plug>(YankyPreviousEntry)", desc = "Select previous entry through yank history" },
    { "<c-n>", "<Plug>(YankyNextEntry)", desc = "Select next entry through yank history" },
    -- {
    --   "<leader>p",
    --   function()
    --     require("telescope").extensions.yank_history.yank_history()
    --   end,
    --   {},
    -- },
  },
}
