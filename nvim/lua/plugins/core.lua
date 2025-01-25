return {
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
  },
  {
    "MagicDuck/grug-far.nvim",
    keys = {
      {
        "<leader>sr",
        false,
      },
    },
  },
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
    keys = {},
  },
  { "xiyaowong/transparent.nvim" },
  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      cmdheight = 2,
      -- disabled_keys = {
      --   ["<Up>"] = {},
      --   ["<Space>"] = { "n", "x" },
      -- },
    },
    config = function()
      require("hardtime").setup()
    end,
  },
  {
    "kmonad/kmonad-vim",
  },
  {
    "max397574/better-escape.nvim",
    config = function()
      require("better_escape").setup({
        timeout = vim.o.timeoutlen,
        default_mappings = false,
        mappings = {
          i = {
            j = {
              k = "<Esc>",
              j = "<Esc>",
            },
            k = {
              k = "<Esc>",
              j = "<Esc>",
            },
          },
          c = {
            j = {
              k = "<Esc>",
              j = "<Esc>",
            },
          },
          v = {
            j = {
              k = "<Esc>",
            },
          },
          s = {
            j = {
              k = "<Esc>",
            },
          },
        },
      })
    end,
  },
  {
    "Zeioth/compiler.nvim",
    cmd = { "CompilerToggleResults", "CompilerOpen", "CompilerRedo" },
    dependencies = { "stevearc/overseer.nvim", "nvim-telescope/telescope.nvim" },
    opts = {},
  },
  {
    "stevearc/overseer.nvim",
    commit = "68a2d344cea4a2e11acfb5690dc8ecd1a1ec0ce0",
    cmd = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
    opts = {
      task_list = {
        direction = "bottom",
        min_height = 25,
        max_height = 25,
        default_detail = 1,
      },
    },
  },
  {
    "vuki656/package-info.nvim",
    ft = "package.json",
    requires = { "MunifTanjim/nui.nvim" },
    opts = {
      icons = {
        enabled = true,
        style = {
          up_to_date = "| ",
          outdated = "| ",
          invalid = "| ",
        },
      },
      colors = {
        up_to_date = "green",
        outdated = "blue",
        invalid = "red",
      },
      package_manager = "npm",
    },
    keys = function()
      local package_info = require("package-info")
      local opts = {
        noremap = true,
        silent = true,
      }

      local mappings = {
        {
          "<leader>ns",
          package_info.show,
          "Show",
        },
        {
          "<leader>nh",
          package_info.hide,
          "Hide",
        },
        {
          "<leader>nh",
          package_info.toggle,
          "Hide",
        },
        {
          "<leader>nu",
          package_info.update,
          "Update",
        },
        {
          "<leader>nd",
          package_info.delete,
          "Delete",
        },
        {
          "<leader>ni",
          package_info.install,
          "Install",
        },
        {
          "<leader>nv",
          package_info.change_version,
          "Change version",
        },
        {
          "<leader>np",
          "<cmd>Telescope package_info<CR>",
          "Package info",
        },
      }

      local function merge_tables(t1, t2)
        for k, v in pairs(t2) do
          t1[k] = v
        end

        return t1
      end

      local ret = {}
      for _, map in ipairs(mappings) do
        local struct = {
          map[1],
          map[2],
          desc = map[3],
        }

        table.insert(ret, merge_tables(struct, opts))
      end

      return ret
    end,
    config = function(_, opts)
      require("package-info").setup(opts)

      require("telescope").setup({
        extensions = {
          package_info = {
            theme = "ivy",
          },
        },
      })
    end,
  },
  {
    "nvzone/typr",
    dependencies = "nvzone/volt",
    opts = {},
    cmd = { "Typr", "TyprStats" },
  },
  {
    "nvim-neorg/neorg",
    enabled = false,
    lazy = false,
    version = false,
    config = function()
      require("neorg").setup({
        load = {
          ["core.defaults"] = {},
          ["core.concealer"] = {},
          ["core.dirman"] = {
            config = {
              workspaces = {
                notes = "~/notes",
              },
              default_workspace = "notes",
            },
          },
        },
      })

      vim.wo.foldlevel = 99
      vim.wo.conceallevel = 2
    end,
  },
  {
    "rest-nvim/rest.nvim",
    ft = "http",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
        opts.ensure_installed = opts.ensure_installed or {}
        table.insert(opts.ensure_installed, "http")
      end,
    },
    config = function()
      local opts = { noremap = true, silent = true, buffer = 0 }

      local function set_http_keymaps()
        vim.utils.map("n", "<localleader>r", "<cmd>Rest run<CR>", opts)
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "http",
        callback = set_http_keymaps,
      })

      local function set_nvim_rest_results_keymaps()
        vim.utils.map("n", "q", vim.utils.trigger_keys_fn("<C-w><C-q>"), opts)
        vim.utils.map("n", "]", vim.utils.trigger_keys_fn("L"), opts)
        vim.utils.map("n", "[", vim.utils.trigger_keys_fn("H"), opts)
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "rest_nvim_result",
        callback = set_nvim_rest_results_keymaps,
      })
    end,
  },
  {
    "Olical/conjure",
    init = function()
      vim.g["conjure#mapping#doc_word"] = "gk"
    end,
  },
  {
    "folke/trouble.nvim",
    keys = {
      { "[q", false },
      { "]q", false },
    },
  },
}
