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
          g = function()
            local from = { line = 1, col = 1 }
            local to = {
              line = vim.fn.line("$"),
              col = math.max(vim.fn.getline("$"):len(), 1),
            }
            return { from = from, to = to }
          end,
        },
      })
    end,
    keys = {
      {
        "[q",
        function()
          MiniAi.move_cursor("left", "a", "q", { search_method = "cover_or_prev" })
        end,
        mode = { "n", "v", "x" },
        desc = "Goto next start @quote"
      },
      {
        "[Q",
        function()
          MiniAi.move_cursor("right", "a", "q", { search_method = "cover_or_prev" })
        end,
        mode = { "n", "v", "x" },
        desc = "Goto next end @quote"
      },
      {
        "]q",
        function()
          vim.utils.trigger_keys("g[q")
        end,
        mode = { "n", "v", "x" },
        desc = "Goto next start @quote"
      },
      {
        "]Q",
        function()
          vim.utils.trigger_keys("g]q")
        end,
        mode = { "n", "v", "x" },
        desc = "Goto next end @quote"
      },
    },
  },
}
