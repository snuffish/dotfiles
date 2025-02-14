return {
  "akinsho/bufferline.nvim",
  version = false,
  dependencies = "nvim-tree/nvim-web-devicons",
  keys = {
    {
      "<Tab>q",
      "<cmd>lua Snacks.bufdelete.delete()<CR>",
      desc = "Delete Buffer",
      silent = true,
    },
    {
      "<localleader>h",
      function()
        vim.utils.trigger_keys("<leader>uh")
      end,
      desc = "Toggle 'Inlay Hints'",
      silent = true,
    },
    {
      "<localleader>o",
      "<cmd>lua Snacks.bufdelete.other()<CR>",
      desc = "Delete all Other Buffers",
    },
    {
      "<localleader>n",
      "<cmd>enew<CR>",
      desc = "Create new Buffer",
    },
    {
      "<localleader>d",
      function()
        vim.utils.trigger_keys("<leader>ud")
      end,
      desc = "Toggle Diagnostics",
    },
  },
}
