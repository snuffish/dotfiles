return {
  { "tpope/vim-repeat", event = "VeryLazy" },
  {
    "echasnovski/mini.surround",
    optional = true,
    event = "VeryLazy",
    opts = {
      --[[
      NOTE: Set all mappers to `gz` prefix for both Normal & Visual mode compatibility
      and elemintate keymap-conflicts with `z` fold motions.]]
      mappings = {
        add = "gza", -- Add surrounding in Normal and Visual modes
        delete = "gzd", -- Delete surrounding
        replace = "gzc", -- Replace surrounding
        find = "gzf", -- Find surrounding (to the right)
        find_left = "gzF", -- Find surrounding (to the left)
        highlight = "gzh", -- Highlight surrounding
        update_n_lines = "gzn", -- Update `n_lines`

        suffix_last = "l", -- Suffix to search with "prev" method
        suffix_next = "n", -- Suffix to search with "next" method
      },
      n_lines = 500,
    },
    --[[
    WARN: Do NOT map the users keybinds here, instead do a `nvim_keymap` bind in LazyVim`s on_load Keymap
      NOTE: Nvim mappings => "lua/config/keymap.lua"
      vim.api.nvim_set_keymap("n", "sa", "gza", { desc = "Add surrounding" })
      vim.api.nvim_set_keymap("n", "ds", "gzd", { desc = "Delete surrounding" })
      vim.api.nvim_set_keymap("n", "cs", "gzc", { desc = "Change surrounding" })
    ]]
    keys = {
      { "gz", "", desc = "+surround" },
    },
  },
  {
    -- NOTE: Remap "f/t" keys to the actual pressed keys when pressed & memory (infinite) forward/backward navigation.
    "ggandor/flit.nvim",
    enabled = true,
    keys = function()
      local ret = {}
      for _, key in ipairs({ "f", "F", "t", "T" }) do
        ret[#ret + 1] = { key, mode = { "n", "x", "o" } }
      end
      return ret
    end,
    opts = { labeled_modes = "nx" },
    config = function()
      require("flit").setup({
        keys = { f = "f", F = "F", t = "t", T = "T" },
        labeled_modes = "v",
        clever_repeat = true,
        multiline = true,
        opts = {},
      })
    end,
  },
  {
    -- NOTE: Flash Remote [search/yankning/jumping] for Treesitter AST & Multiple panes.
    "folke/flash.nvim",
    enabled = true,
    event = "VeryLazy",
    opts = {},
    -- stylua: ignore
    keys = function ()
      return {
        { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
        { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
        { "rf", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
        { "rs", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
        { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
      }
    end,
  },
}
