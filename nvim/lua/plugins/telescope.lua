return {
  -- {
  --   "telescope.nvim",
  --   keys = {
  --     "<LocalLeader>sk",
  --     "<cmd>Telescope keymaps<cr>",
  --     desc = "Show Keymaps",
  --   },
  -- },
  {
    "nvim-telescope/telescope-ui-select.nvim",
    config = function()
      require("telescope").setup({
        extensions = {
          ["ui.select"] = {
            require("telescope.themes").get_dropdown({}),
          },
        },
      })
      require("telescope").load_extension("ui-select")
    end,
  },
}
