require("config.lazy")

LazyVim.on_load("snacks.vim", function()
  vim.schedule(function()
    vim.keymap.del("n", "<leader>uf")
  end)
end)
