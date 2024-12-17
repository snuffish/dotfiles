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
      },
    },
  },
  config = function(_, opts)
    require("neo-tree").setup(opts)
  end,
}
