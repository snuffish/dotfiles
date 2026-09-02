return {
  {
    "BibekBhusal0/nvim-shadcn",
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("nvim-shadcn").setup({
        -- Configuration options here
      })
    end,
  },
  {
    "vuki656/package-info.nvim",
    ft = "package.json",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      icons = {
        enable = true,
        style = {
          up_to_date = "| ",
          outdated = "| ",
          invalid = "| ",
        },
      },
      highlights = {
        up_to_date = { fg = "green" },
        outdated = { fg = "blue" },
        invalid = { fg = "red" },
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
          "<leader>nt",
          package_info.toggle,
          "Toggle",
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

      local wk = require("which-key")

      local ret = {}
      for _, map in ipairs(mappings) do
        local keymap = map[1]
        local action = map[2]
        local desc = map[3]

        local struct = {
          keymap,
          action,
          desc = desc,
        }

        wk.add(vim.tbl_deep_extend("force", struct, {
          icon = { icon = "", color = "red" },
        }))

        table.insert(ret, vim.tbl_deep_extend("force", struct, opts))
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
}
