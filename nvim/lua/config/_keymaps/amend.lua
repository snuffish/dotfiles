-- keymap.amend(mode, lhs, function(original)
--   -- your custom logic
--   original() -- execute the original 'lhs' mapping
-- end, opts)

local keymap = vim.keymap
keymap.amend = require("keymap-amend")
