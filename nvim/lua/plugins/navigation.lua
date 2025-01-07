return {
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
      highlight = true, -- Whether to briefly highlight the node after jumping to it
      highlight_duration = 250, -- How long should above highlight last (in ms)
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
        start_jumping = "<CR>",
      },
    },
    keys = {
      { "<CR>", "<cmd>lua MiniJump2d.start()<CR>" },
      { "<CR><CR>", "<Cmd>lua MiniJump2d.start(MiniJump2d.builtin_opts.line_start)<CR>" },
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
}
