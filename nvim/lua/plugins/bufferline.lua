return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "szw/vim-maximizer",
  },
  opts = {},
  keys = {
    {
      "<LocalLeader>n",
      "<cmd>enew<CR>",
      desc = "Create new Buffer",
    },
    {
      "<LocalLeader><LocalLeader>",
      "<cmd>FzfLua buffers<CR>",
      desc = "Switch Buffers",
    },
    {
      "<LocalLeader><Tab>",
      "<cmd>BufferLineCycleNext<CR>",
      desc = "Next Buffer",
    },
    {
      "<LocalLeader><S-Tab>",
      "<cmd>BufferLineCyclePrev<CR>",
      desc = "Previous Buffer",
    },
    {
      "<LocalLeader>d",
      "<cmd>bd<CR>",
      desc = "Delete Buffer",
    },
    {
      "<LocalLeader>D",
      "<cmd>bD<CR>",
      desc = "Delete Buffer and Window",
    },
    {
      "<LocalLeader>o",
      "<cmd>BufferLineCloseOthers<CR>",
      desc = "Close all Other Buffers",
    },
    {
      "<LocalLeader>m",
      "<cmd>MaximizerToggle<CR>",
      desc = "Maximize/minimize a split",
    },
  },
}
