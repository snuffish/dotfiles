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
      "<localleader>n",
      "<cmd>enew<CR>",
      desc = "Create new Buffer",
    },
    {
      "<localleader><localleader>",
      "<cmd>FzfLua buffers<CR>",
      desc = "Switch Buffers",
    },
    {
      "<localleader><Tab>",
      "<cmd>BufferLineCycleNext<CR>",
      desc = "Next Buffer",
    },
    {
      "<localleader><S-Tab>",
      "<cmd>BufferLineCyclePrev<CR>",
      desc = "Previous Buffer",
    },
    {
      "<localleader>d",
      "<cmd>bd<CR>",
      desc = "Delete Buffer",
    },
    {
      "<localleader>D",
      "<cmd>bD<CR>",
      desc = "Delete Buffer and Window",
    },
    {
      "<localleader>o",
      "<cmd>BufferLineCloseOthers<CR>",
      desc = "Close all Other Buffers",
    },
    {
       "<localleader>m",
      "<cmd>MaximizerToggle<CR>",
      desc = "Maximize/minimize a split",
    },
    {
      ",m",
      "<cmd>MaximizerToggle<CR>",
      desc = "Maximize/minimize a split",
    },
  },
}
