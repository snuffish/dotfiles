return {
  {
    "kdheepak/lazygit.nvim",
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = { },
    keys = {
      { "<leader>lg", "<cmd>LazyGit<cr>", desc = "Open LazyGit" },
      { "<leader>sf", "<cmd>FzfLua git_files<CR>", desc = "Git by [F]files" },
      { "<leader>sc", "<cmd>FzfLua git_commits<CR>", desc = "Git by [C]ommits" },
    },
  },
  {
    "mgierada/lazydocker.nvim",
    dependencies = { "akinsho/toggleterm.nvim" },
    config = function()
      require("lazydocker").setup({
        border = "curved", -- valid options are "single" | "double" | "shadow" | "curved"
      })
    end,
    event = "BufRead",
    opts = { },
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
