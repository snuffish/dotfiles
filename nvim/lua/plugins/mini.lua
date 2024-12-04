return {
  "echasnovski/mini.nvim",
  version = false,
  config = function() 
    require("mini.surround").setup()
    require("mini.pairs").setup()
    require("mini.ai").setup()
    require("mini.basics").setup()
    require("mini.operators").setup()
    require("mini.pick").setup()
    require("mini.move").setup()
    require("mini.comment").setup()
    require("mini.bracketed").setup()
    require("mini.bracketed").setup()
  end,
}

-- {
  --   mappings = {
    --     [ add ] = "ys",
    --     delete = "ds",
    --     find = "",
    --     find_left = "",
    --     highlight = "",
    --     replace = "cs",
    --     update_n_lines = "",
    --
    --     -- Add this only if you don't want to use extended mappings
    --     suffix_last = "",
    --     suffix_next = "",
    --   },
    --   search_method = "cover_or_next",
    -- }

    -- return {
      --   "tpope/vim-surround",
      -- }

      -- require("mini.map").setup()
