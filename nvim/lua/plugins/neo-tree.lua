return {
  "nvim-neo-tree/neo-tree.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree reveal<CR>", desc = "NeoTree reveal", silent = true },
    { "<localleader>e", "<cmd>Neotree buffers<CR>", desc = "Buffer Explorer", silent = true },
  },
  opts = {
    window = {
      mappings = {
        ["<leader>"] = "open",
        ["<cr>"] = "open",
        ["o"] = "open",
        ["P"] = { "toggle_preview", config = { use_float = false, use_image_nvim = true } },
        ["l"] = "focus_preview",
        ["<C-b>"] = { "scroll_preview", config = { direction = 10 } },
        ["<C-f>"] = { "scroll_preview", config = { direction = -10 } },
      },
    },
  },
  config = function(_, opts)
    -- require("neo-tree").setup({
    --   window = {
    --     mappings = {
    --       ["P"] = { "toggle_preview", config = { use_float = false, use_image_nvim = true } },
    --       ["l"] = "focus_preview",
    --       ["<C-b>"] = { "scroll_preview", config = {direction = 10} },
    --       ["<C-f>"] = { "scroll_preview", config = {direction = -10} },
    --     }
    --   }
    -- })
    
    vim.print(opts)

    require("neo-tree").setup(opts)
  end,
}
