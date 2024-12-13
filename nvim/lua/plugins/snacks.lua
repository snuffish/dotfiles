return {
  {
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
          style = "zen",
        },
      },
    },
    keys = {
      {
        "<leader>lq",
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
        desc = "Toggle Zen Mode",
      },
      {
        "<localleader>Z",
        "<cmd>lua require('snacks.toggle').zoom():toggle()<CR>",
        desc = "Toggle Zoom Mode",
      },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
    end,
  },
}
