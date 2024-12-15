require("config.lazy")

vim.cmd("highlight Folded guibg=#022037")

LazyVim.on_load("snacks.vim", function()
  vim.schedule(function()
    vim.keymap.del("n", "<leader>uf")
  end)
end)
