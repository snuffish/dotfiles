local M = {}

local Path = require("plenary.path")
local scan = require("plenary.scandir")
local oil = require("oil")

local function get_lazy_plugins()
  local lazy_path = Path:new(vim.fn.stdpath("data"), "lazy")
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

function M.open_plugin_in_oil()
  local plugins = get_lazy_plugins()
  local plugin_names = {}

  for _, plugin_path in ipairs(plugins) do
    table.insert(plugin_names, Path:new(plugin_path):make_relative())
  end

  vim.ui.select(plugin_names, { prompt = "Select a plugin:" }, function(choice)
    if choice then
      local plugin_path = Path:new(vim.fn.stdpath("data"), "lazy", choice)
      oil.open(plugin_path:absolute(), { float = true })
    end
  end)
end

return M


-- vim.api.nvim_set_keymap('n', '<leader>lp', '<cmd>lua require("plugins.plugin_search").open_plugin_in_oil()<CR>', { noremap = true, silent = true })


-- return {
--   -- Other plugins
--   { "nvim-lua/plenary.nvim" },
--   { "stevearc/oil.nvim" },
-- }
