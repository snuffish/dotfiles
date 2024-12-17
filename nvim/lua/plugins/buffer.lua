return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = "nvim-tree/nvim-web-devicons",
  keys = function()
    local keymaps = {
      {
        "<localleader>",
        "",
        desc = "Buffer",
      },
      {
        "<localleader>q",
        function()
          vim.utils.trigger_keys("<leader>bd")
        end,
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
        "<localleader><localleader>",
        "<Cmd>FzfLua buffers sort_mru=true sort_lastused=true<CR>",
        desc = "Switch Buffer",
      },
      {
        "<localleader>b",
        "<Cmd>e #<CR>",
        desc = "Switch to Other Buffer",
      },
      {
        "<localleader>o",
        function()
          Snacks.bufdelete.other()
        end,
        desc = "Delete all Other Buffers",
      },
      {
        "<localleader>l",
        "<leader>bl",
        desc = "Delete Buffers to the Left",
      },
      {
        "<localleader>r",
        "<Cmd>BufferLineCloseRight<CR>",
        desc = "Delete Buffers to the Right",
      },
      {
        "<localleader>r",
        "<Cmd>BufferLineCloseRight<CR>",
        desc = "Delete Buffers to the Right",
      },
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
        "<localleader><Tab>",
        "<cmd>BufferLineCycleNext<CR>",
        desc = "Next Buffer",
      },
      {
        "<localleader><S-Tab>",
        "<cmd>BufferLineCyclePrev<CR>",
        desc = "Previous Buffer",
      },
    }

    for i = 1, 9 do
      table.insert(keymaps, {
        string.format("<localleader>%d", i),
        string.format("<cmd>BufferLineGoToBuffer %d<CR>", i),
        desc = string.format("Go to Buffer %d", i),
      })
    end

    return keymaps
  end,
}
