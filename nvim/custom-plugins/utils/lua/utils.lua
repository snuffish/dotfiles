local M = {}

local str_to_obj = function(modes)
  local obj = {}
  for i = 1, modes:len() do
    obj[i] = modes:sub(i, i)
  end

  return obj
end

M.map = function(modes, maps, action, opts)
  modes = type(modes) == "string" and str_to_obj(modes) or modes
  maps = type(maps) == "string" and { maps } or maps

  for _, mode in ipairs(modes) do
    for _, map in ipairs(maps) do
      vim.keymap.set(mode, map, action, opts)
    end
  end
end

M.nvim_map = function(modes, maps, action, opts)
  modes = type(modes) == "string" and str_to_obj(modes) or modes
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

return M

-- local address = "0x01052ed048"
-- local func = find_function_by_address(address)
-- if func then
--   local dumped_func = string.dump(func)
--   print("Function found and dumped:", dumped_func)
-- else
--   print("Function not found")
-- end
