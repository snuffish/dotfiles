local utils = {}

utils.str_to_obj = function(modes)
  local obj = {}
  for i = 1, modes:len() do
    obj[i] = modes:sub(i, i)
  end

  return obj
end

utils.map = function(modes, maps, action, opts)
  modes = type(modes) == "string" and utils.str_to_obj(modes) or modes
  maps = type(maps) == "string" and { maps } or maps

  for _, mode in ipairs(modes) do
    for _, map in ipairs(maps) do
      vim.keymap.set(mode, map, action, opts)
    end
  end
end

utils.clear_cmd_line = function()
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, true, true), "n")
  vim.cmd('echo ""')
end

return utils
