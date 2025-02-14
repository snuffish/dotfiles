return {
  "folke/snacks.nvim",
  opts = {
    ---@type snacks.zen
    zen = {
      win = {
        width = 0.8,
        backdrop = { transparent = false, blend = 95 },
        wo = { winhighlight = "NormalFloat:Normal" },
      },
      on_open = function(win)
        require("snacks.indent").disable()
        _G.ZenMode = { enabled = true }
      end,
      on_close = function(win)
        require("snacks.indent").enable()
        _G.ZenMode = { enabled = false }
      end,
    },
  },
  keys = {
    {
      "<localleader>z",
      "<cmd>lua Snacks.zen.zen()<CR>",
      desc = "Toggle 'Zen Mode'",
    },
    {
      "<localleader>Z",
      "<cmd>lua Snacks.zen.zoom()<CR>",
      desc = "Toggle 'Zoom Mode'",
    },
  },
}
