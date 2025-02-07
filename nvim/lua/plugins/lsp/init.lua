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
    dependencies = {
      require("plugins.lsp.cmp"),
      require("plugins.lsp.outline"),
      "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    opts = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()

      keys[#keys + 1] = {
        "K",
        false,
      }

      keys[#keys + 1] = {
        "gr",
        Snacks.picker.lsp_references,
        desc = "References",
      }

      keys[#keys + 1] = {
        "o",
        false,
      }

      keys[#keys + 1] = {
        "gK",
        vim.lsp.buf.hover,
        desc = "Hover",
      }

      keys[#keys + 1] = {
        "gH",
        vim.lsp.buf.signature_help,
        desc = "Signature Help",
        has = "signatureHelp",
      }
    end,
    -- config = function()
    --   require("mason-lspconfig").setup({
    --     automatic_installation = true,
    --     ensure_installed = {
    --       "jdtls",
    --       "vtsls",
    --       "tailwindcss-language-server",
    --     },
    --   })
    --
    --   -- local lspconfig = require("lspconfig")
    --
    --   -- local capabilities = require("cmp_nvim_lsp").default_capabilities()
    --   --
    --   -- require("mason-lspconfig").setup_handlers({
    --   --   function(server_name)
    --   --     if server_name ~= "jdtls" then
    --   --       lspconfig[server_name].setup({
    --   --         on_attach = lsp_attach,
    --   --         capabilities = lsp_capabilities,
    --   --       })
    --   --     end
    --   --   end,
    --   -- })
    -- end,
  },
  -- {
  --   "yioneko/nvim-vtsls",
  --   opts = {},
  --   config = function()
  --     -- require("nvim-vtls").setup({})
  --     --
  --     -- require("vtsls").commands.organize_imports(
  --     --   vim.utils.get_current_bufnr(),
  --     --   on_resolve,
  --     --   on_reject
  --     -- )
  --     --
  --     -- function on_resolve() end
  --     -- function on_reject() end
  --   end,
  -- },
}
