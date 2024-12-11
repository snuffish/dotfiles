local hidden_keymaps = {
  { "<Left>", hidden = true },
  { "<Right>", hidden = true },
  { "<Up>", hidden = true },
  { "<Down>", hidden = true },
}

return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts_extend = { "spec" },
  opts = {
    spec = {
      hidden_keymaps,
      {
        {
          "<leader>cc",
          group = "copilot",
          icon = { icon = " ", color = "yellow" },
          mode = { "n", "v", "i" },
        },
        {
          "<localleader>",
          group = "Current Buffer",
          mode = { "n", "v", "i" },
        },
      },
    },
  },
  keys = {
    {
      "<localleader>",
      function ()
       vim.nvim.Keymaps.set('')
      end,
      desc = "Buffer Local Keymaps"
      -- "<cmd>WhichKey '<localleader>'<CR>",
      -- { noremap = true, silent = true },
    }
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)
    if not vim.tbl_isempty(opts.defaults) then
      LazyVim.warn("which-key: opts.defaults is deprecated. Please use opts.spec instead.")
      wk.add(opts.defaults)
    end
  end,
}
