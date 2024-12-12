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
      { "<leader>b", hidden = true }
    }

    for _, keymap in ipairs(hidden_keymaps) do
      require('utils').add_which_key(keymap)
    end

    -- Hide select buffer keymaps
    for i = 1, 9 do
      require('utils').add_which_key({
        string.format("<localleader>%d", i),
        hidden = true
      })
    end

    local opts = {
      spec = {
        {
          "<leader>cc",
          group = "copilot",
          icon = { icon = " ", color = "yellow" },
        },
        {
          "<localleader>",
          group = "Local Buffer",
          icon = { icon = " ", color = "blue" }
        },
        {
          "<leader>m",
          group = "Math",
          icon = { icon = " ", color = "green" }
        },
        {
          "<leader>s",
          group = "Search",
          icon = { icon = " ", color = "blue" }
        },
        {
          "<leader>f",
          group = "Find",
          icon = { icon = " ", color = "blue" }
        },
        {
          "<leader>d",
          group = "Debug",
          icon = { icon = " ", color = "red" }
        },
      }
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
