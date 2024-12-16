return {
  { "tpope/vim-repeat", event = "VeryLazy" },
  {
    "echasnovski/mini.surround",
    optional = true,
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "gza",
        delete = "gzd",
        replace = "gzc",
        find = "gzf",
        find_left = "gzF",
        highlight = "gzh",
        update_n_lines = "gzn",
        suffix_last = "l",
        suffix_next = "n",
      },
      n_lines = 500,
    },
    keys = {
      { "gz", "", desc = "+surround" },
    },
  },
  {
    "ggandor/flit.nvim",
    enabled = true,
    keys = function()
      local ret = {}
      for _, key in ipairs({ "f", "F", "t", "T" }) do
        table.insert(ret, { key, mode = { "n", "x", "o" } })
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
      })
    end,
  },
  {
    "folke/flash.nvim",
    enabled = true,
    event = "VeryLazy",
    opts = {},
    keys = function()
      return {
        { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash", },
        { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
        { "rf", mode = "o", function() require("flash").remote() end, desc = "Remote Flash", },
        { "rs", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
        { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
      }
    end,
  },
}
