return {
  "folke/snacks.nvim",
  opts = {
    scroll = {
      enabled = false,
    },
    zen = {
      win = {
        width = 0.8,
        backdrop = { transparent = false, blend = 95 },
        wo = { winhighlight = "NormalFloat:Normal" },
      },
      on_open = function(win)
        require("snacks.indent").disable()
        vim.cmd("normal! zM")
        _G.ZenMode = { enabled = true }
      end,
      on_close = function(win)
        require("snacks.indent").enable()
        _G.ZenMode = { enabled = false }
      end,
    },
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
          { icon = " ", key = "h", desc = "Checkhealth", action = ":checkhealth" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
    },
  },
  keys = {
    {
      "<localleader>g",
      function()
        require("snacks.toggle").indent():toggle()
      end,
      desc = "Toggle 'Indent Guides'",
    },
    {
      "<localleader>z",
      function()
        require("snacks.toggle").zen():toggle()
      end,
      desc = "Toggle 'Zen Mode'",
    },
    {
      "<localleader>Z",
      function()
        require("snacks.toggle").zoom():toggle()
      end,
      desc = "Toggle 'Zoom Mode'",
    },
  },
  config = function(_, opts)
    require("snacks").setup(opts)
  end,
}
