return {
  "folke/trouble.nvim",
  opts = {},
  cmd = "Trouble",
  keys = {},
  config = function()
    require("utils").add_which_key({
      "<leader>x",
      group = "Trouble",
      icon = { icon = " ", color = "red" },
    })
  end,
}
