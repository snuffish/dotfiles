vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
  pattern = "*",
  command = "lua Snacks.toggle.inlay_hints():set(false)",
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "markdown", "conf" },
  command = "lua Snacks.toggle.diagnostics():set(false)",
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
  pattern = ".env*",
  callback = function()
    vim.cmd("set filetype=conf")
  end,
})


