return {
  require("plugins.snacks.dashboard"),
  require("plugins.snacks.picker"),
  require("plugins.snacks.zen"),
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
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
            vim.utils.remove_map("nxo", "]i")
            vim.utils.remove_map("nxo", "[i")

            local modes = { "n", "x", "o" }
            for _, mode in ipairs(modes) do
              vim.keymap.set(mode, "[i", "g^ae", { desc = "Jump to end of scope" })
            end
            
            vim.utils.map("nxo", { "[i", "<F1>" }, "g^ae", { desc = "Jump to end of scope" })

            vim.keymap.set("n", "[i", "g^ae", { desc = "Jump to end of scope" })
            vim.keymap.set("x", "[i", "g^ae", { desc = "Jump to end of scope" })
            vim.keymap.set("o", "[i", "g^ae", { desc = "Jump to end of scope" })

            vim.ui.select = Snacks.picker.select
            Snacks.toggle.inlay_hints():set(false)

            -- Snacks.Scope mapping
            vim.utils.map("nxo", "[e", function()
              ---@diagnostic disable-next-line: missing-fields
              Snacks.scope.jump({
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
              Snacks.scope.jump({
                min_size = 1, -- allow single line scopes
                bottom = true,
                cursor = false,
                edge = true,
                treesitter = { blocks = { enabled = false } },
                desc = "jump to bottom edge of scope",
              })
            end, { desc = "jump to bottom edge of scope" })
          end, 500)

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
