return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    dashboard = {
      preset = {
        header = [[
 ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗
 ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║
 ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║
 ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║
 ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║
 ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝
]],

        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "G", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          {
            icon = " ",
            key = "c",
            desc = "Config",
            action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
          },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = " ", key = "p", desc = "Projects", action = ":lua Snacks.picker.projects()" },
          { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
          { icon = "󰊢 ", key = "g", desc = "LazyGit", action = ":LazyGit" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = "󱌢 ", key = "m", desc = "Mason", action = ":Mason" },
          { icon = " ", key = "h", desc = "Checkhealth (which-key)", action = ":checkhealth which-key" },
          { icon = " ", key = "H", desc = "Checkhealth", action = ":checkhealth" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        {
          section = "header",
          pane = 1,
        },
        -- {
        --   section = "terminal",
        --   cmd = "chafa ~/.config/nvim/avatar.png --format ansi --size 71x50; sleep .1",
        --   pane = 3,
        --   indent = 4,
        --   width = 65,
        --   height = 50,
        -- },
        { pane = 1, section = "keys", gap = 1, padding = 1 },
        { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
        { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
        {
          pane = 2,
          icon = " ",
          title = "Git Status",
          section = "terminal",
          enabled = function()
            return Snacks.git.get_root() ~= nil
          end,
          cmd = "git status --short --branch --renames",
          height = 5,
          padding = 1,
          ttl = 5 * 60,
          indent = 3,
        },
        { section = "startup" },
      },
    },
  },
}
