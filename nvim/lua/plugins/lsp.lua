return {
  {
    "neovim/nvim-lspconfig",
    opts = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()

      -- return {
      --   completion = {
      --     trigger = {
      --       show_on_insert_on_trigger_character = false,
      --     },
      --   },
      -- }

      -- keys[#keys + 1] = {
      --   "<leader>cA", false
      -- }
      -- keys[#keys + 1] = {
      --   "<leader>cQ",
      --   function()
      --     print("HEEEEJ")
      --   end,
      --   -- expr = true,
      --   desc = "MY OWN KEYMAP",
      --   -- has = "rename",
      -- }
    end,
    keys = {},
  },
  {
    "hedyhli/outline.nvim",
    lazy = true,
    cmd = { "Outline", "OutlineOpen" },
    keys = {
      { "<leader>O", "<cmd>Outline<CR>", desc = "Toggle outline" },
    },
    opts = {},
    config = function()
      require("outline").setup({})
    end,
  },
  {
    "folke/noice.nvim",
    optional = true,
    opts = {
      presets = { inc_rename = true },
    },
  },
}
