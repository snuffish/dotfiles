local gen_spec = require("mini.ai").gen_spec
local treesitter = gen_spec.treesitter

return {
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
  {
    "Bekaboo/dropbar.nvim",
    -- optional, but required for fuzzy finder support
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
    config = function()
      local dropbar_api = require("dropbar.api")
      vim.keymap.set("n", "<leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
      vim.keymap.set("n", "<localleader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
      vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
      vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })
    end,
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
      highlight = true,
      highlight_duration = 250,
    },
    keys = {
      { "<C-m-l>", "<cmd>Treewalker Right<CR>", noremap = true, desc = "Right" },
      { "<C-m-h>", "<cmd>Treewalker Left<CR>", noremap = true, desc = "Left" },
      { "<C-m-j>", "<cmd>Treewalker Down<CR>", noremap = true, desc = "Down" },
      { "<C-m-k>", "<cmd>Treewalker Up<CR>", noremap = true, desc = "Up" },
      { "gsl", "<cmd>Treewalker SwapRight<CR>", noremap = true, desc = "Swap Right" },
      { "gsh", "<cmd>Treewalker SwapLeft<CR>", noremap = true, desc = "Swap Left" },
      { "gsj", "<cmd>Treewalker SwapDown<CR>", noremap = true, desc = "Swap Down" },
      { "gsk", "<cmd>Treewalker SwapUp<CR>", noremap = true, desc = "Swap Up" },
    },
  },
  {
    "echasnovski/mini.cursorword",
    version = false,
    config = function()
      require("mini.cursorword").setup()
    end,
  },
  {
    "echasnovski/mini.jump2d",
    version = false,
    opts = {
      allowed_lines = { cursor_before = true },
      allowed_windows = { not_current = false },

      view = {
        dim = true,
        n_steps_ahead = 0,
      },

      mappings = {
        start_jumping = "<nop>",
      },
    },
    config = function(_, opts)
      local jump2d = require("mini.jump2d")
      local jump_line_start = jump2d.builtin_opts.line_start

      table.insert(opts, {
        spotter = jump_line_start.spotter,
        hooks = { after_jump = jump_line_start.hooks.after_jump },
      })

      jump2d.setup(opts)
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      textobjects = {
        move = {
          enable = true,
          -- goto_next_start = { []"f"] = "@function.outer", ["]c"] = "@class.outer", ["]a"] = "@parameter.inner" },
          -- goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer", ["]A"] = "@parameter.inner" },
          -- goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer", ["[a"] = "@parameter.inner" },
          -- goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer", ["[A"] = "@parameter.inner" },
        },
      },
    },
  },
}
