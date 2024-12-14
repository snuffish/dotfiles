return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  opts = {},
  keys = function()
    local keymaps = {
      {
        "<localleader>n",
        "<cmd>enew<CR>",
        desc = "Create new Buffer",
      },
      {
        ",n",
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
        "<localleader>q",
        "<cmd>bd<CR>",
        desc = "Delete Buffer",
      },
      {
        "<localleader>Q",
        "<cmd>bD<CR>",
        desc = "Delete Buffer and Window",
      },
      {
        "<localleader>o",
        "<cmd>BufferLineCloseOthers<CR>",
        desc = "Close all Other Buffers",
      },
      {
        "<localleader>ol",
        "<cmd>BufferLineCloseRight<CR>",
        desc = "Close Buffers to the Right",
      },
      {
        "<localleader>oh",
        "<cmd>BufferLineCloseLeft<CR>",
        desc = "Close Buffers to the Left",
      },
    }

    for i = 1, 9 do
      table.insert(keymaps, {
        string.format("<localleader>%d", i),
        string.format("<cmd>BufferLineGoToBuffer %d<CR>", i),
        desc = string.format("Go to Buffer %d", i),
      })

      require("utils").add_which_key({
        string.format("<localleader>%d", i),
        desc = string.format("Go to Buffer %d", i),
      })
    end

    return keymaps
  end,
}
