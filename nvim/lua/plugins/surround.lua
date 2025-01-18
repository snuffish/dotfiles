local gen_spec = require("mini.ai").gen_spec
local treesitter = gen_spec.treesitter

return {
  {
    "echasnovski/mini.surround",
    opts = {
      mappings = {
        add = ";a",
        delete = ";d",
        find = ";f",
        find_left = ";F",
        highlight = ";h",
        replace = ";r",
        update_n_lines = ";n",
      },
      custom_surroundings = {
        ["B"] = { input = { { "%b{}" }, "^.().*().$" }, output = { left = "{", right = "}" } },
      },
    },
  },
  {
    "folke/flash.nvim",
    opts = {
      modes = {
        char = {
          keys = { "f", "F", "t", "T" },
        },
      },
    },
  },
  {
    "echasnovski/mini.ai",
    version = false,
    config = function()
      require("mini.ai").setup({
        mappings = {
          -- Main textobject prefixes
          around = "a",
          inside = "i",

          -- Next/last variants
          around_next = "an",
          inside_next = "in",
          around_last = "al",
          inside_last = "il",

          -- Move cursor to corresponding edge of `a` textobject
          goto_left = "g[",
          goto_right = "g]",
        },
        custom_textobjects = {
          F = treesitter({ a = "@function.outer", i = "@function.inner" }),
          a = gen_spec.argument({ brackets = { "%b()" } }),
          d = { "%f[%d]%d+" }, -- digits
          i = { treesitter({ a = "@conditional.outer", i = "@condition.inner" }) },
        },
      })

      vim.api.nvim_set_keymap("", "gå", "g[", { silent = true, noremap = true })
    end,
  },
}
