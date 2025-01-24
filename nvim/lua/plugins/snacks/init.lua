return {
  require("plugins.snacks.dashboard"),
  require("plugins.snacks.picker"),
  require("plugins.snacks.zen"),
  {
    "ibhagwan/fzf-lua",
    keys = {
      {
        "<leader>sc",
        false,
      },
      {
        "<leader>gs",
        false,
      },
      {
        "<leader>sk",
        false,
      },
      {
        "<leader>fc",
        false,
      },
      {
        "<leader>sh",
        false,
      },
      {
        "<leader>fg",
        false,
      },
      {
        "<leader>fr",
        false,
      },
      {
        "<leader>/",
        false,
      },
      {
        "<leader>sR",
        false,
      },
      {
        "<leader>sb",
        false,
      },
      {
        "<leader>fb",
        false,
      },
      {
        "<leader><leader>",
        false,
      },
      {
        "\\",
        false,
      },
    },
  },
  {
    "MaximilianLloyd/ascii.nvim",
    requires = { "MunifTanjim/nui.nvim" },
  },
  {
    "folke/snacks.nvim",
    opts = {
      scroll = {
        enabled = false,
      },
    },
    keys = {
      {
        "<leader>lg",
        "<cmd>lua Snacks.lazygit()<cr>",
        desc = "Open LazyGit",
      },
      {
        "<leader>gl",
        "<cmd>lua Snacks.picker.git_log_file()<cr>",
        desc = "Current File History",
      },
      {
        "<leader>gs",
        "<cmd>lua Snacks.picker.git_status()<cr>",
        desc = "Status",
      },
    },
  },
  {
    "mgierada/lazydocker.nvim",
    dependencies = { "akinsho/toggleterm.nvim" },
    config = function()
      require("lazydocker").setup({
        border = "curved",
      })
    end,
    event = "BufRead",
    opts = {},
    keys = {
      {
        "<leader>ld",
        function()
          require("lazydocker").open()
        end,
        desc = "Open LazyDocker",
      },
    },
  },
}
