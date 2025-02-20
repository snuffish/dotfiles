return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    dependencies = {
      require("plugins.snacks.dashboard"),
      require("plugins.snacks.picker"),
      require("plugins.snacks.zen"),
    },
    ---@type snacks.config
    opts = {
      image = {
        enabled = true,
      },
      scope = {
        enabled = true,
      },
      toggle = {
        enabled = true,
      },
      statuscolumn = {
        enabled = true,
      },
      explorer = {
        enabled = true,
      },
    },
    keys = {
      {
        "<leader>s",
        false,
      },
      {
        "<leader>lg",
        "<cmd>lua snacks.lazygit()<cr>",
        desc = "open lazygit",
      },
      {
        "<leader>gl",
        "<cmd>lua snacks.picker.git_log_file()<cr>",
        desc = "current file history",
      },
      {
        "<leader>gs",
        "<cmd>lua snacks.picker.git_status()<cr>",
        desc = "status",
      },
      {
        "<leader>bs",
        "<cmd>lua snacks.scratch.select()<cr>",
        desc = "select scratch buffer",
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("user", {
        pattern = "VeryLazy",
        callback = function()
          vim.defer_fn(function()
            vim.utils.remove_map("nxo", "]i")
            vim.utils.remove_map("nxo", "[i")

            vim.ui.select = snacks.picker.select

            vim.utils.map("nxo", "[e", function()
              ---@diagnostic disable-next-line: missing-fields
              snacks.scope.jump({
                min_size = 1, -- allow single line scopes
                bottom = false,
                cursor = false,
                edge = true,
                siblings = true,
                treesitter = { blocks = { enabled = false } },
                desc = "jump to top edge of scope",
              })
            end, { desc = "jump to top edge of scope" })

            vim.utils.map("nxo", "[e", function()
              ---@diagnostic disable-next-line: missing-fields
              snacks.scope.jump({
                min_size = 1, -- allow single line scopes
                bottom = false,
                cursor = false,
                edge = true,
                treesitter = { blocks = { enabled = false } },
                desc = "jump to top edge of scope",
              })
            end, { desc = "jump to top edge of scope" })

            vim.utils.map("nxo", "]e", function()
              ---@diagnostic disable-next-line: missing-fields
              snacks.scope.jump({
                min_size = 1, -- allow single line scopes
                bottom = true,
                cursor = false,
                edge = true,
                treesitter = { blocks = { enabled = false } },
                desc = "jump to bottom edge of scope",
              })
            end, { desc = "jump to bottom edge of scope" })

            vim.utils.map("nxo", "]e", function()
              ---@diagnostic disable-next-line: missing-fields
              snacks.scope.jump({
                min_size = 1, -- allow single line scopes
                bottom = true,
                cursor = false,
                edge = true,
                siblings = true,
                treesitter = { blocks = { enabled = false } },
                desc = "jump to bottom edge of scope",
              })
            end, { desc = "jump to bottom edge of scope" })
          end, 500)

          _g = _g or {}
          snacks = snacks or {}

          _g.dd = function(...)
            snacks.debug.inspect(...)
          end

          _g.bt = function()
            snacks.debug.backtrace()
          end

          vim.print = _g.dd
          p = vim.print
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
        "<leader>sr",
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
    "maximilianlloyd/ascii.nvim",
    requires = { "muniftanjim/nui.nvim" },
  },
  {
    "mgierada/lazydocker.nvim",
    dependencies = { "akinsho/toggleterm.nvim" },
    event = "bufread",
    keys = {
      {
        "<leader>ld",
        "<cmd>lazydocker<cr>",
        desc = "open lazydocker",
      },
    },
    config = function()
      require("lazydocker").setup({
        border = "curved",
      })
    end,
  },
}
