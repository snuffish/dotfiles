return {
  "folke/which-key.nvim",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts = {
    spec = {
      {
        {
          "<leader>l",
          "",
          desc = "Lazy",
        },
        {
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
            "<leader>ld",
            icon = { icon = "", color = "blue" },
            desc = "Open LazyDocker",
          },
          {
            "<leader>lg",
            icon = { icon = "", color = "yellow" },
            desc = "Open LazyGit",
          },
        },
      },
      {
        "<localleader>f",
        desc = "Flash",
        icon = { icon = "", color = "yellow" },
      },
      {
        "<leader>n",
        desc = "NPM",
        icon = { icon = "", color = "red" },
      },
      {
        "<localleader>t",
        desc = "TailwindCSS",
        icon = { icon = "󱏿", color = "blue" },
      },
      {
        {
          "ö",
          desc = "Surround",
        },
        {
          ";",
          desc = "Surround",
        },
      },
    },
  },
}
