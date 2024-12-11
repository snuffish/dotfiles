return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts_extend = { "spec" },
  opts = function()
    local hidden_keymaps = {
      { "<Left>", hidden = true },
      { "<Right>", hidden = true },
      { "<Up>", hidden = true },
      { "<Down>", hidden = true },
    }

    -- Hide select buffer keymaps
    for i = 1, 9 do
      table.insert(hidden_keymaps, {
        string.format("<localleader>%d", i),
        hidden = true
      })
    end

    local opts = {
      hidden_keymaps,
      spec = {
        {
          "<leader>cc",
          group = "copilot",
          icon = { icon = " ", color = "yellow" },
        },
        {
          "<localleader>",
          group = "Current Buffer",
        },
      },
    }

    return opts
  end,
  keys = {},
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)
    if opts.defaults and not vim.tbl_isempty(opts.defaults) then
      LazyVim.warn("which-key: opts.defaults is deprecated. Please use opts.spec instead.")
      wk.add(opts.defaults)
    end
  end
}
