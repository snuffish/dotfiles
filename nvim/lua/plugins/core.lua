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
    "stevearc/oil.nvim",
    event = "VeryLazy",
    priority = 1000,
    dependencies = {
      { "nvim-tree/nvim-web-devicons", opts = {} },
      "snuffish/utils.nvim",
    },
    opts = {
      default_file_explorer = true,
      float = {
        padding = 2,
        max_width = 200,
        max_height = 0,
        border = "rounded",
        win_options = {
          winblend = 5,
        },
        preview_split = "below",
        get_win_title = nil,
        override = function(conf)
          vim.defer_fn(vim.utils.trigger_keys_fn("<C-p>"), 150)
          return conf
        end,
      },
      keymaps = {
        ["<leader>"] = "actions.select",
        ["q"] = { "actions.close", mode = "n" },
        ["<BS>"] = { "actions.parent", mode = "n" },
        ["<Left>"] = { "actions.parent", mode = "n" },
        ["l"] = { "actions.select", mode = "n" },
        ["h"] = { "actions.parent", mode = "n" },
        ["s"] = {
          function()
            require("oil").save({
              confirm = true,
            })
          end,
          desc = "Save"
        },
      },
    },
    keys = {
      {
        "<leader>o",
        "<cmd>lua require('oil').toggle_float()<CR>",
        desc = "Oil Explorer",
      },
    },
  },
  {
    "kmonad/kmonad-vim",
  },
  {
    "max397574/better-escape.nvim",
    config = function()
      require("better_escape").setup({
        timeout = vim.o.timeoutlen,
        default_mappings = true,
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
          t = {
            j = {
              k = "<C-\\><C-n>",
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
    "tris203/hawtkeys.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      customMaps = {
        ["lazy"] = {
          method = "lazy",
        },
      },
    },
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
    cmd = "TyprStats",
    dependencies = "nvzone/volt",
    opts = {},
  },
  {
    "nvim-neorg/neorg",
    enabled = false,
    lazy = false,
    version = "*",
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
      -- Define a function to set the keybindings
      local function set_http_keymaps()
        local _opts = { noremap = true, silent = true }
        vim.api.nvim_buf_set_keymap(0, "n", "<localleader>r", "<cmd>Rest run<CR>", _opts)
      end

      -- Create an autocmd to set the keybindings for http filetypes
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "http",
        callback = set_http_keymaps,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "VeryLazy",
    enabled = true,
    config = function()
      require("nvim-treesitter.configs").setup({
        textobjects = {
          select = {
            enable = true,
            keymaps = {
              -- Your custom capture.
              -- ["ix"] = "@parameter.outer",
            },
          },
        },
      })
      -- If treesitter is already loaded, we need to run config again for textobjects
      -- if LazyVim.is_loaded("nvim-treesitter") then
      --   local opts = LazyVim.opts("nvim-treesitter")
      --   require("nvim-treesitter.configs").setup({ textobjects = opts.textobjects })
      -- end

      -- When in diff mode, we want to use the default
      -- vim text objects c & C instead of the treesitter ones.
      -- local move = require("nvim-treesitter.textobjects.move") ---@type table<string,fun(...)>
      -- local configs = require("nvim-treesitter.configs")
      -- for name, fn in pairs(move) do
      --   if name:find("goto") == 1 then
      --     move[name] = function(q, ...)
      --       if vim.wo.diff then
      --         local config = configs.get_module("textobjects.move")[name] ---@type table<string,string>
      --         for key, query in pairs(config or {}) do
      --           if q == query and key:find("[%]%[][cC]") then
      --             vim.cmd("normal! " .. key)
      --             return
      --           end
      --         end
      --       end
      --       return fn(q, ...)
      --     end
      --   end
      -- end
    end,
  },
  {
    "Olical/conjure",
    init = function()
      vim.g["conjure#mapping#doc_word"] = "gk"
    end,
  },
}
