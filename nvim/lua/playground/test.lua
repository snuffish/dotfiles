local map = vim.keymap.set

require("plenary.reload").reload_module("popup")
local popup = require("popup")

popup.create(
  "tempus id bibendum velit facilisis nisi at eratDapibus magna dui faucibus finibus ac odio, orci ultricies suspendisse..",
  {
    title = "coool",
    line = 8,
    col = 100,
    pos = "topleft",
    -- wrap = true,
    time = 2000,
    width = 10,
    padding = { 0, 3, 0, 3 },
    border = { 1, 1, 1, 1 },
  }
)

-- print(vim.fn.system({ "ls" }))

-- ####################################################

-- popup.create({ "option 1", "option 2" }, {
--   line = "cursor+2",
--   col = "cursor+2",
--   border = { 1, 1, 1, 1 },
--   enter = true,
--   cursorline = true,
--
--   callback = function(win_id, sel)
--     print(sel)
--   end,
-- })

-- popup.create("all the plus signs", {
--   line = 8,
--   col = 55,
--   padding = { 0, 3, 0, 3 },
--   -- border = { 0, 1, 0, 1 }
--   borderchars = { "-", "+" },
-- })
-- })

-- local bufnr = vim.api.nvim_create_buf(false, false)
-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "pass bufnr 1", "pass bufnr 2" })
-- popup.create(bufnr, {
--   line = 8,
--   col = 55,
--   minwidth = 20,
-- })

-- popup.create({ "option 1", "option 2" }, {
--   line = "cursor+2",
--   col = "cursor+2",
--   border = { 1, 1, 1, 1},
--   enter = true,
--   cursorline = true,
--   callback = function(win_id, sel) print(sel) end,
-- })

-- map("n", "<leader>f<tab>", function()
--   vim.ui.select(vim.api.nvim_list_tabpages(), {
--     prompt = "Select Tab:",
--     format_item = function(tabid)
--       local wins = vim.api.nvim_tabpage_list_wins(tabid)
--       local not_floating_win = function(winid)
--         return vim.api.nvim_win_get_config(winid).relative == ""
--       end
--       wins = vim.tbl_filter(not_floating_win, wins)
--       local bufs = {}
--       for _, win in ipairs(wins) do
--         local buf = vim.api.nvim_win_get_buf(win)
--         local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
--         if buftype ~= "nofile" then
--           local fname = vim.api.nvim_buf_get_name(buf)
--           table.insert(bufs, vim.fn.fnamemodify(fname, ":t"))
--         end
--       end
--       local tabnr = vim.api.nvim_tabpage_get_number(tabid)
--       local cwd = string.format(" %8s: ", vim.fn.fnamemodify(vim.fn.getcwd(-1, tabnr), ":t"))
--       local is_current = vim.api.nvim_tabpage_get_number(0) == tabnr and "✸" or " "
--       return tabnr .. is_current .. cwd .. table.concat(bufs, ", ")
--     end,
--   }, function(tabid)
--     if tabid ~= nil then
--       vim.cmd(tabid .. "tabnext")
--     end
--   end)
-- end, { desc = "Tabs" })
