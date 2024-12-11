return {
  {
    "MunifTanjim/nui.nvim",
    lazy = true,
  },
  {
    "hat0uma/csvview.nvim",
    lazy = true,
    event = "BufRead",
    config = function()
      require("csvview").setup({
        view = {
          display_mode = "highlight",
          fzf_options = {
            preview_window = "right:60%",
          },
        },
      })
    end,
  },
  {
    "stevearc/dressing.nvim",
    opts = {
      select = {
        backend = { "telescope" },
        fzf = {
          window = {
            width = 0.5,
            height = 0.4,
          },
        },
      },
    },
  },
  { "nvim-focus/focus.nvim", version = false },
  { "nvim-lua/popup.nvim" },
  { "xiyaowong/transparent.nvim" },
  { "SmiteshP/nvim-navic", requires = "neovim/nvim-lspconfig" },
  { "ThePrimeagen/vim-be-good" },
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      -- Smear cursor color. Defaults to Cursor GUI color if not set.
      -- Set to "none" to match the text color at the target cursor position.
      cursor_color = "#d3cdc3",

      -- Background color. Defaults to Normal GUI background color if not set.
      normal_bg = "#282828",

      -- Smear cursor when switching buffers or windows.
      smear_between_buffers = true,

      -- Smear cursor when moving within line or to neighbor lines.
      smear_between_neighbor_lines = true,

      -- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
      -- Smears will blend better on all backgrounds.
      legacy_computing_symbols_support = false,
    },
  },
  {
    "max397574/better-escape.nvim",
    config = function()
      require("better_escape").setup()
    end,
  },
  {
    "jbyuki/quickmath.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>mc", function ()
          vim.ui.input({
            prompt = "Calculate"
          }, function (input)
              if not input then
                vim.notify("No input provided", vim.log.levels.ERROR)
                return
              end

              if input == "q" then
                vim.notify("Input cancelled", vim.log.levels.INFO)
                return
              end

              local result, err = load("return " .. input)
              if result then
                local success, value = pcall(result)
                if success then
                  vim.notify(value)
                else
                  vim.notify("Error in calculation: " .. value, vim.log.levels.ERROR)
                end
              else
                vim.notify("Invalid input: " .. err, vim.log.levels.ERROR)
              end
            end)
        end,
        desc = "Calculate"
      }
    }
  }
}
