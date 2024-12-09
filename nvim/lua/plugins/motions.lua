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
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "bsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
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
          f = gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
          i = gen_spec.treesitter({ a = "@conditional.outer", i = "@conditional.inner" }),
          c = gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
          -- digits
          d = { "%f[%d]%d+" },
          -- Word with case
          e = { 
            { "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
            "^().*()$",
          },
          u = gen_spec.function_call(), 
          -- without dot in function name
          U = gen_spec.function_call({ name_pattern = "[%w_]" }),
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
  -- {
  --   'mawkler/demicolon.nvim',
  --   -- keys = { ';', ',', 't', 'f', 'T', 'F', ']', '[', ']d', '[d' }, -- Uncomment this to lazy load
  --   dependencies = {
  --     'nvim-treesitter/nvim-treesitter',
  --     'nvim-treesitter/nvim-treesitter-textobjects',
  --   },
  --   opts = {}
  -- },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    -- stylua: ignore
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "rf", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },
  {
    "abecodes/tabout.nvim",
    opt = true, -- Set this to true if the plugin is optional
    event = "InsertCharPre", -- Set the event to 'InsertCharPre' for better compatibility
    priority = 1000,
    opts = {
      tabkey = "<Tab>", -- key to trigger tabout, set to an empty string to disable
      backwards_tabkey = "<S-Tab>", -- key to trigger backwards tabout, set to an empty string to disable
      act_as_tab = true, -- shift content if tab out is not possible
      act_as_shift_tab = false, -- reverse shift content if tab out is not possible (if your keyboard/terminal supports <S-Tab>)
      default_tab = "<C-t>", -- shift default action (only at the beginning of a line, otherwise <TAB> is used)
      default_shift_tab = "<C-d>", -- reverse shift default action,
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
    dependencies = { -- These are optional
      "nvim-treesitter/nvim-treesitter",
      -- "L3MON4D3/LuaSnip",
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
        vim.api.nvim_set_hl(0, "EolMark", { link = "NonText" })
      end,
    }
  },
}
-- {
--   "L3MON4D3/LuaSnip",
--   keys = function()
--     -- Disable default tab keybinding in LuaSnip
--     return {}
--   end,
-- },
-- }
