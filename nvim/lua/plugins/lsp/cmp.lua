return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        ["<C-u>"] = { "scroll_documentation_up", "fallback" },
      },
    },
  },
  -- {
  --   "hrsh7th/nvim-cmp",
  --   dependencies = {
  --     "hrsh7th/cmp-nvim-lsp",
  --     "hrsh7th/cmp-buffer",
  --     "hrsh7th/cmp-path",
  --     "hrsh7th/cmp-cmdline",
  --     "L3MON4D3/LuaSnip",
  --     "saadparwaiz1/cmp_luasnip",
  --     "DasGandlaf/nvim-autohotkey",
  --   },
  --   config = function()
  --     -- local cmp = require("cmp")
  --     --
  --     -- cmp.setup({
  --     --   snippet = {
  --     --     expand = function(args)
  --     --       require("luasnip").lsp_expand(args.body)
  --     --     end,
  --     --   },
  --     --
  --     --   mapping = cmp.mapping.preset.insert({
  --     --     ["<PageDown>"] = cmp.mapping.scroll_docs(-4),
  --     --     ["<PageUp>"] = cmp.mapping.scroll_docs(4),
  --     --     ["<C-Space>"] = cmp.mapping.complete(),
  --     --     ["<C-e>"] = cmp.mapping.abort(),
  --     --     ["<Esc>"] = cmp.mapping.close(),
  --     --     ["<CR>"] = cmp.mapping.confirm({ select = true }),
  --     --   }),
  --     --   sources = cmp.config.sources({
  --     --     { name = "nvim_lsp" },
  --     --     { name = "luasnip" },
  --     --     -- { name = "autohotkey" },
  --     --   }, {
  --     --     { name = "buffer" },
  --     --   }),
  --     -- })
  --   end,
  -- },
  -- {
  --   "giuxtaposition/blink-cmp-copilot",
  -- },
}
