return {
  {
    "giuxtaposition/blink-cmp-copilot",
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      {
        "hedyhli/outline.nvim",
        cmd = { "Outline", "OutlineOpen" },
        keys = {
          { "<localleader>o", "<cmd>Outline<CR>", desc = "Toggle outline" },
        },
        opts = {
          outline_window = {
            auto_jump = true,
            auto_close = true,
          },
          preview_window = {
            auto_preview = true,
            live = true,
          },
        },
      },
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
  },
  {
    "yioneko/nvim-vtsls",
    opts = {},
    config = function()
      -- require("nvim-vtls").setup({})
      --
      -- require("vtsls").commands.organize_imports(
      --   vim.utils.get_current_bufnr(),
      --   on_resolve,
      --   on_reject
      -- )
      --
      -- function on_resolve() end
      -- function on_reject() end
    end,
  },
  {
    "folke/noice.nvim",
    optional = true,
    opts = {
      presets = { inc_rename = true },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "DasGandlaf/nvim-autohotkey",
    },
    config = function()
      local cmp = require("cmp")

      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },

        mapping = cmp.mapping.preset.insert({
          ["<PageDown>"] = cmp.mapping.scroll_docs(-4),
          ["<PageUp>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<Esc>"] = cmp.mapping.close(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          -- { name = "autohotkey" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },
}
