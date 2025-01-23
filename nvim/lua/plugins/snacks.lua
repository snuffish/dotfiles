return {
  {
    "MaximilianLloyd/ascii.nvim",
    requires = { "MunifTanjim/nui.nvim" },
  },
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        win = {
          input = {
            keys = {
              ["<C-p>"] = { "toggle_preview", mode = { "i", "n" } },
              ["<A-p>"] = false,
            },
          },
        },
      },
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
            section = "terminal",
            cmd = "chafa ~/.config/nvim/avatar.png --format ansi --size 71x50; sleep .1",
            pane = 2,
            indent = 4,
            width = 65,
            height = 50,
          },
          {
            { section = "header" },
            { section = "keys", gap = 1, padding = 1 },
            { section = "startup" },
          },
        },
      },
    },
    keys = {
      {
        "<leader>sp",
        "<cmd>lua Snacks.picker.pick()<CR>",
        desc = "Pickers",
      },
      {
        "<leader>sr",
        "<cmd>lua Snacks.picker.resume()<CR>",
        desc = "Resume",
      },
      {
        "<leader>fr",
        "<cmd>lua Snacks.picker.recent()<CR>",
        desc = "Recent",
      },
      {
        "<leader>/",
        "<cmd>lua Snacks.picker.grep()<CR>",
        desc = "Grep (Root Dir)",
      },
      {
        "<leader>sh",
        "<cmd>lua Snacks.picker.help()<CR>",
        desc = "Help pages",
      },
      {
        "<leader><leader>",
        "<cmd>lua Snacks.picker.files()<CR>",
        desc = "Find files",
      },
      {
        "<leader>fb",
        "<cmd>lua Snacks.picker.buffers()<CR>",
        desc = "Buffers",
      },
      {
        "<leader>fg",
        "<cmd>lua Snacks.picker.git_files()<CR>",
        desc = "Find files (git-files)",
      },
      {
        "<leader>sb",
        function()
          require("snacks.picker").grep_buffers()
        end,
        desc = "Buffer",
      },
      {
        "<leader>lg",
        "<cmd>lua Snacks.lazygit()<cr>",
        desc = "Open LazyGit",
      },
      {
        "<leader>gf",
        "<cmd>lua Snacks.lazygit.log_file()<cr>",
        desc = "Git Current File History",
      },
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
      {
        "g/",
        "<cmd>lua Snacks.picker.grep_word()<CR>",
        mode = { "n" },
        desc = "Grep <cword>",
      },
      {
        "<leader>sk",
        "<cmd>lua Snacks.picker.keymaps()<CR>",
        desc = "Keymaps",
      },
      {
        "<leader>su",
        "<cmd>lua Snacks.picker.und󰠣o()<CR>",
        desc = "Undo",
      },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
    end,
  },
  {
    "mgierada/lazydocker.nvim",
    dependencies = { "akinsho/toggleterm.nvim" },
    config = function()
      require("lazydocker").setup({
        border = "curved",
      })
    end,
    event = "BufRead",
    opts = {},
    keys = {
      {
        "<leader>ld",
        function()
          require("lazydocker").open()
        end,
        desc = "Open LazyDocker",
      },
    },
  },
}
