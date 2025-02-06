return {
  "ibhagwan/fzf-lua",
  enabled = false,
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
        vim.utils.map("t", "<C-j>", "<Down>", { silent = true, buffer = true })
        vim.utils.map("t", "<C-k>", "<Up>", { silent = true, buffer = true })
        vim.utils.map("t", "<C-Space>", "<CR>", { silent = true, buffer = true })
      end,
    },
  },
}
