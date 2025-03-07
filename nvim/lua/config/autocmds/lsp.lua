local group = vim.api.nvim_create_augroup("Hierarchy", {
  clear = true,
})

vim.api.nvim_create_autocmd({ "LspAttach" }, {
  group = "Hierarchy",
  desc = "Set up the :FunctionReferences user command",
  callback = function()
    local opts = {
      -- Your opts here
    }
    require("hierarchy").setup(opts)
  end,
})
