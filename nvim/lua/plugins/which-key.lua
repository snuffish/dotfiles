return {
  "folke/which-key.nvim",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts = {
    spec = {
      {
        "<leader>l",
        "",
        desc = "Lazy",
      },
      {
        "<leader>ll",
        "<cmd>Lazy<CR>",
        desc = "Open Lazy",
      },
      {
        "<leader>lx",
        "<cmd>LazyExtras<CR>",
        icon = { icon = "" },
        desc = "Open LazyExtras",
      },
      {
        "<leader>lm",
        "<cmd>Mason<CR>",
        desc = "Open Mason",
        icon = { icon = "", color = "#FF9856" },
      },
      {
        "<localleader>f",
        desc = "Flash",
        icon = { icon = "", color = "yellow" },
      },
      {
        "<localleader>t",
        desc = "TailwindCSS",
        icon = { icon = "󱏿", color = "blue" },
      },
      {
        "<leader>ld",
        icon = { icon = "", color = "blue" },
        desc = "Open LazyDocker",
      },
      {
        "<leader>lg",
        icon = { icon = "", color = "yellow" },
        desc = "Open LazyGit",
      },
      -- {
      --   "<C-i>",
      --   "",
      --   desc = "Enter insert mode",
      -- },
      -- {
      --   "<C-a>",
      --   "",
      --   desc = "Enter append mode",
      -- },
    },
  },
}
