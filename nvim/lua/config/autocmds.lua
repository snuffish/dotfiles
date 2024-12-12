local NORMAL = {
  lineCursor = "#292E42",
  lineNr = "#7AA2F7",
}

local INSERT = {
  lineNr = "#9ECE6A",
  lineCursor = "#3c4468",
}

local VISUAL = {
  lineCursor = "#292E42",
  lineNr = "#BB9AF7",
}

local MODE = {
  NORMAL = 0,
  INSERT = 1,
  VISUAL = 2,
}
-- test
vim.api.nvim_set_hl(MODE.NORMAL, "CursorLineNr", { reverse = true, bold = true, fg = NORMAL.lineNr })
vim.api.nvim_set_hl(MODE.NORMAL, "CursorLine", { bg = NORMAL.lineCursor })

vim.api.nvim_set_hl(MODE.INSERT, "CursorLine", { bg = INSERT.lineCursor })
vim.api.nvim_set_hl(MODE.INSERT, "CursorLineNr", { reverse = true, bold = true, fg = INSERT.lineNr })

vim.api.nvim_set_hl(MODE.VISUAL, "CursorLine", { bg = VISUAL.lineCursor })
vim.api.nvim_set_hl(MODE.VISUAL, "CursorLineNr", { reverse = true, bold = true, fg = VISUAL.lineNr })

local setCurrentMode = function(mode)
  vim.api.nvim_set_hl_ns(mode)
end

vim.api.nvim_create_autocmd("ModeChanged", {
  callback = function()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" then
      setCurrentMode(MODE.VISUAL)
    elseif mode == "i" then
      setCurrentMode(MODE.INSERT)
    else
      setCurrentMode(MODE.NORMAL)
    end
  end,
})

require("plenary.reload").reload_module("popup")
local popup = require("popup")

local function get_cursor_position()
  local cursor_pos = vim.api.nvim_win_get_cursor(0) -- 0 refers to the current window
  local line = cursor_pos[1] -- Line number (1-based)
  local col = cursor_pos[2] -- Column number (0-based)
  print("Cursor Position: Line " .. line .. ", Column " .. (col + 1)) -- +1 to convert to 1-based column
end

vim.api.nvim_create_user_command("Run", function(opts)
  if opts.range > 0 then
    local selected_text = vim.fn.getline(opts.line1, opts.line2)
    local command = "node -e " .. vim.fn.shellescape(table.concat(selected_text, "\n"))

    local output = vim.fn.system(command)
    output = output:gsub("\n", " ")
    print(output)

    -- local win_width = vim.api.nvim_win_get_width(0)  -- Get current window width
    -- local win_height = vim.api.nvim_win_get_height(0)  -- Get current window height
    -- local popup_width = 10  -- Width of the popup
    -- local popup_height = 1  -- Height of the popup (you can adjust this if needed)

    popup.create(output, {
      title = "coool",
      -- line = math.floor((win_height - popup_height) / 2),  -- Center vertically
      -- col = math.floor((win_width - popup_width) / 2),      -- Center horizontally
      line = 8,
      col = 120,
      pos = "center", -- Change position to center
      -- wrap = true,
      time = 5000,
      width = 10,
      padding = { 0, 3, 0, 3 },
      border = { 1, 1, 1, 1 },
    })
  else
    print("No text selected")
  end
end, { range = true })

-- Error executing Lua callback: ...ish/.local/share/nvim/lazy/popup.nvim/lua/popup/init.lua:90: 'replacement string' item contains newlines
-- stack traceback:
-- [C]: in function 'nvim_buf_set_lines'
-- ...ish/.local/share/nvim/lazy/popup.nvim/lua/popup/init.lua:90: in function 'create'
-- /Users/snuffish/.terminal/nvim/lua/config/autocmds.lua:13: in function </Users/snuffish/.terminal/nvim/lua/config/autocmds.lua:4>

-- vim.api.nvim_create_user_command("Reload", function()
--   local hls_status = vim.v.hlsearch
--   for name, _ in pairs(package.loaded) do
--     if name:match("^cnull") then
--       package.loaded[name] = nil
--       print('Loaded"  .. name')
--     end
--     -- print("Loaded" .. name)
--   end
--
--   dofile(vim.env.MYVIMRC)
--   if hls_status == 0 then
--     vim.opt.hlsearch = false
--   end
-- end, {})

vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = ".env*",
  command = "set filetype=dot"
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufRead", "BufWinEnter" }, {
  pattern = "help",
  command = "lua print(MiniBasics.toggle_gnostic())",
})
