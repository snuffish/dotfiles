return {
  "LintaoAmons/scratch.nvim",
  event = "VeryLazy",
  dependencies = {
    { "ibhagwan/fzf-lua" }, --optional: if you want to use fzf-lua to pick scratch file. Recommanded, since it will order the files by modification datetime desc. (require rg)
    -- { "stevearc/dressing.nvim" }, -- optional: to have the same UI shown in the GIF
  },
  opts = {
      scratch_file_dir = vim.fn.stdpath("cache") .. "/scratch.nvim",
      window_cmd = "popup",
      file_picker = "fzflua",
      filetypes = { "lua", "js", "bash", "ts" },
    },
  config = function(_, opts)
    require("scratch").setup(opts)
  end,
}
