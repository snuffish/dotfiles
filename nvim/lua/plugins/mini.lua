local gen_spec = require("mini.ai").gen_spec
local treesitter = gen_spec.treesitter

local ai_motion = function(textobject, search_method)
  local mode = { "n", "x", "o" }

  local search_method_param = function(direction)
    if search_method == "cover" then
      return "cover_or_" .. direction
    end

    return direction
  end

  return {
    {
      "[" .. textobject,
      function()
        MiniAi.move_cursor("left", "a", textobject, { search_method = search_method_param("prev") })
      end,
      mode = mode,
      desc = "Goto next start @" .. textobject,
    },
    {
      "[" .. textobject:upper(),
      function()
        MiniAi.move_cursor("right", "a", textobject, { search_method = search_method_param("prev") })
      end,
      mode = mode,
      desc = "Goto next end @" .. textobject:upper(),
    },
    {
      "]" .. textobject,
      function()
        MiniAi.move_cursor("left", "a", textobject, { search_method = search_method_param("next") })
      end,
      mode = mode,
      desc = "Goto next start @" .. textobject,
    },
    {
      "]" .. textobject:upper(),
      function()
        MiniAi.move_cursor("right", "a", textobject, { search_method = search_method_param("next") })
      end,
      mode = mode,
      desc = "Goto next end @" .. textobject:upper(),
    },
  }
end

return {
  {
    "echasnovski/mini.surround",
    opts = {
      -- mappings = {
      --   add = ";a",
      --   delete = ";d",
      --   find = ";f",
      --   find_left = ";F",
      --   highlight = ";h",
      --   replace = ";r",
      --   update_n_lines = ";n",
      -- },
      mappings = {
        add = "ys",
        delete = "ds",
        find = "",
        find_left = "",
        highlight = "",
        replace = "cs",
        update_n_lines = "",

        -- Add this only if you don't want to use extended mappings
        suffix_last = "",
        suffix_next = "",
      },
      search_method = "cover_or_next",
      custom_surroundings = {
        ["B"] = { input = { { "%b{}" }, "^.().*().$" }, output = { left = "{", right = "}" } },
      },
    },
    config = function(_, opts)
      require("mini.surround").setup(opts)

      -- Remap adding surrounding to Visual mode selection
      vim.keymap.del("x", "ys")
      vim.keymap.set("x", "S", [[:<C-u>lua MiniSurround.add('visual')<CR>]], { silent = true })

      vim.keymap.set("n", "yss", "ys_", { remap = true, desc = "Surround line" })
      vim.keymap.set("n", "yw", "ysiw", { remap = true, desc = "Surround <cword>" })
    end,
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

        n_lines = 250,

        search_method = "cover_or_next",

        custom_textobjects = {
          F = treesitter({ a = "@function.outer", i = "@function.inner" }),
          a = gen_spec.argument({ brackets = { "%b()" } }),
          d = { "%f[%d]%d+" }, -- digits
          i = { treesitter({ a = "@conditional.outer", i = "@condition.inner" }) },
          g = function() -- Whole buffer
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
      function TableConcat(t1, t2)
        for i = 1, #t2 do
          t1[#t1 + 1] = t2[i]
        end
        return t1
      end

      local quotes = ai_motion("q", "cover")
      -- local brackets = ai_motion("b")
      -- local keys = TableConcat(quotes, brackets)
      return quotes
    end,
  },
  {
    "echasnovski/mini.operators",
    version = false,
    config = function()
      require("mini.operators").setup()
    end,
  },
  {
    "echasnovski/mini.basics",
    version = false,
    config = function()
      require("mini.basics").setup()
    end,
  },
  -- {
  --   "echasnovski/mini.bracketed",
  --   version = false,
  --   config = function()
  --     require("mini.bracketed").setup()
  --   end,
  -- },
  {
    "echasnovski/mini.splitjoin",
    version = false,
    config = function()
      require("mini.splitjoin").setup()
    end,
  },
}
