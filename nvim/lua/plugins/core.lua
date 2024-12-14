return {
  {
    "okuuva/auto-save.nvim",
    cmd = "ASToggle", -- optional for lazy loading on command
    event = { "InsertLeave", "TextChanged" }, -- optional for lazy loading on trigger events
    opts = {
      --
      -- All of these are just the defaults
      --
      enabled = true, -- start auto-save when the plugin is loaded (i.e. when your package manager loads it)
      -- execution_message = {
      --   enabled = true,
      --   message = function() -- message to print on save
      --     return ("AutoSave: saved at " .. vim.fn.strftime("%H:%M:%S"))
      --   end,
      --   dim = 0.18, -- dim the color of `message`
      --   cleaning_interval = 1250, -- (milliseconds) automatically clean MsgArea after displaying `message`. See :h MsgArea
      -- },
      trigger_events = { -- See :h events
        immediate_save = { "BufLeave", "FocusLost" }, -- vim events that trigger an immediate save
        defer_save = { "InsertLeave", "TextChanged" }, -- vim events that trigger a deferred save (saves after `debounce_delay`)
        cancel_deferred_save = { "InsertEnter" }, -- vim events that cancel a pending deferred save
      },
      -- function that takes the buffer handle and determines whether to save the current buffer or not
      -- return true: if buffer is ok to be saved
      -- return false: if it's not ok to be saved
      -- if set to `nil` then no specific condition is applied
      condition = nil,
      write_all_buffers = false, -- write all buffers when the current one meets `condition`
      -- Do not execute autocmds when saving
      -- This is what fixed the issues with undo/redo that I had
      -- https://github.com/okuuva/auto-save.n...
      noautocmd = false,
      lockmarks = false, -- lock marks when saving, see `:h lockmarks` for more details
      -- delay after which a pending save is executed (default 1000)
      debounce_delay = 1000,
      -- log debug messages to 'auto-save.log' file in neovim cache directory, set to `true` to enable
      debug = false,
    },
    keys = {
    },
  },
  {
    "Wansmer/treesj",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
    keys = {
      {
        "<leader>m",
        function()
          require("treesj").toggle()
        end,
      },
    },
    config = function()
      require("treesj").setup({})
    end,
  },
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
  { "SmiteshP/nvim-navic", requires = "neovim/-lspconfig" },
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
        "<leader>mc",
        function()
          vim.ui.input({
            prompt = "Calculate",
          }, function(input)
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
                  vim.notify(string.format("Calc %s: %s", input, value))
                else
                  vim.notify("Error in calculation: " .. value, vim.log.levels.ERROR)
                end
              else
                vim.notify("Invalid input: " .. err, vim.log.levels.ERROR)
              end
            end)
        end,
        desc = "Calculate",
      },
    },
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup()
    end,
  },
}
