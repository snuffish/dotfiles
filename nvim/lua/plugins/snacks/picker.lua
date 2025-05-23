local local_buffers = function()
  Snacks.picker.buffers({
    layout = {
      preset = "select",
      preview = true,
    },
  })
end

return {
  "folke/snacks.nvim",
  opts = {
    ---@type snacks.picker
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
      "<localleader><localleader>",
      local_buffers,
      desc = "Buffers",
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
      "<cmd>lua Snacks.picker.grep_word()<CR>",
      mode = { "n", "v", "x" },
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
      "<cmd>lua Snacks.picker.undo()<CR>",
      desc = "Undotree",
    },
    {
      vim.g.map_ctrl_tab,
      "<cmd>lua Snacks.picker.buffers()<CR>",
      desc = "Buffers",
    },
  },
}
