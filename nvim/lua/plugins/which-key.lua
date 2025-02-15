return {
  "folke/which-key.nvim",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  ---@type wk.Opts
  opts = {
    ---@type wk.Spec
    spec = {
      {
        "<localleader>",
        "",
        desc = "Local Leader",
      },
      {
        "gs",
        "",
        desc = "Treewalker Swap",
      },
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
            icon = { icon = "", color = "cyan" },
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
          {
            "<leader>lp",
            "<cmd>lua Snacks.picker.projects()<CR>",
            icon = { icon = " ", color = "azure" },
            desc = "Open Projects",
          },
          {
            "<leader>lq",
            "<cmd>lua Snacks.dashboard.open()<CR>",
            icon = { icon = "󰕮 ", color = "azure" },
            desc = "Open Dashboard",
          },
        },
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
        "<leader>r",
        desc = "Replace",
        icon = { icon = "", color = "orange" },
      },
    },
  },
  config = function(_, opts)
    require("which-key").setup(opts)
  end,
}
