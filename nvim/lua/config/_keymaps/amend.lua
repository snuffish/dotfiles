local keymap = vim.keymap
keymap.amend = require("keymap-amend")

-- keymap.amend(mode, lhs, function(original)
--   -- your custom logic
--   original() -- execute the original 'lhs' mapping
-- end, opts)

-- keymap.amend("n", "dd", function(original)
--   local is_empty_line = vim.api.nvim_get_current_line():match("^%s*$")
--   if is_empty_line then
--     print("EMPTY LINE")
--     return '"_dd'
--   else
--     print("NORMAL DELETE")
--     original()
--   end
-- end, {})

vim.keymap.amend("n", "dd", function(original)
  print("AMEND")
  original()
end)
