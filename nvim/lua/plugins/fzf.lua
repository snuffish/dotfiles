return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    {
      "borderless_full",
    },
    winopts = {
      fullscreen = false,
      preview = {
        default = "bat",
      },
      on_create = function()
        vim.keymap.set("t", "<C-j>", "<Down>", { silent = true, buffer = true })
        vim.keymap.set("t", "<C-k>", "<Up>", { silent = true, buffer = true })
        vim.keymap.set("t", "<C-Space>", "<CR>", { silent = true, buffer = true })
      end,
    },
  },
  keys = {
    {
      "<leader>fz",
      "<cmd>FzfLua<CR>",
      desc = "FzfLua BuiltIn",
    },
  },
}
