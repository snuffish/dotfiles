return {
  "gbprod/yanky.nvim",
  dependencies = {
    { "kkharji/sqlite.lua" },
  },
  opts = {
    ring = { storage = "sqlite" },
  },
  config = function()
    require("yanky").setup({
      highlight = {
        on_put = true,
        on_yank = true,
        timer = 500,
      },
      textobj = {
        enabled = true,
      },
      preserve_cursor_position = {
        enabled = false,
      },
    })
  end,
  keys = {
    {
      "<leader>p",
      function()
        require("telescope").extensions.yank_history.yank_history({})
      end,
      desc = "Open Yank History",
    },
    { "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yank text" },
    { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put yanked text after cursor" },
    { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put yanked text before cursor" },
    { "gp", "<Plug>(YankyGPutAfter)", mode = { "n", "x" }, desc = "Put yanked text after selection" },
    { "gP", "<Plug>(YankyGPutBefore)", mode = { "n", "x" }, desc = "Put yanked text before selection" },
    { "<c-p>", "<Plug>(YankyPreviousEntry)", desc = "Select previous entry through yank history" },
    { "<c-n>", "<Plug>(YankyNextEntry)", desc = "Select next entry through yank history" },
    { "op", "m`O<ESC><Plug>(YankyPutIndentAfterLinewise)``" },
    { "OP", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "Put indented before cursor (linewise)" },

    -- { "op", "<Plug>(YankyPutIndentAfterLinewise)", desc = "Put indented after cursor (linewise)" },
    -- { "]P", "<Plug>(YankyPutIndentAfterLinewise)", desc = "Put indented after cursor (linewise)" },
    -- { "[P", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "Put indented before cursor (linewise)" },
    -- { ">P", "<Plug>(YankyPutIndentBeforeShiftRight)", desc = "Put before and indent right" },
    -- { "<P", "<Plug>(YankyPutIndentBeforeShiftLeft)", desc = "Put before and indent left" },
    -- { ">p", "<Plug>(YankyPutIndentAfterShiftRight)", desc = "Put and indent right" },
    -- { "<p", "<Plug>(YankyPutIndentAfterShiftLeft)", desc = "Put and indent left" },
    -- { "op", "<Plug>(YankyPutAfterFilter)", desc = "Put after applying a filter" },
    -- { "OP", "<Plug>(YankyPutBeforeFilter)", desc = "Put before applying a filter" },
  },
}
