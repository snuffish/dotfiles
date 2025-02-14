return {
  "hedyhli/outline.nvim",
  cmd = { "Outline", "OutlineOpen" },
  keys = {
    { "<localleader>o", "<cmd>Outline<CR>", desc = "Toggle outline" },
  },
  opts = {
    outline_window = {
      auto_close = true,
      wrap = true,
    },
    preview_window = {
      auto_preview = true,
      live = true,
    },
    symbol_folding = {
      autofold_depth = 0,
      auto_unfold = {
        hovered = true,
      },
    },
    keymaps = {
      toggle_preview = "e",
      fold = { "h", "<Left>" },
      unfold = { "l", "<Right>" },
    },
  },
}
