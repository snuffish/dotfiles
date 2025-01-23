return {
  "ibhagwan/fzf-lua",
  enable = false,
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
      "<leader>sk",
      false,
    },
    {
      "<leader>sh",
      false,
    },
    {
      "<leader>fg",
      false,
    },
    {
      "<leader>fr",
      false,
    },
    {
      "<leader>/",
      false,
    },
    {
      "<leader>sR",
      false,
    },
    {
      "<leader>sb",
      false,
    },
    {
      "<leader>fb",
      false,
    },
    {
      "<leader><leader>",
      false,
    },
    {
      "\\",
      false,
    },
    {
      "<leader>fz",
      "<cmd>FzfLua<CR>",
      desc = "FzfLua BuiltIn",
    },
  },
}
