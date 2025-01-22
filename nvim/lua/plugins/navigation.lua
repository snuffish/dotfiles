local gen_spec = require("mini.ai").gen_spec
local treesitter = gen_spec.treesitter

return {
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
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
    keys = {
      -- { "<CR>", "<cmd>lua MiniJump2d.start()<CR>" },
      { "<CR>", "<Cmd>lua MiniJump2d.start(MiniJump2d.builtin_opts.line_start)<CR>" },
    },
    config = function(_, opts)
      local jump2d = require("mini.jump2d")
      local jump_line_start = jump2d.builtin_opts.line_start

      table.insert(opts, {
        spotter = jump_line_start.spotter,
        hooks = { after_jump = jump_line_start.hooks.after_jump },
      })

      require("mini.jump2d").setup(opts)
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
