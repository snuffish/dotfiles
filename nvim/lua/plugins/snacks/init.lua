return {
  require("plugins.snacks.dashboard"),
  require("plugins.snacks.picker"),
  require("plugins.snacks.zen"),
  {
    "folke/snacks.nvim",
    opts = {
      scope = {
        enabled = true,
      },
      toggle = {
        enabled = true,
      },
      statuscolumn = {
        enabled = true,
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
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          vim.defer_fn(function()
            vim.ui.select = Snacks.picker.select
            Snacks.toggle.inlay_hints():set(false)
          end, 250)

          _G.dd = function(...)
            Snacks.debug.inspect(...)
          end

          _G.bt = function()
            Snacks.debug.backtrace()
          end

          vim.print = _G.dd
          P = vim.print
        end,
      })
    end,
  },
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
    "mgierada/lazydocker.nvim",
    dependencies = { "akinsho/toggleterm.nvim" },
    event = "BufRead",
    keys = {
      {
        "<leader>ld",
        "<cmd>Lazydocker<CR>",
        desc = "Open LazyDocker",
      },
    },
    config = function()
      require("lazydocker").setup({
        border = "curved",
      })
    end,
  },
}
