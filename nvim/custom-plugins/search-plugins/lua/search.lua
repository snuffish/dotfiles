local M = {}

local Path = require("plenary.path")
local scan = require("plenary.scandir")
local oil = require("oil")

local lazy_path = Path:new(vim.fn.stdpath("data"), "lazy")

M.get_lazy_plugins = function()
  local plugins = {}

  scan.scan_dir(lazy_path:absolute(), {
    depth = 1,
    only_dirs = true,
    on_insert = function(entry)
      table.insert(plugins, entry)
    end,
  })

  return plugins
end

M.open_float_window = function()
  local plugins = M.get_lazy_plugins()
  local plugin_names = {}
  local plugin_paths = {}

  for _, plugin_path in ipairs(plugins) do
    local path_obj = Path:new(plugin_path)
    local plugin_name = path_obj:make_relative(lazy_path:absolute())
    table.insert(plugin_names, plugin_name)
    plugin_paths[plugin_name] = plugin_path
  end

  vim.ui.select(plugin_names, { prompt = "Select a plugin:" }, function(choice)
    if choice then
      local plugin_path = plugin_paths[choice]
      oil.open_float(plugin_path)
    end
  end)
end

M.setup = function()
  vim.api.nvim_create_user_command("SearchPlugin", M.open_float_window, {})
end

return M
