return {
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
  keys = {
    { "<leader>lg", "<cmd>LazyGit<cr>", desc = "Open LazyGit" },
    { "<leader>sf", "<cmd>FzfLua git_files<CR>", desc = "Git by [F]files" },
    { "<leader>sc", "<cmd>FzfLua git_commits<CR>", desc = "Git by [C]ommits" },
  },
}
