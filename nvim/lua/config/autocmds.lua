-- vim.api.nvim_create_augroup("CenterScreen", { clear = false })
--   group = "CenterScreen",
--   callback = function()
-- vim.api.nvim_create_autocmd("CursorMoved", {
--     if _G.ZenMode and _G.ZenMode.enabled then
--       vim.cmd("normal! zz")
--     end
--   end,
-- })
--
-- local NORMAL = {
--   lineCursor = "#292E42",
--   lineNr = "#7AA2F7",
-- }
--
-- local INSERT = {
--   lineNr = "#9ECE6A",
--   lineCursor = "#3c4468",
-- }
--
-- local VISUAL = {
--   lineCursor = "#292E42",
--   lineNr = "#BB9AF7",
-- }
--
-- local MODE = {
--   NORMAL = 0,
--   INSERT = 1,
--   VISUAL = 2,
-- }
-- -- test
-- vim.api.nvim_set_hl(MODE.NORMAL, "CursorLineNr", { reverse = false, bold = true, fg = NORMAL.lineNr })
-- vim.api.nvim_set_hl(MODE.NORMAL, "CursorLine", { bg = NORMAL.lineCursor })
--
-- vim.api.nvim_set_hl(MODE.INSERT, "CursorLine", { bg = INSERT.lineCursor })
-- vim.api.nvim_set_hl(MODE.INSERT, "CursorLineNr", { reverse = false, bold = true, fg = INSERT.lineNr })
--
-- vim.api.nvim_set_hl(MODE.VISUAL, "CursorLine", { bg = VISUAL.lineCursor })
-- vim.api.nvim_set_hl(MODE.VISUAL, "CursorLineNr", { reverse = false, bold = true, fg = VISUAL.lineNr })
--
-- local setCurrentMode = function(mode)
--   vim.api.nvim_set_hl_ns(mode)
-- end
--
-- vim.api.nvim_create_autocmd("ModeChanged", {
--   callback = function()
--     local mode = vim.fn.mode()
--     if mode == "v" or mode == "V" then
--       setCurrentMode(MODE.VISUAL)
--     elseif mode == "i" then
--       setCurrentMode(MODE.INSERT)
--     else
--       setCurrentMode(MODE.NORMAL)
--     end
--   end,
-- })

vim.api.nvim_create_autocmd({ "BufEnter", "BufRead", "BufWinEnter" }, {
  pattern = "help",
  command = "lua print(MiniBasics.toggle_gnostic())",
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
  pattern = ".env*",
  command = "set filetype=conf",
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
  pattern = "*.md",
  callback = function()
    vim.diagnostic.enable(false)
  end,
})

