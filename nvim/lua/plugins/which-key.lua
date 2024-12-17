return {
  "folke/which-key.nvim",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts = {
    spec = {
      {
        "gs",
        hidden = true
      },
      {
        "J",
        desc = "Join lines"
      },
      {
        "<leader>l",
        desc = "Lazy"
      },
      {
        "Y",
        desc = "Yank to end of line"
      }
    }
  },
}
