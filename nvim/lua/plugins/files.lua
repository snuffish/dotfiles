local harpoon_modal = function()
  local harpoon = require("harpoon")
  local Menu = require("nui.menu")
  local event = require("nui.utils.autocmd").event

  local fileId = 1
  local menu_items = {}
  for _, item in ipairs(harpoon:list().items) do
    if item.value ~= "" then
      table.insert(
        menu_items,
        Menu.item(string.format("%d %s", fileId, item.value), {
          fileId = fileId,
        })
      )

      fileId = fileId + 1
    end
  end

  local menu = Menu({
    position = "50%",
    size = {
      width = 100,
      height = 5,
    },
    border = {
      style = "single",
      text = {
        top = "Harpoon Buffers",
        top_align = "center",
        bottom = "[ e - enter | a - add | c - clear | n - next | p - prev ]",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
    lines = #menu_items == 0 and {
      Menu.item("  No buffers found"),
    } or menu_items,
    max_width = 20,
    keymap = {
      focus_next = { "j", "<C-j>", "<Down>", "<Tab>" },
      focus_prev = { "k", "<C-k>", "<Up>", "<S-Tab>" },
      close = { "q", "<Esc>", "<C-q>" },
      submit = { "e", "<CR>", "<C-e>", "<Space>" },
    },
    -- on_close = function()
    --   print("Menu Closed!")
    -- end,
    on_submit = function(item)
      if not item.fileId then
        return
      end

      harpoon:list():select(item.fileId)
    end,
  })

  menu:mount()
end

return {
  {
    "stevearc/oil.nvim",
    event = "VeryLazy",
    priority = 1000,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
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
        ["q"] = { "actions.close", mode = "n" },
        ["<Esc>"] = { "actions.close", mode = "n" },
        ["<leader>"] = "actions.select",
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
          desc = "Save",
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
    "echasnovski/mini.pick",
    version = false,
    lazy = false,
    opts = {
      mappings = {
        move_down = "<C-j>",
        move_up = "<C-k>",
        choose = "<CR>",
        toggle_preview = "<C-p>",
        toggle_info = "<Tab>",
      },
    },
  },
  {
    "ThePrimeagen/harpoon",
    enabled = false,
    branch = "harpoon2",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      local harpoon = require("harpoon")

      harpoon:setup()

      vim.utils.map("n", "<C-e>", function()
        harpoon_modal()
      end, { desc = "Toggle Harpoon Buffers" })

      vim.utils.map("n", "<C-e>a", function()
        harpoon:list():add()
        print("Added to Harpoon list")
      end, { desc = "Add buffer to Harpoon" })

      vim.utils.map("n", "<C-e>c", function()
        harpoon:list():clear()
        print("Harpoon list cleared")
      end, { desc = "Clear Harpoon list" })

      for i = 1, 4 do
        vim.utils.map("n", "<leader>" .. i, function()
          harpoon:list():select(i)
        end, { desc = "Harpoon file " .. i, silent = true, noremap = true })
      end

      -- Toggle previous & next buffers stored within Harpoon list
      vim.utils.map("n", "<C-e>n", function()
        harpoon:list():next()
      end)

      vim.utils.map("n", "<C-e>p", function()
        harpoon:list():prev()
      end)

      -- -- basic telescope configuration
      -- local conf = require("telescope.config").values
      -- local function toggle_telescope(harpoon_files)
      --   local file_paths = {}
      --   for _, item in ipairs(harpoon_files.items) do
      --     table.insert(file_paths, item.value)
      --   end
      --
      --   require("telescope.pickers")
      --     .new({}, {
      --       prompt_title = "Harpoon",
      --       finder = require("telescope.finders").new_table({
      --         results = file_paths,
      --       }),
      --       previewer = conf.file_previewer({}),
      --       sorter = conf.generic_sorter({}),
      --     })
      --     :find()
      -- end
      --
      -- vim.keymap.set("n", "<C-e>", function()
      --   toggle_telescope(harpoon:list())
      -- end, { desc = "Open harpoon window" })
    end,
  },
}
