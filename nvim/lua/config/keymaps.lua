require("config.remaps")

vim.utils.map("n", "<localleader>a", function()
  local pattern = "%s %l %r"
  vim.o.statuscolumn = vim.o.statuscolumn ~= pattern and pattern or ""
end, { desc = "Toggle `Absolute linenumbers`" })

vim.utils.map("n", "<leader>a", "ggVG", { desc = "Select all text", silent = true })
vim.utils.map("n", "<A-Up><A-Up>", ":<Up>", { desc = "Previous command", noremap = true, silent = true })
vim.utils.map("x", { "/", "g/" }, "<esc>/\\%V", { silent = false, desc = "Search Inside Visual Selection" })

-- Move cursor left/right in insert-mode
vim.utils.map("ci", "<A-a>", "<Home>")
vim.utils.map("ci", "<A-d>", "<End>")

-- Regex replaces
vim.utils.map("n", "RR", "<Esc>:%s/", { noremap = true, desc = "Regex string replace (global)" })
vim.utils.map("x", "RR", "<Esc>:'<,'>s/", { noremap = true, desc = "Regex string replace (selection)" })

-- Regex deletes
vim.utils.map("n", "DD", "<Esc>:%s//<Left>", { noremap = true, desc = "Regex delete (selection)" })
vim.utils.map("x", "DD", "<Esc>:'<,'>s//<Left>", { noremap = true, desc = "Regex delete (selection)" })

-- Mini.Surround mapping
vim.api.nvim_set_keymap("", "ys", "gza", { desc = "Add surrounding" })
vim.api.nvim_set_keymap("", "yss", "ys_", { desc = "Add surrounding (whole row)" })
vim.api.nvim_set_keymap("", "ds", "gzd", { desc = "Delete surrounding" })
vim.api.nvim_set_keymap("", "cs", "gzc", { desc = "Change surrounding" })

local function map_text_object(key)
  vim.api.nvim_set_keymap("n", "<C-i>" .. key, string.format("vi%s%si", key, vim.keycode("<Esc>")), { desc = "Prepennd after " .. key })
  vim.api.nvim_set_keymap("n", "<C-e>" .. key, string.format("vi%so%sa", key, vim.keycode("<Esc>")), { desc = "Apend after " .. key })
end
-- map_text_object("q")
-- map_text_object("d")

-- vim.api.nvim_set_keymap("n", "iq", "viqi", {})
vim.api.nvim_set_keymap("o", "e", "echo 'DSDSDS'", {})

vim.api.nvim_set_keymap("o", "iw", "iw", { noremap = true, desc = "Inside word" })
vim.api.nvim_set_keymap("o", "aw", "aw", { noremap = true, desc = "Around word" })

-- vim.keymap.set("", jk, rhs, opts?)

local test = "dsadsadasdas"
local test = "gfgfg"
local test = "5453gfd"

-- vim.utils.map("n", "<C-e>", "<cmd>echo '1232'<CR>")
-- vim.api.nvim_set_keymap("n", "e", ":set operatorfunc=v:lua.custom_delete_operator<CR>g@", { noremap = true, silent = true, desc = "Custom delete operator" })
-- vim.api.nvim_set_keymap("o", "a", "<cmd>echo '12321321'<CR>", {})

-- vim.api.nvim_set_keymap("i", "<C-a>", string.format("vi%so%sa", key, vim.keycode("<Esc>")), {  })
-- vim.api.nvim_set_keymap("", "cs", "gzc", {})

-- vim.api.nvim_set_keymap("", "hq", "gzhq", { desc = "Highlight surrounding" })

-- Mini.ai mapping
-- vim.api.nvim_set_keymap("n", "	q", "vinqi", {})
-- vim.api.nvim_set_keymap("v", "	q", "inq" .. vim.keycode("<Esc>") .. "i", {})

-- vim.utils.map("	n", "€kBn", function()
--   vim.utils.trigger_keys("viqo" .. vim.keycode("<Esc>") .. "a")
--   -- vim.cmd("stopinser t")
-- end)
-- vim.api.nvim_set_keymap("", "<C-i>", "viqo\\<Esc>i", { noremap = true, silent = true, desc = "Change surrounding" })

-- Insert/append into current text-objects
-- vim.utils.map("n", "<C-i>q", function()
--   vim.cmd("TSTextobjectGotoNextStart @parameter.inner")
-- end)

-- vim.utils.map("ni", "<C-e>q", function()
--   vim.cmd("TSTextobjectGotoNextEnd @parameter.inner")
--   vim.utils.trigger_keys("i")
-- end)

-- vim.utils.map("n", "<C-b>", function()
--   vim.cmd("TSTextobjectRepeatLast")
-- end)



local function edit_operator(type)
  -- Get the selected text
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])
  
  -- Perform your custom operation on the selected text
  for i, line in ipairs(lines) do
    lines[i] = "EDIT: " .. line
  end
  
  -- Replace the selected text with the modified text
  vim.fn.setline(start_pos[2], lines)
end

-- Map the custom operator to a key

-- vim.api.nvim_set_keymap("n", "ge", ":set operatorfunc=v:lua.edit_operator<CR>g@", { noremap = true, silent = true, desc = "Custom edit operator" })
local function custom_delete_operator(type)
  -- Get the selected text
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  -- Perform the delete operation
  for i = start_pos[2], end_pos[2] do
    vim.fn.setline(i, "")
  end
end

-- Map the custom delete operator to a key
-- vim.api.nvim_set_keymap("n", "gd", ":set operatorfunc=v:lua.custom_delete_operator<CR>g@", { noremap = true, silent = true, desc = "Custom delete operator" })






local function custom_delete_operator(type)
  -- Get the selected text
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  -- Perform the delete operation
  for i = start_pos[2], end_pos[2] do
    vim.fn.setline(i, "")
  end
end

-- Assign the function to the global vim table
vim.custom_delete_operator = custom_delete_operator

-- Map the custom delete operator to a key
vim.api.nvim_set_keymap("n", "e", ":set operatorfunc=v:lua.vim.custom_delete_operator<CR>g@", { noremap = true, silent = true, desc = "Custom delete operator" })

