return {
  "folke/snacks.nvim",
  opts = {
    scope = {
      keys = {
        textobject = {
          ie = {
            min_size = 2, -- minimum size of the scope
            edge = false, -- inner scope
            cursor = false,
            treesitter = { blocks = { enabled = false } },
            desc = "inner scope",
          },
          ae = {
            cursor = false,
            min_size = 2, -- minimum size of the scope
            treesitter = { blocks = { enabled = false } },
            desc = "full scope",
          },
        },
        jump = {
          ["[e"] = {
            min_size = 1, -- allow single line scopes
            bottom = false,
            cursor = false,
            edge = true,
            treesitter = { blocks = { enabled = false } },
            desc = "jump to top edge of scope",
          },
          ["]e"] = {
            min_size = 1, -- allow single line scopes
            bottom = true,
            cursor = false,
            edge = true,
            treesitter = { blocks = { enabled = false } },
            desc = "jump to bottom edge of scope",
          },
        },
      },
    },
  },
}
