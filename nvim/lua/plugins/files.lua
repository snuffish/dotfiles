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
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
    lines = menu_items,
    max_width = 20,
    keymap = {
      focus_next = { "j", "<C-j>", "<Down>", "<Tab>" },
      focus_prev = { "k", "<C-k>", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "<C-q>", "q" },
      submit = { "<CR>", "<C-e>", "<Space>" },
    },
    on_close = function()
      print("Menu Closed!")
    end,
    on_submit = function(item)
      harpoon:list():select(item.fileId)
    end,
  })

  menu:mount()
end

return {
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      local harpoon = require("harpoon")

      harpoon:setup()

      vim.keymap.set("n", "<C-e>", function()
        harpoon_modal()
      end)

      vim.keymap.set("n", "<leader>a", function()
        harpoon:list():add()
      end)
      -- vim.keymap.set("n", "<C-e>", function()
      --   P(harpoon:list())
      --   vim.ui.select({ "tabs", "spaces" }, {
      --     prompt = "Select tabs or spaces:",
      --     format_item = function(item)
      --       return "I'd like to choose " .. item
      --     end,
      --   }, function(choice)
      --     if choice == "spaces" then
      --       vim.o.expandtab = true
      --     else
      --       vim.o.expandtab = false
      --     end
      --   end)
      -- end)

      vim.keymap.set("n", "<leader>1", function()
        harpoon:list():select(1)
      end)

      vim.keymap.set("n", "<leader>2", function()
        harpoon:list():select(2)
      end)

      vim.keymap.set("n", "<leader>3", function()
        harpoon:list():select(3)
      end)

      vim.keymap.set("n", "<leader>4", function()
        harpoon:list():select(4)
      end)

      -- Toggle previous & next buffers stored within Harpoon list
      vim.keymap.set("n", "<C-S-P>", function()
        harpoon:list():prev()
      end)
      vim.keymap.set("n", "<C-S-N>", function()
        harpoon:list():next()
      end)
      --
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
      --
    end,
  },
}
