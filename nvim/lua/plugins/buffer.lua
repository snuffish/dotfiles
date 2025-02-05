return {
  "akinsho/bufferline.nvim",
  version = false,
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
        "<cmd>lua Snacks.bufdelete.delete()<CR>",
        desc = "Delete Buffer",
        silent = true,
      },
      {
        "<Tab>q",
        "<cmd>lua Snacks.bufdelete.delete()<CR>",
        desc = "Delete Buffer",
        silent = true,
      },
      {
        "<localleader>Q",
        function()
          vim.utils.trigger_keys("<leader>bD")
        end,
        desc = "Delete Buffer and Window",
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
        "<Tab>o",
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
      {
        ",n",
        "<cmd>enew<CR>",
        desc = "Create new Buffer",
      },
      {
        "<Tab>l",
        function()
          vim.utils.trigger_keys("]b")
        end,
        desc = "Next Buffer",
      },
      {
        "<S-Tab><S-Tab>",
        function()
          vim.utils.trigger_keys("[b")
        end,
        desc = "Previous Buffer",
      },
      {
        "<Tab>h",
        function()
          vim.utils.trigger_keys("[b")
        end,
        desc = "Previous Buffer",
      },
    }

    for i = 1, 9 do
      table.insert(keymaps, {
        string.format("<localleader>%d", i),
        string.format("<cmd>BufferLineGoToBuffer %d<CR>", i),
        desc = string.format("Go to Buffer %d", i),
      })

      table.insert(keymaps, {
        string.format("<Tab>%d", i),
        string.format("<cmd>BufferLineGoToBuffer %d<CR>", i),
        desc = string.format("Go to Buffer %d", i),
      })
    end

    return keymaps
  end,
}
