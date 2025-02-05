local local_buffers = function()
  Snacks.picker.buffers({
    layout = {
      preset = "select",
    },
  })
end

return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    picker = {
      win = {
        input = {
          keys = {
            [vim.g.map_ctrl_tab] = { "confirm", mode = { "i", "n" } },
            ["<C-p>"] = { "toggle_preview", mode = { "i", "n" } },
            ["<C-q>"] = { "close", mode = { "i", "n" } },
            ["qq"] = { "close", mode = { "i" } },
            ["<C-c>"] = false,
            ["<A-p>"] = false,
          },
        },
        list = {
          keys = {
            ["h"] = { "explorer_up", mode = { "n" } },
            ["<leader>"] = { "confirm", mode = { "n" } },
            ["<C-p>"] = { "toggle_preview", mode = { "i", "n" } },
            ["<A-p>"] = false,
          },
        },
      },
    },
  },
  keys = {
    {
      "<leader>e",
      "<cmd>lua Snacks.picker.explorer()<CR>",
      desc = "Explorer",
    },
    {
      "<leader>sp",
      "<cmd>lua Snacks.picker.pick()<CR>",
      desc = "Pickers",
    },
    {
      "<leader>sc",
      function()
        ---@diagnostic disable-next-line: missing-fields
        Snacks.picker.grep({
          ---@diagnostic disable-next-line: assign-type-mismatch
          cwd = vim.fn.stdpath("config"),
          title = "Grep Config Files",
        })
      end,
      desc = "Grep Config Files",
    },
    {
      "<leader>fc",
      function()
        ---@diagnostic disable-next-line: missing-fields
        Snacks.picker.files({
          ---@diagnostic disable-next-line: assign-type-mismatch
          cwd = vim.fn.stdpath("config"),
          title = "Config Files",
        })
      end,
      desc = "Find Config Files",
    },
    {
      "<leader>sr",
      "<cmd>lua Snacks.picker.resume()<CR>",
      desc = "Resume",
    },
    {
      "<leader>fr",
      "<cmd>lua Snacks.picker.recent()<CR>",
      desc = "Recent",
    },
    {
      "<leader>sh",
      "<cmd>lua Snacks.picker.help()<CR>",
      desc = "Help pages",
    },
    {
      "<leader><leader>",
      "<cmd>lua Snacks.picker.files()<CR>",
      desc = "Find files",
    },
    {
      "<leader>fb",
      local_buffers,
      desc = "Buffers",
    },
    {
      "<Tab><Space>",
      local_buffers,
      desc = "Buffers",
    },
    {
      "<Tab>`",
      local_buffers,
      desc = "Switch Buffer",
    },
    {
      "<leader>fg",
      "<cmd>lua Snacks.picker.git_files()<CR>",
      desc = "Find files (git-files)",
    },
    {
      "<leader>sb",
      "<cmd>lua Snacks.picker.grep_buffers()<CR>",
      desc = "Buffer",
    },
    {
      "g/",
      function()
        local function get_visual_selection()
          -- Yank current visual selection into the 'v' register
          -- NOTE: that this makes no effort to preserve this register
          vim.cmd('noau normal! "vy"')
          return vim.fn.getreg("v")
        end

        ---@diagnostic disable-next-line: missing-fields
        Snacks.picker.grep({
          search = get_visual_selection(),
          live = false,
        })
      end,
      mode = { "x" },
      desc = "Grep visual selection",
    },
    {
      "g/",
      "<cmd>lua Snacks.picker.grep_word()<CR>",
      mode = { "n" },
      desc = "Grep <cword>",
    },
    {
      "<leader>/",
      "<cmd>lua Snacks.picker.grep()<CR>",
      mode = { "n" },
      desc = "Grep Files",
    },
    {
      "<leader>sk",
      "<cmd>lua Snacks.picker.keymaps()<CR>",
      desc = "Keymaps",
    },
    {
      "<leader>su",
      "<cmd>lua Snacks.picker.und󰠣o()<CR>",
      desc = "Undo",
    },
    {
      "<localleader><localleader>",
      "<cmd>lua Snacks.picker.buffers()<CR>",
      desc = "Buffers",
    },
    {
      vim.g.map_ctrl_tab,
      "<cmd>lua Snacks.picker.buffers()<CR>",
      desc = "Buffers",
    },
  },
}
