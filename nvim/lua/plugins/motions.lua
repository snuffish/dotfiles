return {
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      require("mini.pairs").setup()
      require("mini.basics").setup()
      require("mini.operators").setup()
      require("mini.pick").setup()
      require("mini.move").setup()
      require("mini.comment").setup()
      require("mini.bracketed").setup()
      require("mini.icons").setup()
    end,
  },
  {
    "mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "sa",
        delete = "ds",
        find = "sf",
        find_left = "sF",
        highlight = "sh",
        replace = "cs",
        update_n_lines = "gsn",

        suffix_last = 'l', -- Suffix to search with "prev" method
        suffix_next = 'n', -- Suffix to search with "next" method

      },
      n_lines = 500,
    },
    config = function(_, opts)
      require("mini.surround").setup(opts)
    end,
  },
  {
    "mini.ai",
    event = "VeryLazy",
    opts = function()
      local ai = require("mini.ai")
      local gen_spec = ai.gen_spec

      return {
        n_lines = 500,
        custom_textobjects = {
          i = {
            gen_spec.treesitter({ a = "@conditional.outer",i = "@conditional.inner" }),
        }
          , -- function
          f = gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }), -- function
         c = gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }), -- class
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
          d = { "%f[%d]%d+" }, -- digits
          e = { -- Word with case
            { "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
            "^().*()$",
          },
          u = gen_spec.function_call(), -- u for "Usage"
          U = gen_spec.function_call({ name_pattern = "[%w_]" }), -- without dot in function name
        },
      }
    end,
    config = function(_, opts)
      require("mini.ai").setup(opts)
      LazyVim.on_load("which-key.nvim", function()
        vim.schedule(function()
           LazyVim.mini.ai_whichkey(opts)
        end)
      end)
    end,
  },
  {
    'mawkler/demicolon.nvim',
    -- keys = { ';', ',', 't', 'f', 'T', 'F', ']', '[', ']d', '[d' }, -- Uncomment this to lazy load
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    opts = {}
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    -- stylua: ignore
    keys = function ()
     local centerScreen = vim.api.nvim_feedkeys('zz', 'n', true)

      return {
        { "s", mode = { "n", "x", "o" }, function()
          require("flash").jump()
          if centerScreen then centerScreen() end
        end, desc = "Flash" },
        { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
        { "rf", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
        { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
        { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
      }
    end,
  },
  {
    "abecodes/tabout.nvim",
    opt = true, -- set this to true if the plugin is optional
    event = "insertcharpre", -- set the event to 'insertcharpre' for better compatibility
    priority = 1000,
    opts = {
      tabkey = "<tab>", -- key to trigger tabout, set to an empty string to disable
      backwards_tabkey = "<s-tab>", -- key to trigger backwards tabout, set to an empty string to disable
      act_as_tab = true, -- shift content if tab out is not possible
      act_as_shift_tab = false, -- reverse shift content if tab out is not possible (if your keyboard/terminal supports <s-tab>)
      default_tab = "<c-t>", -- shift default action (only at the beginning of a line, otherwise <tab> is used)
      default_shift_tab = "<c-d>", -- reverse shift default action,
      enable_backwards = true, -- well ...
      completion = false, -- if the tabkey is used in a completion pum
      tabouts = {
        { open = "'", close = "'" },
        { open = '"', close = '"' },
        { open = "`", close = "`" },
        { open = "(", close = ")" },
        { open = "[", close = "]" },
        { open = "{", close = "}" },
      },
      ignore_beginning = true, --[[ if the cursor is at the beginning of a filled element it will rather tab out than shift the content ]]
      exclude = {}, -- tabout will ignore these filetypes
    },
    config = function(_, opts)
      require("tabout").setup(opts)
    end,
    dependencies = { -- these are optional
      "nvim-treesitter/nvim-treesitter",
      -- "l3mon4d3/luasnip",
      "hrsh7th/nvim-cmp",
    },
    {
      "aidancz/eolmark.nvim",
      lazy = false,
      enabled = false,
      config = function()
        require("eolmark").setup({
          mark = " $",
        })
        vim.api.nvim_set_hl(0, "eolmark", { link = "nontext" })
      end,
    }
  },
}
-- {
--   "l3MON4D3/LuaSnip",
--   keys = function()
--     -- Disable default tab keybinding in LuaSnip
--     return {}
--   end,
-- },
-- }
