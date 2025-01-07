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

      local symbols = {
        ["q"] = "Quotes `'\"",
        ["b"] = "Brackets {([])}",
        ["B"] = "Brackets {}",
        ["a"] = "Argument",
        ["f"] = "Function (inner)",
        ["F"] = "Function (outer)",
      }

      for symbol, desc in pairs(symbols) do
        vim.api.nvim_set_keymap("n", "<M-i>" .. symbol, "vin" .. symbol .. "<Esc>i", { desc = desc })
        vim.api.nvim_set_keymap("n", "<M-a>" .. symbol, "vin" .. symbol .. "o<Esc>a", { desc = desc })
        -- vim.api.nvim_set_keymap("n", "<M-i>" .. symbol, "g[" .. symbol .. "a", { desc = desc })
        -- vim.api.nvim_set_keymap("n", "<M-a>" .. symbol, "g]" .. symbol .. "i", { desc = desc })
      end
    end,
  },
}
