return {
  "folke/which-key.nvim",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts = {
    spec = {
      {
        "J",
        desc = "Join lines",
      },
      {
        "<leader>l",
        desc = "Lazy",
      },
      {
        "<leader>lx",
        "<cmd>LazyExtras<CR>",
        desc = "Lazy Extras",
      },
      {
        "<leader>ll",
        "<cmd>LazyExtras<CR>",
        desc = "Open LazyExtras",
      },
      {
        "<localleader>f",
        desc = "Flash",
        icon = { icon = " ", color = "yellow" },
      },
      {
        "<localleader>t",
        desc = "TailwindCSS",
        icon = { icon = "󱏿 ", color = "blue" },
      },
      {
        "<leader>ld",
        icon = { icon = " ", color = "blue" },
        desc = "Open LazyDocker",
      },
      {
        "<leader>lg",
        icon = { icon = " ", color = "yellow" },
        desc = "Open LazyGit",
      },
    },
  },
}
