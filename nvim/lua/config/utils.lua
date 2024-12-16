local M = {}

M.str_to_obj = function(modes)
  local obj = {}
  for i = 1, modes:len() do
    obj[i] = modes:sub(i, i)
  end

  return obj
end

M.map = function(modes, maps, action, opts)
  modes = type(modes) == "string" and M.str_to_obj(modes) or modes
  maps = type(maps) == "string" and { maps } or maps

  for _, mode in ipairs(modes) do
    for _, map in ipairs(maps) do
      vim.keymap.set(mode, map, action, opts)
    end
  end
end

M.trigger_keys = function(keys, mode)
  mode = mode or "n" -- Set default mode to 'n' (normal mode) if not provided
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true), mode, true)
end

return M
