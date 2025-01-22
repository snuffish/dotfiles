local gen_spec = require("mini.ai").gen_spec
local treesitter = gen_spec.treesitter

local ai_motion = function(textobject)
  local mode = { "n", "x", "o" }

  return {
    {
      "[" .. textobject,
      function()
        MiniAi.move_cursor("left", "a", textobject, { search_method = "cover_or_prev" })
      end,
      mode = mode,
      desc = "Goto next start @" .. textobject,
    },
    {
      "[" .. string.upper(textobject),
      function()
        MiniAi.move_cursor("right", "a", textobject, { search_method = "cover_or_prev" })
      end,
      mode = mode,
      desc = "Goto next end @" .. string.upper(textobject),
    },
    {
      "]" .. textobject,
      function()
        MiniAi.move_cursor("left", "a", textobject, { search_method = "cover_or_next" })
      end,
      mode = mode,
      desc = "Goto next start @" .. textobject,
    },
    {
      "]" .. string.upper(textobject),
      function()
        MiniAi.move_cursor("right", "a", textobject, { search_method = "cover_or_next" })
      end,
      mode = mode,
      desc = "Goto next end @" .. string.upper(textobject),
    },
  }
end

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
    keys = function()
      local quotes = ai_motion("q")
      local brackets = ai_motion("b")

      local keys = {}

      for _, value in ipairs(quotes) do
        keys[#keys + 1] = value
      end

      for _, value in ipairs(brackets) do
        keys[#keys + 1] = value
      end

      return keys
    end,
  },
}
