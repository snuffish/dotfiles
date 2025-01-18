return {
  {
    "luckasRanarison/tailwind-tools.nvim",
    ft = "typescriptreact",
    name = "tailwind-tools",
    build = ":UpdateRemotePlugins",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "neovim/nvim-lspconfig",
    },
    opts = {},
    keys = {
      {
        "<localleader>tt",
        "<cmd>TailwindConcealToggle<CR>",
        desc = "Toggle 'Conceal'",
      },
      {
        "<localleader>tc",
        "<cmd>TailwindColorToggle<CR>",
        desc = "Toggle 'Color'",
      },
      {
        "<localleader>ts",
        "<cmd>TailwindSort<CR>",
        desc = "Sort Classes",
      },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "tailwind-tools",
      "onsails/lspkind-nvim",
    },
    opts = function()
      return {
        formatting = {
          format = require("lspkind").cmp_format({
            before = require("tailwind-tools.cmp").lspkind_format,
          }),
        },
      }
    end,
  },
}
