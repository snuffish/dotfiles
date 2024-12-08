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
        { "<leader>cc", group = "copilot", icon = { icon = " ", color = "yellow" } },
        {
          "<localleader>",
          group = "Current Buffer",
        },
      },
    },
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
