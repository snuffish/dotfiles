require("plenary.reload").reload_module("popup")

local popup = require("popup")

-- popup.create(
--   "just some longer text Maecenas, dolor, tempus id bibendum velit facilisis nisi at eratDapibus magna dui faucibus finibus ac odio, orci ultricies suspendisse..",
--   {
--     title = "coool",
--     line = 8,
--     col = 100,
--     pos = "topleft",
--     -- wrap = true,
--     time = 2000,
--     width = 10,
--     padding = { 0, 3, 0, 3 },
--     border = { 1, 1, 1, 1 },
--   }
-- )

print(vim.fn.system({ "ls" }))

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
