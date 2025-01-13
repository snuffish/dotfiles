local M = {}

local stringToChars = function(modes)
  local arr = {}
  for c in modes:gmatch(".") do
    arr[#arr + 1] = c
  end

  return arr
end

M.map = function(modes, maps, action, opts)
  modes = stringToChars(modes)
  maps = type(maps) == "string" and { maps } or maps

  for _, mode in ipairs(modes) do
    for _, map in ipairs(maps) do
      vim.keymap.set(mode, map, action, opts)
    end
  end
end

M.nvim_map = function(modes, maps, action, opts)
  modes = stringToChars(modes)
  maps = type(maps) == "string" and { maps } or maps

  for _, mode in ipairs(modes) do
    for _, map in ipairs(maps) do
      vim.api.nvim_set_keymap(mode, map, action, opts)
    end
  end
end

M.trigger_keys = function(keys)
  local api = vim.api
  api.nvim_feedkeys(api.nvim_replace_termcodes(keys, true, true, true), "m", true)
end

M.trigger_keys_fn = function(keys)
  return function()
    M.trigger_keys(keys)
  end
end

M.find_function_by_address = function(address)
  for _, keymap in ipairs(vim.api.nvim_get_keymap("n")) do
    if keymap.callback then
      local func = keymap.callback
      if tostring(func):find(address) then
        return func
      end
    end
  end
  return nil
end

M.setup = function(namespace)
  namespace = namespace or "utils"
  vim[namespace] = M
end

M.get_current_bufnr = function()
  local current_bufnr = vim.api.nvim_get_current_buf()
  return current_bufnr
end

M.get_all_buffers = function()
  local buffers = vim.api.nvim_list_bufs()
  return buffers
end

M.get_all_buffers_content = function()
  local buffers = vim.api.nvim_list_bufs()
  local buffers_content = {}

  for _, buf in ipairs(buffers) do
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    table.insert(buffers_content, {buf = buf, content = lines})
  end

  return buffers_content
end

return M

-- local address = "0x01052ed048"
-- local func = find_function_by_address(address)
-- if func then
--   local dumped_func = string.dump(func)
--   print("Function found and dumped:", dumped_func)
-- else
--   print("Function not found")
-- end
