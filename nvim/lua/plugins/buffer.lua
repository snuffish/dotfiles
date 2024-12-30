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
        "<localleader>s",
        "",
        desc = "Surround",
      },
      {
        "<localleader>sa",
        "gza",
        desc = "Add surrounding",
      },
      {
        "<localleader>sd",
        "gzd",
        desc = "Delete surrounding",
      },
      {
        "<localleader>sc",
        "gzc",
        desc = "Change surrounding",
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
        "<localleader>fs",
        function()
          vim.utils.trigger_keys("s")
        end,
        desc = "Flash Jump (forward)",
      },
      {
        "<localleader>fS",
        function()
          vim.utils.trigger_keys("S")
        end,
        desc = "Flash Jump (backward)",
      },
      {
        "<localleader>yl",
        function()
          vim.utils.trigger_keys("yl")
        end,
        desc = "Flash Yank Remote Line (upwards)",
      },
      {
        "<localleader>yL",
        function()
          vim.utils.trigger_keys("yL")
        end,
        desc = "Flash Yank Remote Line (downwards)",
      },
      {
        "<localleader>yt",
        function()
          vim.utils.trigger_keys("yt")
        end,
        desc = "Flash TreeSitter Yank Search",
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
