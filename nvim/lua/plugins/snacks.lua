-- local zen_style = Snacks.config.style("zoom_indicator", {
--   text = "▍ zoom  󰊓  ",
--   minimal = true,
--   enter = false,
--   focusable = false,
--   height = 1,
--   row = 0,
--   col = -1,
--   backdrop = false,
-- })

-- window = {                                                                                                                               |  ---------------------------------------------------------------------------------------------------------------------------------------------
--        width = 0.85,                                                                                                                          |  ---------------------------------------------------------------------------------------------------------------------------------------------
--        backdrop = 0.95,                                                                                                                       |  ---------------------------------------------------------------------------------------------------------------------------------------------
--        height = 1,                                                                                                                            |  ---------------------------------------------------------------------------------------------------------------------------------------------
--        options = {                                                                                                                            |  ---------------------------------------------------------------------------------------------------------------------------------------------
--          signcolumn = "no",                                                                                                                   |  ---------------------------------------------------------------------------------------------------------------------------------------------
--          number = false,                                                                                                                      |  ---------------------------------------------------------------------------------------------------------------------------------------------
--          relativenumber = true,                                                                                                               |  ---------------------------------------------------------------------------------------------------------------------------------------------
--          cursorline = false,                                                                                                                  |  ---------------------------------------------------------------------------------------------------------------------------------------------
--          cursorcolumn = false,                                                                                                                |  ---------------------------------------------------------------------------------------------------------------------------------------------
--          foldcolumn = "0",                                                                                                                    |  ---------------------------------------------------------------------------------------------------------------------------------------------
--          list = true,                                                                                                                         |  ---------------------------------------------------------------------------------------------------------------------------------------------
--        },                                                                                                                                     |  ---------------------------------------------------------------------------------------------------------------------------------------------
--      }, 

return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = [[
       ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗          Z
       ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║      Z    
       ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║   z       
       ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║ z         
       ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║           
       ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝           
]],
        -- stylua: ignore
        ---@type snacks.dashboard.Item[]
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "G", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
          { icon = "󰊢 ", key = "g", desc = "LazyGit", action = ":LazyGit" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = "󱌢 ", key = "m", desc = "Mason", action = ":Mason" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
    },
    scroll = {
      enabled = false,
    },
    zen = {
      win = {
        width = 200,
      },
      style = { }
      
      -- win = {
      --   enter = true,
      --   fixbuf = false,
      --   minimal = true,
      --   focusable = true,
      --   width = 1,
      --   -- heigt = 0.85,
      --   row = 0,
      --   col = -1,
      --   backdrop = false,
      --   keys = { q = false },
      --   wo = {
      --     winhighlight = "NormalFloat:Normal",
      --   },
      -- },
    },
  },
  keys = {
    {
      "<leader>ld",
      "<cmd>lua require('snacks').dashboard.open()<CR>",
      desc = "Open Dashboard",
    },
    {
      "<localleader>g",
      "<cmd>require('snacks.toggle').indent():toggle()<CR>",
      desc = "Toggle 'Indent Guides'",
    },
    {
      "<localleader>z",
      "<cmd>lua require('snacks.toggle').zen():toggle()<CR>",
      desc = "Toggle 'Zen Mode'",
    },
    {
      "<localleader>Z",
      "<cmd>lua require('snacks.toggle').zoom():toggle()<CR>",
      desc = "Toggle 'Zoom Mode'",
    },
  },
  config = function(_, opts)
    require("snacks").setup(opts)
  end,
}
