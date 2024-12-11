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
    filesystem = {
      window = {
        mappings = {
          ["\\\\"] = "close_window",
          ['<leader>'] = 'open'
        },
      },
    },
  },
}
