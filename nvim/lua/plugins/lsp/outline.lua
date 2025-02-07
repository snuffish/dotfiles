return {
  "hedyhli/outline.nvim",
  cmd = { "Outline", "OutlineOpen" },
  keys = {
    { "<localleader>o", "<cmd>Outline<CR>", desc = "Toggle outline" },
  },
  opts = {
    outline_window = {
      -- auto_jump = true,
      auto_close = true,
    },
    preview_window = {
      auto_preview = true,
      live = true,
    },
    symbol_folding = {
      autofold_depth = false,
      -- auto_unfold = {
      --   only = 2,
      -- },
    },
    keymaps = {
      toggle_preview = "e",
    },
  },
}
