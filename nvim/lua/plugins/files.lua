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
    "ThePrimeagen/harpoon",
    enabled = false,
    branch = "harpoon2",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      local harpoon = require("harpoon")

      harpoon:setup()

      vim.keymap.set("n", "<C-e>", function()
        harpoon_modal()
      end, { desc = "Toggle Harpoon Buffers" })

      vim.keymap.set("n", "<C-e>a", function()
        harpoon:list():add()
        print("Added to Harpoon list")
      end, { desc = "Add buffer to Harpoon" })

      vim.keymap.set("n", "<C-e>c", function()
        harpoon:list():clear()
        print("Harpoon list cleared")
      end, { desc = "Clear Harpoon list" })

      for i = 1, 4 do
        vim.keymap.set("n", "<leader>" .. i, function()
          harpoon:list():select(i)
        end, { desc = "Harpoon file " .. i, silent = true, noremap = true })
      end

      -- Toggle previous & next buffers stored within Harpoon list
      vim.keymap.set("n", "<C-e>n", function()
        harpoon:list():next()
      end)

      vim.keymap.set("n", "<C-e>p", function()
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
