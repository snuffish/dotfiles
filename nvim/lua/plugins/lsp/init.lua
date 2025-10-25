return {
  require("plugins.lsp.java"),
  require("plugins.lsp.tailwind-css"),
  {
    "folke/noice.nvim",
    optional = true,
    opts = {
      presets = { inc_rename = true },
    },
  },
  {
    "neovim/nvim-lspconfig",
    priority = 1,
    opts = {
      servers = {
        ["*"] = {
          keys = {
            { "gd", "lua vim.lsp.buf.definition()", has = "definition" },
            { "K", false },
            { "o", false },
            { "gK", vim.lsp.buf.hover },
            {
              "gH",
              vim.lsp.buf.signature_help,
              desc = "Signature Help",
              has = "signatureHelp",
            },
          },
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    dependencies = {
      require("plugins.lsp.cmp"),
      require("plugins.lsp.outline"),
      require("plugins.lsp.hierarchy"),
    },
  },
}
